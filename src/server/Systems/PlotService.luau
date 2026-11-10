--[[
	PlotService.luau — bases dos jogadores.

	- Atribui um plot livre no join e libera no leave (se lotar, o jogador entra numa fila).
	- Desenha os Boos colocados nos slots (o save fica em Data.PlotLayout).
	- Portão: começa ABERTO; o dono tranca por GateLockSeconds; depois fica aberto
	  pelo menos GateOpenSeconds. Trancado = intrusos são expulsos e ninguém rouba.
	- Alarme (consumível): avisa o dono quando alguém de fora entra.
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
local gate: {
	[Model]: {
		lockedUntil: number,
		nextLockAt: number,
		alarmUntil: number,
		lastAlarm: number,
		lastEject: { [Player]: number },
	},
} =
	{}
local slotModels: { [Model]: { [number]: Model } } = {}
local charConns: { [Player]: RBXScriptConnection } = {}

local LOCKED_COLOR = Color3.fromRGB(90, 255, 140)
local OPEN_COLOR = Color3.fromRGB(255, 70, 70)

local updateGateVisual -- definido mais abaixo

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
	return math.abs(p.X) <= S.X / 2 + 0.5 and math.abs(p.Z) <= S.Z / 2 + 0.5 and p.Y > -3 and p.Y < 24
end

function PlotService.plotAt(pos: Vector3): Model?
	for _, plot in plotsFolder:GetChildren() do
		if plot:IsA("Model") and PlotService.isInside(plot, pos) then
			return plot
		end
	end
	return nil
end

function PlotService.slotCount(player: Player): number
	local n = Config.Plot.BaseSlots
	if ctx.Passes.owns(player, "ExtraSlots") then
		n += Config.Plot.ExtraSlotsPass
	end
	if ctx.Passes.owns(player, "VIP") then
		n += Config.Plot.VIPSlots
	end
	return math.min(n, Config.Plot.MaxSlots)
end

function PlotService.pad(plot: Model, slotIndex: number): BasePart?
	local slots = plot:FindFirstChild("Slots")
	return slots and slots:FindFirstChild("Slot_" .. slotIndex)
end

-- Fora da base, na frente do portão
function PlotService.frontCFrame(plot: Model): CFrame
	local floor = plot.Floor :: BasePart
	return floor.CFrame * CFrame.new(0, 3, -Config.World.PlotSize.Z / 2 - 8) * CFrame.Angles(0, math.pi, 0)
end

function PlotService.spawnCFrame(plot: Model): CFrame
	return (plot.OwnerSpawn :: BasePart).CFrame + Vector3.new(0, 3, 0)
end

----------------------------------------------------------------------
-- Desenho dos slots
----------------------------------------------------------------------
local function bodyCFrameFor(plot: Model, pad: BasePart): CFrame
	local pos = pad.Position + Vector3.new(0, 1.9, 0)
	local look = (plot.Floor :: BasePart).CFrame.LookVector -- frente da base (aponta para a praça)
	return CFrame.lookAt(pos, pos + look)
end

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

function PlotService.renderSlots(player: Player)
	local plot = plotOf[player]
	local data = ctx.PlayerData.data(player)
	if not plot or not data then
		return
	end
	local models = slotModels[plot]
	local unlockedCount = PlotService.slotCount(player)
	for i = 1, Config.Plot.MaxSlots do
		local pad = PlotService.pad(plot, i)
		if pad then
			local unlocked = i <= unlockedCount
			local key = unlocked and data.PlotLayout[tostring(i)] or nil
			pad.Color = unlocked and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(90, 85, 110)
			pad.Material = unlocked and Enum.Material.SmoothPlastic or Enum.Material.Slate
			pad:SetAttribute("Unlocked", unlocked)
			pad:SetAttribute("Occupied", key ~= nil)

			local current = models[i]
			if current and (current:GetAttribute("BooKey") ~= key) then
				current:Destroy()
				models[i] = nil
				current = nil
			end
			if key and not current and Config.Boos[key] then
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
	-- Destrava o Boo que estava num slot que deixou de existir (ex.: passe removido)
	for i, m in pairs(models) do
		if i > unlockedCount then
			m:Destroy()
			models[i] = nil
		end
	end
end

function PlotService.slotModel(plot: Model, slotIndex: number): Model?
	return slotModels[plot] and slotModels[plot][slotIndex]
end

local function clearSlots(plot: Model)
	for _, m in pairs(slotModels[plot]) do
		m:Destroy()
	end
	slotModels[plot] = {}
	for _, child in plot:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("BooKey") then
			child:Destroy() -- iscas restantes
		end
	end
	for i = 1, Config.Plot.MaxSlots do
		local pad = PlotService.pad(plot, i)
		if pad then
			pad:SetAttribute("Unlocked", false)
			pad:SetAttribute("Occupied", false)
			pad.Color = Color3.fromRGB(255, 255, 255)
		end
	end
end

----------------------------------------------------------------------
-- Atribuição
----------------------------------------------------------------------
local function setSign(plot: Model, text: string)
	local sign = plot:FindFirstChild("Sign")
	local label = sign and sign:FindFirstChild("Label")
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
	gate[free] = { lockedUntil = 0, nextLockAt = 0, alarmUntil = 0, lastAlarm = 0, lastEject = {} }
	free:SetAttribute("OwnerUserId", player.UserId)
	free:SetAttribute("OwnerName", player.DisplayName)
	free:SetAttribute("Locked", false)
	player:SetAttribute("PlotIndex", free:GetAttribute("Index"))
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
	clearSlots(plot)
	gate[plot] = { lockedUntil = 0, nextLockAt = 0, alarmUntil = 0, lastAlarm = 0, lastEject = {} }
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", "")
	plot:SetAttribute("VisualSet", false)
	updateGateVisual(plot, false)
	setSign(plot, "Base livre")
	-- Próximo da fila
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
-- Portão e alarme
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
	-- intrusos são expulsos já no próximo tick
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

local function tick()
	local now = os.clock()
	for plot, owner in pairs(ownerOfPlot) do
		local g = gate[plot]
		local locked = g.lockedUntil > now
		updateGateVisual(plot, locked)
		for _, other in Players:GetPlayers() do
			if other ~= owner then
				local pos = ctx.Net.position(other)
				if pos and PlotService.isInside(plot, pos) then
					if locked then
						-- Trancado: expulsa (e quem estava carregando um Boo daqui solta ele)
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
			setSign(plot, string.format("Base de %s\n$%s/s  |  %s", owner.DisplayName, Format.compact(income), status))
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
			gate[plot] = { lockedUntil = 0, nextLockAt = 0, alarmUntil = 0, lastAlarm = 0, lastEject = {} }
			local lockPrompt = plot.LockButton:FindFirstChild("LockPrompt") :: ProximityPrompt
			lockPrompt.Triggered:Connect(function(player)
				if ownerOfPlot[plot] == player and ctx.Net.allowPrompt(player, "Lock") then
					PlotService.toggleGate(player)
				end
			end)
			for _, pad in plot.Slots:GetChildren() do
				local placePrompt = pad:FindFirstChild("PlacePrompt") :: ProximityPrompt
				placePrompt.Triggered:Connect(function(player)
					if ownerOfPlot[plot] == player and ctx.Net.allowPrompt(player, "Place") then
						ctx.Boos.placeBest(player, pad:GetAttribute("SlotIndex"))
					end
				end)
			end
		end
	end

	ctx.PlayerData.Loaded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
	ctx.Net.on("ToggleBaseGate", PlotService.toggleGate)

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
