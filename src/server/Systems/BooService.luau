--[[
	BooService.luau — o loop principal.

	Spawn nas zonas -> Captura -> Inventário -> Base (slot) -> Renda por segundo
	Roubo: o ladrão segura o prompt num Boo de outra base (portão aberto), carrega o Boo
	na cabeça (mais lento) e precisa entrar na PRÓPRIA base para concluir.
	Se morrer, tomar slap/susto ou ser expulso, o Boo cai no chão por DroppedBooSeconds.
	Ninguém pega o Boo -> volta para o dono original.

	Toda regra é checada aqui (servidor). O cliente só dispara prompts/remotes.
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local BooModel = require(Shared.BooModel)
local Rarity = require(Shared.Util.Rarity)

local BooService = {}

local ctx
local world: Instance
local zoneFolder: Instance
local droppedFolder: Instance
local rng = Random.new()

local zoneBoos: { [string]: { Model } } = {}
type Carry = { key: string, fromUserId: number, model: Model }
local carrying: { [Player]: Carry } = {}

local ZONE_BY_NAME = {}
for _, z in ipairs(Config.Zones) do
	ZONE_BY_NAME[z.name] = z
end

----------------------------------------------------------------------
-- Helpers de dados
----------------------------------------------------------------------
local function inventoryCount(data): number
	local n = 0
	for _, c in pairs(data.Inventory) do
		n += c
	end
	return n
end
BooService.inventoryCount = inventoryCount

local function addInventory(data, key: string, amount: number?)
	data.Inventory[key] = (data.Inventory[key] or 0) + (amount or 1)
end

local function removeInventory(data, key: string): boolean
	local c = data.Inventory[key]
	if not c or c <= 0 then
		return false
	end
	c -= 1
	data.Inventory[key] = c > 0 and c or nil
	return true
end

local function placedCount(data): number
	local n = 0
	for _ in pairs(data.PlotLayout) do
		n += 1
	end
	return n
end

local function firstFreeSlot(player: Player, data): number?
	for i = 1, ctx.Plots.slotCount(player) do
		if data.PlotLayout[tostring(i)] == nil then
			return i
		end
	end
	return nil
end

function BooService.stat(data): number
	return math.max(data.Speed, data.ThrowPower)
end

function BooService.incomeMultiplier(player: Player, data): number
	local m = 1 + data.Rebirths * Config.Rebirth.IncomeMultiplierPerRebirth
	if ctx.Passes.owns(player, "DoubleCash") then
		m *= 2
	end
	if (data.Cash2xEnds or 0) > os.time() then
		m *= 2
	end
	if ctx.Passes.owns(player, "VIP") then
		m *= 1.1
	end
	return m
end

function BooService.baseIncome(player: Player, data): number
	local total = 0
	local slots = ctx.Plots.slotCount(player)
	for slot, key in pairs(data.PlotLayout) do
		local i = tonumber(slot)
		local def = Config.Boos[key]
		if def and i and i <= slots then
			total += def.incomePerSec
		end
	end
	return total
end

function BooService.incomePerSec(player: Player, data): number
	return BooService.baseIncome(player, data) * BooService.incomeMultiplier(player, data)
end

-- Guarda no inventário e tenta colocar direto na base (melhor UX)
local function giveBoo(player: Player, data, key: string, autoPlace: boolean?)
	if autoPlace ~= false then
		local slot = firstFreeSlot(player, data)
		if slot then
			data.PlotLayout[tostring(slot)] = key
			ctx.Plots.renderSlots(player)
			return "placed"
		end
	end
	addInventory(data, key)
	return "inventory"
end
BooService.giveBoo = giveBoo

----------------------------------------------------------------------
-- Zonas: spawn e captura
----------------------------------------------------------------------
local function currentLuck(): number
	return ctx.Products.serverLuck()
end

local function spawnZoneBoo(zone)
	local key = Rarity.roll(zone.name, currentLuck() * (1 + zone.luckBias), rng)
	if not key then
		return
	end
	local angle = rng:NextNumber() * math.pi * 2
	local dist = math.sqrt(rng:NextNumber()) * zone.radius * 0.8
	local pos = zone.center + Vector3.new(math.cos(angle) * dist, 2.2, math.sin(angle) * dist)
	local model = BooModel.build(
		key,
		{ anchored = true, cframe = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0) }
	)
	model:SetAttribute("Zone", zone.name)
	model:SetAttribute("SpawnedAt", os.clock())
	BooModel.addLabel(model)

	local p = Instance.new("ProximityPrompt")
	p.Name = "CapturePrompt"
	p.ActionText = "Capturar"
	p.ObjectText = Config.Boos[key].name
	p.HoldDuration = 0.4
	p.MaxActivationDistance = Config.World.CaptureRange + Config.Economy.ThrowRangeBonusMax
	p.RequiresLineOfSight = false
	p.Parent = model.PrimaryPart
	p.Triggered:Connect(function(player)
		if ctx.Net.allowPrompt(player, "Capture") then
			BooService.tryCapture(player, model)
		end
	end)

	model.Parent = zoneFolder
	table.insert(zoneBoos[zone.name], model)

	local tier = Rarity.booTier(key)
	if tier >= Rarity.tier("Legendary") then
		ctx.notifyAll(
			string.format("Um %s %s apareceu em %s!", key, Rarity.label(Config.Boos[key].rarity), zone.label),
			"rare"
		)
	end
end

local function removeZoneBoo(model: Model)
	local zoneName = model:GetAttribute("Zone")
	local list = zoneBoos[zoneName]
	if list then
		local i = table.find(list, model)
		if i then
			table.remove(list, i)
		end
	end
	model:Destroy()
end

function BooService.tryCapture(player: Player, model: Model)
	if not ctx.Net.isDescendant(model, zoneFolder, "Model") or not model.PrimaryPart then
		return
	end
	local data = ctx.PlayerData.data(player)
	if not data then
		return
	end
	local zone = ZONE_BY_NAME[model:GetAttribute("Zone")]
	local key = model:GetAttribute("BooKey")
	if not zone or not Config.Boos[key] then
		return
	end
	if not ctx.Net.cooldown(player, "capture", Config.CaptureCooldown) then
		return
	end
	if BooService.stat(data) < zone.minStat then
		ctx.notify(
			player,
			string.format("Você precisa de %d de Speed ou Throw para capturar em %s.", zone.minStat, zone.label),
			"warn"
		)
		return
	end
	local range = Config.World.CaptureRange
		+ math.min(data.ThrowPower * Config.Economy.ThrowRangeBonusPerPoint, Config.Economy.ThrowRangeBonusMax)
		+ 2
	if not ctx.Net.near(player, model.PrimaryPart.Position, range) then
		return
	end
	local hasFreeSlot = firstFreeSlot(player, data) ~= nil and ctx.Plots.getPlot(player) ~= nil
	if not hasFreeSlot and inventoryCount(data) >= Config.Economy.MaxInventory then
		ctx.notify(player, "Inventário cheio! Venda ou coloque Boos na base.", "warn")
		return
	end

	local position = model.PrimaryPart.Position
	removeZoneBoo(model)

	local lucky = false
	if data.LuckyCaptures > 0 then
		data.LuckyCaptures -= 1
		lucky = true
		local reroll = Rarity.roll(zone.name, currentLuck() * Config.SuperLuckyMultiplier * (1 + zone.luckBias), rng)
		key = Rarity.better(key, reroll)
	end

	data.Stats.Captures += 1
	local where = giveBoo(player, data, key)
	local def = Config.Boos[key]
	ctx.fx("Capture", { userId = player.UserId, booKey = key, position = position, lucky = lucky })
	ctx.notify(
		player,
		string.format(
			"Você capturou %s (%s)%s%s",
			def.name,
			Rarity.label(def.rarity),
			lucky and " com Super Sorte" or "",
			where == "placed" and " e ele já está na sua base!" or "!"
		),
		"success"
	)
	if Rarity.tier(def.rarity) >= Rarity.tier("Epic") then
		ctx.notifyAll(
			string.format("%s capturou um %s %s!", player.DisplayName, def.name, Rarity.label(def.rarity)),
			"rare"
		)
	end
	ctx.PlayerData.markDirty(player)
end

----------------------------------------------------------------------
-- Base: colocar, guardar, vender
----------------------------------------------------------------------
function BooService.place(player: Player, key, slotIndex)
	local data = ctx.PlayerData.data(player)
	if not data or not ctx.Plots.getPlot(player) then
		return
	end
	if not ctx.Net.isString(key) or not Config.Boos[key] or (data.Inventory[key] or 0) <= 0 then
		return
	end
	local maxSlots = ctx.Plots.slotCount(player)
	if slotIndex == nil then
		slotIndex = firstFreeSlot(player, data)
		if not slotIndex then
			ctx.notify(player, "Sua base está cheia. Guarde ou venda um Boo.", "warn")
			return
		end
	elseif not ctx.Net.isInt(slotIndex, 1, maxSlots) then
		return
	end
	local slotKey = tostring(slotIndex)
	local old = data.PlotLayout[slotKey]
	removeInventory(data, key)
	if old then
		addInventory(data, old) -- troca explícita
	end
	data.PlotLayout[slotKey] = key
	ctx.Plots.renderSlots(player)
	ctx.PlayerData.markDirty(player)
end

-- Prompt no slot vazio: coloca o Boo de maior renda do inventário
function BooService.placeBest(player: Player, slotIndex: number)
	local data = ctx.PlayerData.data(player)
	if not data then
		return
	end
	if data.PlotLayout[tostring(slotIndex)] then
		return
	end
	local best, bestIncome = nil, -1
	for key, count in pairs(data.Inventory) do
		local def = Config.Boos[key]
		if def and count > 0 and def.incomePerSec > bestIncome then
			best, bestIncome = key, def.incomePerSec
		end
	end
	if not best then
		ctx.notify(player, "Seu inventário está vazio. Capture Boos nas zonas!", "info")
		return
	end
	BooService.place(player, best, slotIndex)
end

function BooService.store(player: Player, slotIndex)
	local data = ctx.PlayerData.data(player)
	if not data or not ctx.Net.isInt(slotIndex, 1, Config.Plot.MaxSlots) then
		return
	end
	local slotKey = tostring(slotIndex)
	local key = data.PlotLayout[slotKey]
	if not key then
		return
	end
	if inventoryCount(data) >= Config.Economy.MaxInventory then
		ctx.notify(player, "Inventário cheio!", "warn")
		return
	end
	data.PlotLayout[slotKey] = nil
	addInventory(data, key)
	ctx.Plots.renderSlots(player)
	ctx.PlayerData.markDirty(player)
end

function BooService.sell(player: Player, key)
	local data = ctx.PlayerData.data(player)
	if not data or not ctx.Net.isString(key) or not Config.Boos[key] then
		return
	end
	if not removeInventory(data, key) then
		return
	end
	local value = Config.Boos[key].incomePerSec * Config.Economy.SellMultiplier
	data.Cash += value
	ctx.notify(player, string.format("Vendeu %s por $%d.", key, value), "success")
	ctx.fx("Coin", { userId = player.UserId })
	ctx.PlayerData.markDirty(player)
end

----------------------------------------------------------------------
-- Roubo
----------------------------------------------------------------------
function BooService.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

local function attachCarry(thief: Player, key: string, fromUserId: number)
	local char = thief.Character
	local head = char and char:FindFirstChild("Head") :: BasePart
	if not head then
		return false
	end
	local model = BooModel.build(key, { anchored = false, scale = 0.7, cframe = head.CFrame * CFrame.new(0, 2.4, 0) })
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	model.Name = "CarriedBoo"
	model.Parent = char
	carrying[thief] = { key = key, fromUserId = fromUserId, model = model }
	thief:SetAttribute("Carrying", key)
	ctx.Character.refresh(thief)
	return true
end

local function clearCarry(player: Player)
	local c = carrying[player]
	if c then
		if c.model then
			c.model:Destroy()
		end
		carrying[player] = nil
		player:SetAttribute("Carrying", nil)
		ctx.Character.refresh(player)
	end
	return c
end

-- Devolve o Boo para o dono original (se ainda está no servidor)
local function returnToOwner(key: string, fromUserId: number)
	local owner = Players:GetPlayerByUserId(fromUserId)
	local data = owner and ctx.PlayerData.data(owner)
	if owner and data then
		giveBoo(owner, data, key)
		ctx.notify(owner, string.format("Seu %s voltou para casa!", key), "success")
		ctx.PlayerData.markDirty(owner)
	end
end

local function startPickup(player: Player, dropped: Model)
	if not dropped.Parent or not ctx.Net.isDescendant(dropped, droppedFolder, "Model") then
		return
	end
	if carrying[player] or not ctx.Net.alive(player) or not dropped.PrimaryPart then
		return
	end
	if not ctx.Net.near(player, dropped.PrimaryPart.Position, 12) then
		return
	end
	local key = dropped:GetAttribute("BooKey")
	local fromUserId = dropped:GetAttribute("FromUserId")
	dropped:Destroy()
	if player.UserId == fromUserId then
		returnToOwner(key, fromUserId)
		ctx.fx("Recovered", { userId = player.UserId })
	else
		attachCarry(player, key, fromUserId)
		ctx.notify(player, "Você pegou o Boo! Corra para a sua base!", "info")
	end
end

function BooService.dropCarried(player: Player, reason: string)
	local c = carrying[player]
	if not c then
		return
	end
	local pos = c.model and c.model.PrimaryPart and c.model.PrimaryPart.Position or ctx.Net.position(player)
	clearCarry(player)
	if not pos then
		returnToOwner(c.key, c.fromUserId)
		return
	end
	-- Se caiu dentro de uma base trancada/no vazio, devolve direto
	local ground = Vector3.new(pos.X, 2.2, pos.Z)
	if reason == "left" or pos.Y < -20 then
		returnToOwner(c.key, c.fromUserId)
		return
	end
	local model = BooModel.build(c.key, { anchored = true, cframe = CFrame.new(ground) })
	model:SetAttribute("FromUserId", c.fromUserId)
	BooModel.addLabel(model, "Caiu! Pegue rápido")
	local p = Instance.new("ProximityPrompt")
	p.Name = "PickupPrompt"
	p.ActionText = "Pegar"
	p.ObjectText = c.key
	p.HoldDuration = 0.3
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Parent = model.PrimaryPart
	p.Triggered:Connect(function(picker)
		if ctx.Net.allowPrompt(picker, "Pickup") then
			startPickup(picker, model)
		end
	end)
	model.Parent = droppedFolder
	ctx.fx("Dropped", { position = ground, reason = reason })
	task.delay(Config.World.DroppedBooSeconds, function()
		if model.Parent then
			model:Destroy()
			returnToOwner(c.key, c.fromUserId)
		end
	end)
end

local function poofDecoy(thief: Player, model: Model)
	local ownerId = model:GetAttribute("OwnerUserId")
	local pos = model.PrimaryPart and model.PrimaryPart.Position
	model:Destroy()
	ctx.fx("Poof", { position = pos })
	ctx.notify(thief, "Era um Boo Isca! Só sobrou fumaça.", "warn")
	local owner = Players:GetPlayerByUserId(ownerId)
	if owner then
		ctx.notify(owner, string.format("%s caiu na sua isca!", thief.DisplayName), "success")
	end
end

function BooService.trySteal(thief: Player, model: Model)
	local plotsFolder = world.Plots
	if not ctx.Net.isDescendant(model, plotsFolder, "Model") or not model.PrimaryPart then
		return
	end
	local ownerId = model:GetAttribute("OwnerUserId")
	local victim = Players:GetPlayerByUserId(ownerId or 0)
	if not victim or victim == thief then
		return
	end
	if not ctx.Net.cooldown(thief, "steal", 1.5) then
		return
	end
	if carrying[thief] then
		ctx.notify(thief, "Você já está carregando um Boo!", "warn")
		return
	end
	if not ctx.Plots.getPlot(thief) then
		ctx.notify(thief, "Você precisa de uma base para roubar.", "warn")
		return
	end
	if ctx.Character.isInvisible(thief) then
		ctx.notify(thief, "Não dá para roubar invisível!", "warn")
		return
	end
	local plot = ctx.Plots.getPlot(victim)
	if not plot or not model:IsDescendantOf(plot) then
		return
	end
	if ctx.Plots.isLocked(plot) then
		ctx.notify(thief, "Essa base está trancada!", "warn")
		return
	end
	if not ctx.Net.near(thief, model.PrimaryPart.Position, Config.World.StealRange + 3) then
		return
	end

	if model:GetAttribute("Decoy") then
		poofDecoy(thief, model)
		return
	end

	local vData = ctx.PlayerData.data(victim)
	local vSession = ctx.PlayerData.session(victim)
	if not vData or not vSession then
		return
	end
	if vSession.isNewPlayer and os.clock() - vSession.joinClock < Config.World.NewPlayerProtectSeconds then
		ctx.notify(thief, string.format("%s é novato e está protegido por enquanto.", victim.DisplayName), "warn")
		return
	end
	if placedCount(vData) <= 1 then
		ctx.notify(thief, "Não dá para roubar o último Boo de alguém. Seja legal!", "warn")
		return
	end

	local slotKey = tostring(model:GetAttribute("SlotIndex"))
	local key = vData.PlotLayout[slotKey]
	if not key or key ~= model:GetAttribute("BooKey") then
		return
	end

	vData.PlotLayout[slotKey] = nil
	vData.Stats.TimesStolen += 1
	ctx.Plots.renderSlots(victim)
	ctx.PlayerData.markDirty(victim)

	if not attachCarry(thief, key, victim.UserId) then
		returnToOwner(key, victim.UserId)
		return
	end
	ctx.notify(thief, string.format("Você pegou %s! Corra para a sua base!", key), "info")
	ctx.notify(victim, string.format("%s está roubando seu %s! Pegue de volta!", thief.DisplayName, key), "danger")
	ctx.fx(
		"StealAlert",
		{ thief = thief.DisplayName, victim = victim.DisplayName, booKey = key, thiefId = thief.UserId }
	)
end

function BooService.onPlacedPrompt(player: Player, model: Model)
	if model:GetAttribute("OwnerUserId") == player.UserId then
		if model:GetAttribute("Decoy") then
			return
		end
		BooService.store(player, model:GetAttribute("SlotIndex"))
	else
		BooService.trySteal(player, model)
	end
end

local function checkDeliveries()
	for thief, c in pairs(carrying) do
		local pos = ctx.Net.position(thief)
		local plot = ctx.Plots.getPlot(thief)
		if pos and plot and ctx.Plots.isInside(plot, pos) then
			clearCarry(thief)
			local data = ctx.PlayerData.data(thief)
			if data then
				data.Stats.Steals += 1
				giveBoo(thief, data, c.key)
				ctx.notify(thief, string.format("Roubo concluído! %s agora é seu.", c.key), "success")
				ctx.fx("StealSuccess", { userId = thief.UserId, booKey = c.key, position = pos })
				ctx.PlayerData.markDirty(thief)
			else
				returnToOwner(c.key, c.fromUserId)
			end
			local victim = Players:GetPlayerByUserId(c.fromUserId)
			if victim then
				ctx.notify(victim, string.format("%s levou seu %s.", thief.DisplayName, c.key), "danger")
			end
		end
	end
end

----------------------------------------------------------------------
-- Isca
----------------------------------------------------------------------
function BooService.spawnDecoy(player: Player, duration: number): boolean
	local plot = ctx.Plots.getPlot(player)
	local data = ctx.PlayerData.data(player)
	if not plot or not data then
		return false
	end
	local free = {}
	for i = 1, ctx.Plots.slotCount(player) do
		if data.PlotLayout[tostring(i)] == nil and not plot:FindFirstChild("Decoy_" .. i) then
			table.insert(free, i)
		end
	end
	if #free == 0 then
		ctx.notify(player, "Precisa de um slot vazio para a isca.", "warn")
		return false
	end
	local slot = free[rng:NextInteger(1, #free)]
	local pad = ctx.Plots.pad(plot, slot)
	local baits = { "JellyBoo", "MoonBoo", "CometBoo", "StarlightBoo" }
	local look = baits[rng:NextInteger(1, #baits)]
	local pos = pad.Position + Vector3.new(0, 1.9, 0)
	local model = BooModel.build(
		look,
		{ anchored = true, decoy = true, cframe = CFrame.lookAt(pos, pos + (plot.Floor :: BasePart).CFrame.LookVector) }
	)
	model.Name = "Decoy_" .. slot
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Decoy", true)
	model:SetAttribute("SlotIndex", slot)
	BooModel.addLabel(model)
	ctx.Plots.addStealPrompt(model)
	model.Parent = plot
	task.delay(duration, function()
		if model.Parent then
			model:Destroy()
		end
	end)
	return true
end

----------------------------------------------------------------------
-- Rebirth helper
----------------------------------------------------------------------
function BooService.clearBelowTier(player: Player, data, minTier: number)
	for slot, key in pairs(data.PlotLayout) do
		if Rarity.booTier(key) < minTier then
			data.PlotLayout[slot] = nil
		end
	end
	for key in pairs(data.Inventory) do
		if Rarity.booTier(key) < minTier then
			data.Inventory[key] = nil
		end
	end
	ctx.Plots.renderSlots(player)
end

----------------------------------------------------------------------

function BooService.init(c)
	ctx = c
	world = Workspace:WaitForChild("StealABooWorld")
	zoneFolder = world:WaitForChild("ZoneBoos")
	droppedFolder = world:WaitForChild("DroppedBoos")
	for _, z in ipairs(Config.Zones) do
		zoneBoos[z.name] = {}
	end

	ctx.Net.on("RequestCapture", BooService.tryCapture)
	ctx.Net.on("RequestSteal", BooService.trySteal)
	ctx.Net.on("RequestPlaceBoo", BooService.place)
	ctx.Net.on("RequestStoreBoo", BooService.store)
	ctx.Net.on("RequestSellBoo", BooService.sell)

	ctx.PlayerData.Releasing:Connect(function(player)
		BooService.dropCarried(player, "left")
	end)

	-- Enche as zonas logo no início
	for _, zone in ipairs(Config.Zones) do
		for _ = 1, zone.maxBoos do
			spawnZoneBoo(zone)
		end
	end

	-- Spawn das zonas (e troca de Boos velhos para girar o "carrossel" de raridades)
	task.spawn(function()
		while true do
			for _, zone in ipairs(Config.Zones) do
				local list = zoneBoos[zone.name]
				for i = #list, 1, -1 do
					local m = list[i]
					if not m.Parent or os.clock() - (m:GetAttribute("SpawnedAt") or 0) > 120 then
						table.remove(list, i)
						if m.Parent then
							m:Destroy()
						end
					end
				end
				if #list < zone.maxBoos then
					spawnZoneBoo(zone)
				end
			end
			task.wait(Config.BooRespawnSeconds / 2)
		end
	end)

	-- Renda passiva
	task.spawn(function()
		while true do
			local dt = task.wait(Config.Economy.IncomeTickSeconds)
			for player, profile in pairs(ctx.PlayerData.all()) do
				if profile:IsActive() then
					local data = profile.Data
					local gain = BooService.incomePerSec(player, data) * dt
					if gain > 0 then
						data.Cash += gain
						data.TotalCash += gain
						ctx.PlayerData.markDirty(player)
					end
				end
			end
		end
	end)

	-- Entregas de roubo
	task.spawn(function()
		while true do
			task.wait(0.2)
			checkDeliveries()
		end
	end)
end

return BooService
