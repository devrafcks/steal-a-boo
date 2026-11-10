--[[
	PlotService.luau — bases dos jogadores.

	- Atribui um plot livre no join e libera no leave (se lotar, o jogador entra numa fila).
	- Andares: térreo + até 3 andares comprados com Cash (Config.Plot.Floors). Cada andar
	  tem 8 slots e elevadores (pads "Subir" / "Descer").
	- Slots do térreo: 6 livres, 4 do passe ExtraSlots, 2 do passe VIP.
	- Cofre: a renda dos Boos cai no cofre; pisar na esteira de coleta passa tudo para o Cash.
	- Esteiras pagas 2x/3x/4x: o prompt abre a compra no cliente; quem entrega é o ProcessReceipt.
	- Portão: começa ABERTO; o dono tranca por GateLockSeconds; depois fica aberto
	  pelo menos GateOpenSeconds. Trancado = intrusos são expulsos e ninguém rouba.
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local BooModel = require(Shared.BooModel)
local Format = require(Shared.Util.Format)

local PlotService = {}

local ctx
local plotsFolder: Instance
local plotOf: { [Player]: Model } = {}
local ownerOfPlot: { [Model]: Player } = {}
local waiting: { Player } = {}
local gate: { [Model]: any } = {}
local slotModels: { [Model]: { [number]: Model } } = {}
local charConns: { [Player]: RBXScriptConnection } = {}

local LOCKED_COLOR = Color3.fromRGB(90, 255, 140)
local OPEN_COLOR = Color3.fromRGB(255, 70, 70)
local P = Config.Plot
local M = Config.Materials

local updateGateVisual -- definido mais abaixo

local function newGateState()
	return { lockedUntil = 0, nextLockAt = 0, alarmUntil = 0, lastAlarm = 0, lastEject = {} }
end

----------------------------------------------------------------------
-- Consultas
----------------------------------------------------------------------
function PlotService.getPlot(player: Player): Model?
	return plotOf[player]
end

function PlotService.ownerOf(plot: Model): Player?
	return ownerOfPlot[plot]
end

function PlotService.isLocked(plot: Model): boolean
	local g = gate[plot]
	return g ~= nil and g.lockedUntil > os.clock()
end

function PlotService.isInside(plot: Model, pos: Vector3): boolean
	local floor = plot:FindFirstChild("Floor") :: BasePart
	if not floor then
		return false
	end
	local p = floor.CFrame:PointToObjectSpace(pos)
	local S = Config.World.PlotSize
	return math.abs(p.X) <= S.X / 2 + 0.5
		and math.abs(p.Z) <= S.Z / 2 + 0.5
		and p.Y > -3
		and p.Y < P.FloorHeight * #P.Floors + 8
end

function PlotService.plotAt(pos: Vector3): Model?
	for _, plot in plotsFolder:GetChildren() do
		if plot:IsA("Model") and PlotService.isInside(plot, pos) then
			return plot
		end
	end
	return nil
end

function PlotService.baseLevel(player: Player): number
	local data = ctx.PlayerData.data(player)
	return data and math.clamp(data.BaseLevel or 1, 1, #P.Floors) or 1
end

-- Slot i liberado para esse jogador?
function PlotService.isUnlocked(player: Player, i: number): boolean
	if i < 1 or i > P.MaxSlots then
		return false
	end
	if i <= P.BaseGroundSlots then
		return true
	end
	if i <= P.BaseGroundSlots + P.ExtraSlotsPass then
		return ctx.Passes.owns(player, "ExtraSlots")
	end
	if i <= P.GroundSlots then
		return ctx.Passes.owns(player, "VIP")
	end
	local floorIndex = 2 + math.floor((i - P.GroundSlots - 1) / P.FloorSlots)
	return PlotService.baseLevel(player) >= floorIndex
end

function PlotService.unlockedCount(player: Player): number
	local n = 0
	for i = 1, P.MaxSlots do
		if PlotService.isUnlocked(player, i) then
			n += 1
		end
	end
	return n
end

function PlotService.pad(plot: Model, slotIndex: number): BasePart?
	local slots = plot:FindFirstChild("Slots")
	return slots and slots:FindFirstChild("Slot_" .. slotIndex)
end

function PlotService.frontCFrame(plot: Model): CFrame
	local floor = plot.Floor :: BasePart
	return floor.CFrame * CFrame.new(0, 3, -Config.World.PlotSize.Z / 2 - 8) * CFrame.Angles(0, math.pi, 0)
end

function PlotService.spawnCFrame(plot: Model): CFrame
	return (plot.OwnerSpawn :: BasePart).CFrame + Vector3.new(0, 3, 0)
end

local function plotCF(plot: Model): CFrame
	return (plot.Floor :: BasePart).CFrame * CFrame.new(0, -0.5, 0)
end

----------------------------------------------------------------------
-- Prompts
----------------------------------------------------------------------
local function addStealPrompt(model: Model)
	local p = Instance.new("ProximityPrompt")
	p.Name = "StealPrompt"
	p.ActionText = "Roubar"
	p.ObjectText = model.Name
	p.HoldDuration = 0.8
	p.MaxActivationDistance = Config.World.StealRange
	p.RequiresLineOfSight = false
	p.Parent = model.PrimaryPart
	p.Triggered:Connect(function(player)
		if ctx.Net.allowPrompt(player, "Steal") then
			ctx.Boos.onPlacedPrompt(player, model)
		end
	end)
	return p
end
PlotService.addStealPrompt = addStealPrompt

local function setupPad(plot: Model, pad: BasePart)
	local p = pad:FindFirstChild("PlacePrompt") :: ProximityPrompt
	if not p then
		p = Instance.new("ProximityPrompt")
		p.Name = "PlacePrompt"
		p.ActionText = "Colocar Boo"
		p.ObjectText = "Slot " .. pad:GetAttribute("SlotIndex")
		p.MaxActivationDistance = 8
		p.RequiresLineOfSight = false
		p.Enabled = false -- o cliente do dono liga localmente
		p.Parent = pad
	end
	p.Triggered:Connect(function(player)
		if ownerOfPlot[plot] == player and ctx.Net.allowPrompt(player, "Place") then
			ctx.Boos.placeBest(player, pad:GetAttribute("SlotIndex"))
		end
	end)
end

local function setupLift(plot: Model, pad: BasePart)
	local p = pad:FindFirstChildOfClass("ProximityPrompt")
	p.Triggered:Connect(function(player)
		if not ctx.Net.allowPrompt(player, "Lift") then
			return
		end
		local pos = ctx.Net.position(player)
		if not pos or (pos - pad.Position).Magnitude > 12 then
			return
		end
		local target = plot:FindFirstChild(pad:GetAttribute("Target") or "", true)
		if not target then
			ctx.notify(player, "Esse andar ainda não foi construído.", "info")
			return
		end
		player.Character:PivotTo(target.CFrame + Vector3.new(0, 3.5, 0))
		ctx.fx("Lift", { userId = player.UserId })
	end)
end

----------------------------------------------------------------------
-- Andares (construídos conforme o BaseLevel do dono)
----------------------------------------------------------------------
local function mk(className: string, props, parent: Instance)
	local inst = Instance.new(className)
	if inst:IsA("BasePart") then
		inst.Anchored = true
		inst.TopSurface = Enum.SurfaceType.Smooth
		inst.BottomSurface = Enum.SurfaceType.Smooth
	end
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function liftPad(parent: Instance, cf: CFrame, up: boolean, target: string)
	local pad = mk("Part", {
		Name = up and "LiftUp" or "LiftDown",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 5, 5),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
		Color = up and Color3.fromRGB(90, 220, 255) or Color3.fromRGB(255, 170, 90),
		Material = Enum.Material.Neon,
	}, parent)
	pad:SetAttribute("Target", target)
	mk("ProximityPrompt", {
		ActionText = up and "Subir" or "Descer",
		ObjectText = "Elevador",
		HoldDuration = 0.15,
		MaxActivationDistance = 7,
		RequiresLineOfSight = false,
	}, pad)
	local gui = mk("BillboardGui", {
		Size = UDim2.fromOffset(90, 30),
		StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0),
		MaxDistance = 60,
		LightInfluence = 0,
	}, pad)
	mk("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.2,
		Text = up and "SUBIR" or "DESCER",
	}, gui)
	return pad
end

local function buildFloor(plot: Model, f: number)
	local cf = plotCF(plot)
	local h = (f - 1) * P.FloorHeight
	local color = plot:GetAttribute("Color") or Color3.fromRGB(255, 160, 200)
	local floorModel = mk("Model", { Name = "Level_" .. f }, plot)

	mk("Part", {
		Name = "Deck",
		Size = Vector3.new(46, 1, 24),
		CFrame = cf * CFrame.new(0, h, 11),
		Color = color:Lerp(Color3.new(1, 1, 1), 0.55),
		Material = Enum.Material.WoodPlanks,
		MaterialVariant = M.Planks,
	}, floorModel)
	mk("Part", {
		Name = "WallBack",
		Size = Vector3.new(48, P.FloorHeight, 1),
		CFrame = cf * CFrame.new(0, h + P.FloorHeight / 2, 24),
		Color = color,
		Material = Enum.Material.WoodPlanks,
		MaterialVariant = M.Planks,
	}, floorModel)
	for side = -1, 1, 2 do
		mk("Part", {
			Name = "WallSide",
			Size = Vector3.new(1, P.FloorHeight, 26),
			CFrame = cf * CFrame.new(side * 24, h + P.FloorHeight / 2, 11),
			Color = color,
			Material = Enum.Material.WoodPlanks,
			MaterialVariant = M.Planks,
		}, floorModel)
	end
	mk("Part", {
		Name = "Rail",
		Size = Vector3.new(46, 2.5, 0.5),
		CFrame = cf * CFrame.new(0, h + 1.75, -1),
		Color = Color3.fromRGB(255, 240, 255),
		Material = Enum.Material.SmoothPlastic,
	}, floorModel)
	for x = -22, 22, 4 do
		mk("Part", {
			Name = "RailLight",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.7,
			CFrame = cf * CFrame.new(x, h + 3.2, -1),
			Color = (x / 4) % 2 == 0 and Color3.fromRGB(255, 220, 120) or color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, floorModel)
	end
	local sign = mk("Part", {
		Name = "LevelSign",
		Size = Vector3.one,
		CFrame = cf * CFrame.new(0, h + 5, -1.5),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, floorModel)
	local gui = mk("BillboardGui", { Size = UDim2.fromOffset(140, 32), MaxDistance = 90, LightInfluence = 0 }, sign)
	mk("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 240, 150),
		TextStrokeTransparency = 0.2,
		Text = P.Floors[f].name,
	}, gui)

	-- 8 slots do andar
	local i = P.GroundSlots + (f - 2) * P.FloorSlots + 1
	for _, z in ipairs({ 4, 12 }) do
		for _, x in ipairs({ -15, -5, 5, 15 }) do
			local pad = mk("Part", {
				Name = "Slot_" .. i,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.4, 6, 6),
				CFrame = cf * CFrame.new(x, h + 0.7, z) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.new(1, 1, 1),
				Material = Enum.Material.SmoothPlastic,
			}, plot.Slots)
			pad:SetAttribute("SlotIndex", i)
			pad:SetAttribute("Level", f)
			setupPad(plot, pad)
			i += 1
		end
	end

	-- Elevadores: descer volta ao térreo, subir vai ao próximo andar (se existir)
	setupLift(plot, liftPad(floorModel, cf * CFrame.new(-19, h + 0.7, 19), false, "GroundLanding"))
	setupLift(plot, liftPad(floorModel, cf * CFrame.new(-11, h + 0.7, 19), true, "Level_" .. (f + 1) .. "Landing"))
	mk("Part", {
		Name = "Level_" .. f .. "Landing",
		Size = Vector3.new(4, 0.2, 4),
		CFrame = cf * CFrame.new(-19, h + 0.6, 14),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, floorModel)
	return floorModel
end

local function updateRoof(plot: Model, level: number)
	local old = plot:FindFirstChild("Roof")
	if old then
		old:Destroy()
	end
	if level <= 1 then
		return -- o térreo fica aberto (dá para ver os Boos de cima)
	end
	local cf = plotCF(plot)
	local h = level * P.FloorHeight
	local roof = mk("Model", { Name = "Roof" }, plot)
	local colors = { Color3.fromRGB(255, 90, 160), Color3.fromRGB(255, 255, 255) }
	for k = 0, 7 do
		mk("Part", {
			Name = "RoofStripe",
			Size = Vector3.new(6, 0.6, 28),
			CFrame = cf * CFrame.new(-21 + k * 6, h + 0.6, 11) * CFrame.Angles(math.rad(-8), 0, 0),
			Color = colors[(k % 2) + 1],
			Material = Enum.Material.Fabric,
			MaterialVariant = M.Tent,
			CanCollide = false,
		}, roof)
	end
end

function PlotService.renderFloors(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	local level = PlotService.baseLevel(player)
	for f = 2, #P.Floors do
		local existing = plot:FindFirstChild("Level_" .. f)
		if level >= f and not existing then
			buildFloor(plot, f)
		elseif level < f and existing then
			existing:Destroy()
			for i = P.GroundSlots + (f - 2) * P.FloorSlots + 1, P.GroundSlots + (f - 1) * P.FloorSlots do
				local pad = PlotService.pad(plot, i)
				if pad then
					pad:Destroy()
				end
			end
		end
	end
	updateRoof(plot, level)
end

function PlotService.nextFloor(player: Player)
	return P.Floors[PlotService.baseLevel(player) + 1]
end

function PlotService.upgrade(player: Player)
	local data = ctx.PlayerData.data(player)
	if not data or not plotOf[player] or not ctx.Net.cooldown(player, "upgrade", 1) then
		return
	end
	local level = PlotService.baseLevel(player)
	local nextFloor = P.Floors[level + 1]
	if not nextFloor then
		ctx.notify(player, "Sua base já está no máximo!", "info")
		return
	end
	if data.Cash < nextFloor.cost then
		ctx.notify(
			player,
			string.format("Faltam $%s para o %s.", Format.compact(nextFloor.cost - data.Cash), nextFloor.name),
			"warn"
		)
		return
	end
	data.Cash -= nextFloor.cost
	data.BaseLevel = level + 1
	PlotService.renderFloors(player)
	PlotService.renderSlots(player)
	ctx.notify(player, string.format("%s construído! +%d slots.", nextFloor.name, P.FloorSlots), "success")
	ctx.fx(
		"BaseUpgrade",
		{ userId = player.UserId, plotIndex = plotOf[player]:GetAttribute("Index"), level = level + 1 }
	)
	ctx.PlayerData.markDirty(player)
end

----------------------------------------------------------------------
-- Desenho dos slots
----------------------------------------------------------------------
local function bodyCFrameFor(plot: Model, pad: BasePart): CFrame
	local pos = pad.Position + Vector3.new(0, 1.9, 0)
	local look = (plot.Floor :: BasePart).CFrame.LookVector
	return CFrame.lookAt(pos, pos + look)
end

-- Boos em slots que não estão liberados voltam para a bolsa (ex.: passe removido)
local function migrateLocked(player: Player, data): boolean
	local moved = false
	for slot, key in pairs(data.PlotLayout) do
		local i = tonumber(slot)
		if not i or not PlotService.isUnlocked(player, i) then
			data.PlotLayout[slot] = nil
			data.Inventory[key] = (data.Inventory[key] or 0) + 1
			moved = true
		end
	end
	return moved
end

function PlotService.renderSlots(player: Player)
	local plot = plotOf[player]
	local data = ctx.PlayerData.data(player)
	if not plot or not data then
		return
	end
	if migrateLocked(player, data) then
		ctx.PlayerData.markDirty(player)
	end
	local models = slotModels[plot]
	for i = 1, P.MaxSlots do
		local pad = PlotService.pad(plot, i)
		local unlocked = PlotService.isUnlocked(player, i)
		local key = unlocked and data.PlotLayout[tostring(i)] or nil
		if pad then
			pad.Color = unlocked and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(90, 85, 110)
			pad.Material = unlocked and Enum.Material.SmoothPlastic or Enum.Material.Slate
			pad:SetAttribute("Unlocked", unlocked)
			pad:SetAttribute("Occupied", key ~= nil)
		end
		local current = models[i]
		if current and (current:GetAttribute("BooKey") ~= key or not pad) then
			current:Destroy()
			models[i] = nil
			current = nil
		end
		if pad and key and not current and Config.Boos[key] then
			local m = BooModel.build(key, { anchored = true, cframe = bodyCFrameFor(plot, pad) })
			m:SetAttribute("OwnerUserId", player.UserId)
			m:SetAttribute("SlotIndex", i)
			m:SetAttribute("PlotIndex", plot:GetAttribute("Index"))
			BooModel.addLabel(m)
			addStealPrompt(m)
			m.Parent = plot
			models[i] = m
		end
	end
end

function PlotService.slotModel(plot: Model, slotIndex: number): Model?
	return slotModels[plot] and slotModels[plot][slotIndex]
end

local function clearPlot(plot: Model)
	for _, m in pairs(slotModels[plot]) do
		m:Destroy()
	end
	slotModels[plot] = {}
	for _, child in plot:GetChildren() do
		if
			child:IsA("Model") and (child:GetAttribute("BooKey") or child.Name:match("^Level_") or child.Name == "Roof")
		then
			child:Destroy()
		end
	end
	for _, pad in plot.Slots:GetChildren() do
		if (pad:GetAttribute("SlotIndex") or 0) > P.GroundSlots then
			pad:Destroy()
		else
			pad:SetAttribute("Unlocked", false)
			pad:SetAttribute("Occupied", false)
			pad.Color = Color3.fromRGB(255, 255, 255)
		end
	end
	plot:SetAttribute("BoostMult", 1)
	plot:SetAttribute("BoostEnds", 0)
	plot:SetAttribute("IncomePerSec", 0)
end

----------------------------------------------------------------------
-- Atribuição
----------------------------------------------------------------------
local function setLabel(part: Instance?, text: string)
	local label = part and part:FindFirstChild("Label")
	local t = label and label:FindFirstChild("Text")
	if t then
		t.Text = text
	end
end

local function teleportToPlot(player: Player)
	local plot = plotOf[player]
	local char = player.Character
	if plot and char then
		char:PivotTo(PlotService.spawnCFrame(plot))
	end
end

local function assign(player: Player)
	if plotOf[player] then
		return
	end
	local free
	for i = 1, Config.World.MaxPlayersPlotCount do
		local plot = plotsFolder:FindFirstChild("Plot_" .. i)
		if plot and ownerOfPlot[plot] == nil then
			free = plot
			break
		end
	end
	if not free then
		table.insert(waiting, player)
		ctx.notify(player, "Todas as bases estão ocupadas. Você entra na fila e recebe a próxima!", "warn")
		return
	end
	plotOf[player] = free
	ownerOfPlot[free] = player
	slotModels[free] = {}
	gate[free] = newGateState()
	free:SetAttribute("OwnerUserId", player.UserId)
	free:SetAttribute("OwnerName", player.DisplayName)
	free:SetAttribute("Locked", false)
	player:SetAttribute("PlotIndex", free:GetAttribute("Index"))
	PlotService.renderFloors(player)
	PlotService.renderSlots(player)

	if charConns[player] then
		charConns[player]:Disconnect()
	end
	charConns[player] = player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 5)
		task.wait()
		teleportToPlot(player)
	end)
	if player.Character then
		teleportToPlot(player)
	end
	ctx.PlayerData.markDirty(player)
end

local function release(player: Player)
	for i, p in ipairs(waiting) do
		if p == player then
			table.remove(waiting, i)
			break
		end
	end
	if charConns[player] then
		charConns[player]:Disconnect()
		charConns[player] = nil
	end
	local plot = plotOf[player]
	if not plot then
		return
	end
	plotOf[player] = nil
	ownerOfPlot[plot] = nil
	clearPlot(plot)
	gate[plot] = newGateState()
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", "")
	plot:SetAttribute("VisualSet", false)
	updateGateVisual(plot, false)
	setLabel(plot:FindFirstChild("Sign"), "Base livre")
	setLabel(plot:FindFirstChild("CollectPad"), "Cofre")
	while #waiting > 0 do
		local nextPlayer = table.remove(waiting, 1)
		if nextPlayer.Parent == Players then
			assign(nextPlayer)
			if plotOf[nextPlayer] then
				ctx.notify(nextPlayer, "Sua base ficou pronta!", "success")
			end
			break
		end
	end
end

----------------------------------------------------------------------
-- Portão, alarme e cofre
----------------------------------------------------------------------
function PlotService.toggleGate(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	local pos = ctx.Net.position(player)
	local button = plot:FindFirstChild("LockButton") :: BasePart
	if not pos or not (PlotService.isInside(plot, pos) or (button and (pos - button.Position).Magnitude <= 14)) then
		ctx.notify(player, "Vá até a sua base para trancar o portão.", "warn")
		return
	end
	local g = gate[plot]
	local now = os.clock()
	if g.lockedUntil > now then
		ctx.notify(player, string.format("Já está trancado (%ds).", math.ceil(g.lockedUntil - now)), "info")
		return
	end
	if now < g.nextLockAt then
		ctx.notify(player, string.format("Portão recarregando: espere %ds.", math.ceil(g.nextLockAt - now)), "warn")
		return
	end
	g.lockedUntil = now + Config.World.GateLockSeconds
	g.nextLockAt = g.lockedUntil + Config.World.GateOpenSeconds
	plot:SetAttribute("LockEnds", Workspace:GetServerTimeNow() + Config.World.GateLockSeconds)
	plot:SetAttribute(
		"NextLockAt",
		Workspace:GetServerTimeNow() + Config.World.GateLockSeconds + Config.World.GateOpenSeconds
	)
	ctx.notify(player, string.format("Base trancada por %ds!", Config.World.GateLockSeconds), "success")
	ctx.fx("GateLocked", { plotIndex = plot:GetAttribute("Index") })
end

function PlotService.alarm(player: Player, duration: number): boolean
	local plot = plotOf[player]
	if not plot then
		return false
	end
	gate[plot].alarmUntil = os.clock() + duration
	plot:SetAttribute("AlarmEnds", Workspace:GetServerTimeNow() + duration)
	return true
end

function updateGateVisual(plot: Model, locked: boolean)
	if plot:GetAttribute("Locked") == locked and plot:GetAttribute("VisualSet") then
		return
	end
	plot:SetAttribute("VisualSet", true)
	plot:SetAttribute("Locked", locked)
	local g = plot:FindFirstChild("Gate") :: BasePart
	local light = plot:FindFirstChild("StatusLight") :: BasePart
	if g then
		g.Transparency = locked and 0.35 or 1
	end
	if light then
		light.Color = locked and LOCKED_COLOR or OPEN_COLOR
		local glow = light:FindFirstChild("Glow") :: PointLight
		if glow then
			glow.Color = light.Color
		end
	end
	local lockButton = plot:FindFirstChild("LockButton")
	local prompt = lockButton and lockButton:FindFirstChild("LockPrompt") :: ProximityPrompt
	if prompt then
		prompt.ActionText = locked and "Trancada" or "Trancar base"
	end
end

local function collect(player: Player, plot: Model)
	local data = ctx.PlayerData.data(player)
	if not data or (data.Vault or 0) < 1 then
		return
	end
	local amount = math.floor(data.Vault)
	data.Vault -= amount
	data.Cash += amount
	data.TotalCash += amount
	ctx.fx("Collect", { userId = player.UserId, amount = amount, plotIndex = plot:GetAttribute("Index") })
	ctx.PlayerData.markDirty(player)
end

local function tick()
	local now = os.clock()
	for plot, owner in pairs(ownerOfPlot) do
		local g = gate[plot]
		local locked = g.lockedUntil > now
		updateGateVisual(plot, locked)

		-- Esteira de coleta: o dono pisou perto do coletor
		local ownerPos = ctx.Net.position(owner)
		local pad = plot:FindFirstChild("CollectPad") :: BasePart
		if ownerPos and pad and (ownerPos - pad.Position).Magnitude <= Config.Vault.CollectRadius + 2 then
			collect(owner, plot)
		end

		for _, other in Players:GetPlayers() do
			if other ~= owner then
				local pos = ctx.Net.position(other)
				if pos and PlotService.isInside(plot, pos) then
					if locked then
						ctx.Boos.dropCarried(other, "ejected")
						other.Character:PivotTo(PlotService.frontCFrame(plot))
						if (g.lastEject[other] or 0) + 3 < now then
							g.lastEject[other] = now
							ctx.notify(other, "Essa base está trancada!", "warn")
						end
					elseif g.alarmUntil > now and g.lastAlarm + 4 < now then
						g.lastAlarm = now
						ctx.fx("Alarm", { plotIndex = plot:GetAttribute("Index"), intruder = other.DisplayName })
						ctx.notify(owner, string.format("ALARME! %s entrou na sua base!", other.DisplayName), "danger")
					end
				end
			end
		end
	end
end

local function updateSigns()
	for plot, owner in pairs(ownerOfPlot) do
		local data = ctx.PlayerData.data(owner)
		if data then
			local income = ctx.Boos.incomePerSec(owner, data)
			local status = PlotService.isLocked(plot) and "TRANCADA" or "aberta"
			setLabel(
				plot:FindFirstChild("Sign"),
				string.format("Base de %s\n$%s/s  |  %s", owner.DisplayName, Format.compact(income), status)
			)
			setLabel(plot:FindFirstChild("CollectPad"), string.format("Cofre: $%s", Format.compact(data.Vault or 0)))
			plot:SetAttribute("IncomePerSec", income)
			local boostActive = (data.IncomeBoostEnds or 0) > os.time()
			plot:SetAttribute("BoostMult", boostActive and data.IncomeBoostMult or 1)
			plot:SetAttribute("BoostEnds", boostActive and data.IncomeBoostEnds or 0)
		end
	end
end

----------------------------------------------------------------------

function PlotService.init(c)
	ctx = c
	plotsFolder = Workspace:WaitForChild("StealABooWorld"):WaitForChild("Plots")

	for _, plot in plotsFolder:GetChildren() do
		if plot:IsA("Model") then
			slotModels[plot] = {}
			gate[plot] = newGateState()
			local lockPrompt = plot.LockButton:FindFirstChild("LockPrompt") :: ProximityPrompt
			lockPrompt.Triggered:Connect(function(player)
				if ownerOfPlot[plot] == player and ctx.Net.allowPrompt(player, "Lock") then
					PlotService.toggleGate(player)
				end
			end)
			local upgradePrompt = plot:FindFirstChild("UpgradePrompt", true)
			if upgradePrompt then
				upgradePrompt.Triggered:Connect(function(player)
					if ownerOfPlot[plot] == player and ctx.Net.allowPrompt(player, "Upgrade") then
						PlotService.upgrade(player)
					end
				end)
			end
			for _, pad in plot.Slots:GetChildren() do
				setupPad(plot, pad)
			end
			local groundLift = plot:FindFirstChild("LiftUp")
			if groundLift then
				setupLift(plot, groundLift)
			end
		end
	end

	ctx.PlayerData.Loaded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
	ctx.Net.on("ToggleBaseGate", PlotService.toggleGate)
	ctx.Net.on("RequestUpgradeBase", PlotService.upgrade)

	task.spawn(function()
		local signTimer = 0
		while true do
			local dt = task.wait(0.25)
			tick()
			signTimer += dt
			if signTimer >= 1 then
				signTimer = 0
				updateSigns()
			end
		end
	end)
end

return PlotService
