--[[
	init.server.luau — bootstrap do servidor de Steal a Boo!

	Ordem: mapa -> remotes -> dados -> sistemas -> monetização.
	Todos os serviços recebem o mesmo `ctx` (sem requires circulares).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)

local Systems = script.Systems
local Data = script.Data
local Monetization = script.Monetization

local WorldBuilder = require(Systems.WorldBuilder)
local AntiExploit = require(Systems.AntiExploit)
local PlayerData = require(Data.PlayerData)
local Leaderboards = require(Data.Leaderboards)
local PlotService = require(Systems.PlotService)
local CharacterService = require(Systems.CharacterService)
local BooService = require(Systems.BooService)
local TrainingService = require(Systems.TrainingService)
local CombatService = require(Systems.CombatService)
local RebirthService = require(Systems.RebirthService)
local DailyRewardService = require(Systems.DailyRewardService)
local ShopService = require(Systems.ShopService)
local GamePasses = require(Monetization.GamePasses)
local Products = require(Monetization.Products)
local ProcessReceipt = require(Monetization.ProcessReceipt)

print(string.format("[%s] iniciando servidor (%s)", Config.GameName, Config.PlaceVersionNote))

WorldBuilder.build()
AntiExploit.init()

local NotifyRemote = AntiExploit.remote("Notify") :: RemoteEvent
local EffectRemote = AntiExploit.remote("ReplicateEffect") :: RemoteEvent
local DataUpdatedRemote = AntiExploit.remote("DataUpdated") :: RemoteEvent

local ctx = {
	Config = Config,
	Net = AntiExploit,
	PlayerData = PlayerData,
	Leaderboards = Leaderboards,
	Plots = PlotService,
	Character = CharacterService,
	Boos = BooService,
	Training = TrainingService,
	Combat = CombatService,
	Rebirth = RebirthService,
	Daily = DailyRewardService,
	Shop = ShopService,
	Passes = GamePasses,
	Products = Products,
}

-- Toast para um jogador. kind: info | success | warn | danger | rare
function ctx.notify(player: Player, text: string, kind: string?)
	if player and player.Parent == Players then
		NotifyRemote:FireClient(player, text, kind or "info")
	end
end

function ctx.notifyAll(text: string, kind: string?)
	NotifyRemote:FireAllClients(text, kind or "info")
end

-- Efeito visual JÁ autorizado pelo servidor. target nil = todo mundo.
function ctx.fx(name: string, payload, target: Player?)
	if target then
		if target.Parent == Players then
			EffectRemote:FireClient(target, name, payload)
		end
	else
		EffectRemote:FireAllClients(name, payload)
	end
end

----------------------------------------------------------------------
-- Snapshot leve para o HUD
----------------------------------------------------------------------
local function buildSnapshot(player: Player, data)
	local passes = {}
	for key in pairs(Config.GamePasses) do
		passes[key] = GamePasses.owns(player, key)
	end
	return {
		Cash = math.floor(data.Cash),
		TotalCash = math.floor(data.TotalCash),
		Rebirths = data.Rebirths,
		Speed = data.Speed,
		ThrowPower = data.ThrowPower,
		IncomePerSec = BooService.incomePerSec(player, data),
		IncomeMultiplier = BooService.incomeMultiplier(player, data),
		Inventory = data.Inventory,
		PlotLayout = data.PlotLayout,
		Consumables = data.Consumables,
		LuckyCaptures = data.LuckyCaptures,
		SlotCount = PlotService.slotCount(player),
		RebirthCost = RebirthService.cost(data),
		TrainCost = { Speed = TrainingService.cost(data, "Speed"), Throw = TrainingService.cost(data, "Throw") },
		Passes = passes,
		Settings = data.Settings,
		Daily = DailyRewardService.info(data),
		Cash2xEnds = data.Cash2xEnds,
		CarouselPrice = ShopService.carouselPrice(data),
		Stats = data.Stats,
		PlotIndex = player:GetAttribute("PlotIndex"),
		RealSave = PlayerData.isUsingRealSave(),
	}
end
PlayerData.setSnapshot(buildSnapshot, DataUpdatedRemote)

----------------------------------------------------------------------
-- Inicialização dos serviços
----------------------------------------------------------------------
GamePasses.init(ctx)
Products.init(ctx)
CharacterService.init(ctx)
PlotService.init(ctx)
BooService.init(ctx)
TrainingService.init(ctx)
CombatService.init(ctx)
RebirthService.init(ctx)
DailyRewardService.init(ctx)
ShopService.init(ctx)
Leaderboards.init(ctx)
ProcessReceipt.init(ctx)
PlayerData.init() -- por último: o Loaded dispara depois que todos já escutam

-- Settings do jogador (só tipos válidos)
AntiExploit.on("UpdateSettings", function(player, settings)
	local data = PlayerData.data(player)
	if not data or type(settings) ~= "table" then
		return
	end
	if type(settings.ReduceScares) == "boolean" then
		data.Settings.ReduceScares = settings.ReduceScares
	end
	if type(settings.MusicVolume) == "number" and settings.MusicVolume == settings.MusicVolume then
		data.Settings.MusicVolume = math.clamp(settings.MusicVolume, 0, 1)
	end
	PlayerData.markDirty(player)
end)

-- leaderstats (lista de jogadores do Roblox) + tutorial na 1ª sessão
PlayerData.Loaded:Connect(function(player, profile)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = stats
	stats.Parent = player

	task.spawn(function()
		while player.Parent == Players and profile:IsActive() do
			cash.Value = "$" .. Format.compact(profile.Data.Cash)
			rebirths.Value = profile.Data.Rebirths
			task.wait(1)
		end
	end)

	PlayerData.markDirty(player)
	if not profile.Data.TutorialDone then
		profile.Data.TutorialDone = true
		task.delay(2, function()
			ctx.fx("Tutorial", {}, player)
		end)
	end
	if not PlayerData.isUsingRealSave() then
		task.delay(3, function()
			ctx.notify(player, "[Studio] Save em memória: ligue API Services para salvar de verdade.", "warn")
		end)
	end
end)

print(string.format("[%s] servidor pronto", Config.GameName))
