--[[
	PlayerData.luau — save do jogador com ProfileStore.

	- StartSessionAsync no PlayerAdded (session lock: o mesmo save nunca abre em 2 servidores)
	- Reconcile() preenche campos novos do TEMPLATE em saves antigos (adicione campos, nunca renomeie)
	- Autosave nativo do ProfileStore; EndSession no PlayerRemoving; BindToClose espera tudo salvar
	- Studio sem "Enable Studio Access to API Services": usa ProfileStore.Mock (memória) e avisa no Output
	- Se o pacote ProfileStore não existir (esqueceu `wally install`), usa um perfil em memória simples
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Util.Signal)

local PlayerData = {}

local function consumablesTemplate()
	local t = {}
	for _, c in ipairs(Config.Consumables) do
		t[c.key] = 0
	end
	return t
end

PlayerData.TEMPLATE = {
	DataVersion = 1,
	Cash = Config.Economy.StartingCash,
	TotalCash = 0,
	Rebirths = 0,
	Speed = 0,
	ThrowPower = 0,
	SpeedTrains = 0, -- quantas vezes treinou (define o custo)
	ThrowTrains = 0,
	Inventory = {}, -- [booKey] = quantidade (Boos fora da base)
	PlotLayout = {}, -- ["slotIndex"] = booKey (chaves string para o DataStore)
	OwnedCosmetics = {},
	Consumables = consumablesTemplate(),
	LuckyCaptures = 0,
	Daily = { lastDay = -1, streak = 0 },
	PurchaseIds = {}, -- [purchaseId] = os.time() da entrega
	Settings = { ReduceScares = false, MusicVolume = 0.5 },
	Stats = { Steals = 0, Captures = 0, TimesStolen = 0 },
	FirstJoin = 0,
	TutorialDone = false,
	Cash2xEnds = 0, -- os.time() em que acaba o 2x Cash pessoal
	BaseLevel = 1, -- andares construídos (1 = só térreo)
	Vault = 0, -- renda guardada na base, esperando a coleta
	IncomeBoostMult = 1, -- esteira paga ativa (2x/3x/4x)
	IncomeBoostEnds = 0, -- os.time() em que a esteira paga acaba
}

local Profiles: { [Player]: any } = {}
local Sessions: { [Player]: any } = {} -- estado só desta sessão (não salva)

local loadedEvent = Signal.new()
local releasingEvent = Signal.new()
PlayerData.Loaded = loadedEvent -- (player, profile)
PlayerData.Releasing = releasingEvent -- (player, profile) antes do EndSession

local store
local usingFallback = false
local usingMock = false

----------------------------------------------------------------------
-- Fallback: perfil em memória com a mesma "cara" de um Profile
----------------------------------------------------------------------
local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		out[k] = deepCopy(v)
	end
	return out
end

local function reconcile(target, template)
	for k, v in pairs(template) do
		if type(k) == "string" then
			if target[k] == nil then
				target[k] = deepCopy(v)
			elseif type(target[k]) == "table" and type(v) == "table" then
				reconcile(target[k], v)
			end
		end
	end
end

local function newMemoryProfile()
	local ended = Instance.new("BindableEvent")
	local active = true
	local profile = { Data = deepCopy(PlayerData.TEMPLATE), Key = "memory" }
	profile.LastSavedData = profile.Data
	profile.OnSessionEnd = ended.Event
	function profile:IsActive()
		return active
	end
	function profile:Reconcile()
		reconcile(self.Data, PlayerData.TEMPLATE)
	end
	function profile:AddUserId() end
	function profile:Save() end
	function profile:EndSession()
		if active then
			active = false
			ended:Fire()
		end
	end
	return profile
end

----------------------------------------------------------------------

local function studioApiAvailable(): boolean
	if not RunService:IsStudio() then
		return true
	end
	local ok = pcall(function()
		DataStoreService:GetDataStore("__StealABoo_ApiCheck"):GetAsync("check")
	end)
	return ok
end

local function prunePurchaseIds(data)
	local now = os.time()
	local maxAge = Config.DataStore.PurchaseIdMemoryDays * 86400
	local list = {}
	for id, t in pairs(data.PurchaseIds) do
		if type(t) ~= "number" or now - t > maxAge then
			data.PurchaseIds[id] = nil
		else
			table.insert(list, { id = id, t = t })
		end
	end
	if #list > Config.DataStore.PurchaseIdMaxEntries then
		table.sort(list, function(a, b)
			return a.t < b.t
		end)
		for i = 1, #list - Config.DataStore.PurchaseIdMaxEntries do
			data.PurchaseIds[list[i].id] = nil
		end
	end
end

local function onPlayerAdded(player: Player)
	local profile
	if usingFallback then
		profile = newMemoryProfile()
	else
		profile = store:StartSessionAsync(tostring(player.UserId), {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})
	end

	if profile == nil then
		-- só acontece quando o servidor está desligando
		player:Kick("Não consegui carregar seu save. Entre de novo, por favor!")
		return
	end

	profile:AddUserId(player.UserId) -- GDPR
	profile:Reconcile()
	prunePurchaseIds(profile.Data)

	profile.OnSessionEnd:Connect(function()
		Profiles[player] = nil
		Sessions[player] = nil
		if player.Parent == Players then
			player:Kick("Seu save foi aberto em outro servidor. Entre de novo!")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	local data = profile.Data
	local isNew = data.FirstJoin == 0
	if isNew then
		data.FirstJoin = os.time()
		-- o Boo inicial já nasce colocado na base (renda desde o primeiro segundo)
		data.PlotLayout["1"] = Config.Economy.StarterBoo
	end

	Profiles[player] = profile
	Sessions[player] = {
		joinClock = os.clock(),
		isNewPlayer = isNew,
		cooldowns = {},
	}
	player:SetAttribute("DataLoaded", true)
	loadedEvent:Fire(player, profile)
end

local function onPlayerRemoving(player: Player)
	local profile = Profiles[player]
	if profile ~= nil then
		releasingEvent:Fire(player, profile)
		profile:EndSession()
	end
	Profiles[player] = nil
	Sessions[player] = nil
end

function PlayerData.init()
	local ok, ProfileStore = pcall(function()
		return require(ServerScriptService:WaitForChild("ServerPackages", 5):WaitForChild("ProfileStore", 5))
	end)
	if not ok or ProfileStore == nil then
		usingFallback = true
		warn(
			"[PlayerData] ProfileStore não encontrado (rode `wally install`). Usando save em MEMÓRIA — nada será salvo!"
		)
	else
		local s = ProfileStore.New(Config.DataStore.ProfileStoreName, PlayerData.TEMPLATE)
		if studioApiAvailable() then
			store = s
		else
			store = s.Mock
			usingMock = true
			warn(
				"[PlayerData] Studio sem acesso às API Services: usando ProfileStore.Mock (memória). Ligue Game Settings > Security > Enable Studio Access to API Services para testar o save de verdade."
			)
		end
	end

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	game:BindToClose(function()
		-- encerra todas as sessões e espera o ProfileStore gravar (máx ~25s)
		for _, player in Players:GetPlayers() do
			task.spawn(onPlayerRemoving, player)
		end
		local deadline = os.clock() + 25
		while os.clock() < deadline do
			if next(Profiles) == nil then
				break
			end
			task.wait(0.25)
		end
	end)
end

function PlayerData.get(player: Player)
	local p = Profiles[player]
	if p and p:IsActive() then
		return p
	end
	return nil
end

function PlayerData.data(player: Player)
	local p = PlayerData.get(player)
	return p and p.Data
end

function PlayerData.session(player: Player)
	return Sessions[player]
end

-- Espera o perfil carregar (nil se o jogador saiu ou passou do tempo)
function PlayerData.waitFor(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 30)
	while player.Parent == Players and os.clock() < deadline do
		local p = PlayerData.get(player)
		if p then
			return p
		end
		task.wait(0.1)
	end
	return nil
end

function PlayerData.isUsingRealSave(): boolean
	return not usingFallback and not usingMock
end

----------------------------------------------------------------------
-- Snapshot para o HUD (debounce: no máximo 5 por segundo por jogador)
----------------------------------------------------------------------
local snapshotBuilder = nil
local dirty: { [Player]: boolean } = {}
local dataUpdatedRemote: RemoteEvent? = nil

function PlayerData.setSnapshot(builder, remote: RemoteEvent)
	snapshotBuilder = builder
	dataUpdatedRemote = remote
end

function PlayerData.markDirty(player: Player)
	if dirty[player] then
		return
	end
	dirty[player] = true
	task.delay(0.2, function()
		dirty[player] = nil
		if player.Parent ~= Players or not snapshotBuilder or not dataUpdatedRemote then
			return
		end
		local profile = PlayerData.get(player)
		if profile then
			local ok, snap = pcall(snapshotBuilder, player, profile.Data)
			if ok then
				dataUpdatedRemote:FireClient(player, snap)
			else
				warn("[PlayerData] snapshot falhou:", snap)
			end
		end
	end)
end

function PlayerData.all()
	return Profiles
end

return PlayerData
