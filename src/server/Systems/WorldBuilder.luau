--[[
	WorldBuilder.luau — monta o mapa inteiro com primitivas se o place estiver vazio.

	Se já existir workspace.StealABooWorld (você editou o mapa à mão e salvou),
	ele NÃO reconstrói: só usa o que está lá (mesmos nomes de peças).

	Layout (vista de cima, +X = leste):
	  - Praça neutra no centro (0,0,0), raio Config.World.PlazaRadius
	  - 8 bases: 4 ao norte (z = -105) e 4 ao sul (z = +105), frente virada para a praça
	  - Zonas de captura a leste (Feirinha, Corredor, Terreno da Lua) e a Tenda Secreta a oeste
]]
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local WorldBuilder = {}

local PLOT_COLORS = {
	Color3.fromRGB(255, 140, 190),
	Color3.fromRGB(160, 130, 255),
	Color3.fromRGB(255, 210, 90),
	Color3.fromRGB(110, 220, 255),
	Color3.fromRGB(255, 160, 90),
	Color3.fromRGB(140, 235, 160),
	Color3.fromRGB(255, 120, 120),
	Color3.fromRGB(200, 150, 255),
}

local function mk(className: string, props, parent: Instance?)
	local inst = Instance.new(className)
	if inst:IsA("BasePart") then
		inst.Anchored = true
		inst.TopSurface = Enum.SurfaceType.Smooth
		inst.BottomSurface = Enum.SurfaceType.Smooth
	end
	for k, v in pairs(props) do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function prompt(parent: Instance, actionText: string, objectText: string, hold: number?, name: string?)
	return mk("ProximityPrompt", {
		Name = name or "Prompt",
		ActionText = actionText,
		ObjectText = objectText,
		HoldDuration = hold or 0,
		MaxActivationDistance = 12,
		RequiresLineOfSight = false,
		KeyboardKeyCode = Enum.KeyCode.E,
	}, parent)
end

local function billboard(parent: Instance, text: string, size: UDim2, offset: Vector3, color: Color3?)
	local gui = mk("BillboardGui", {
		Name = "Label",
		Size = size,
		StudsOffsetWorldSpace = offset,
		MaxDistance = 250,
		LightInfluence = 0,
	}, parent)
	mk("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = color or Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.2,
		Text = text,
	}, gui)
	return gui
end

local function lamp(parent: Instance, pos: Vector3, color: Color3?)
	local m = mk("Model", { Name = "Lamp" }, parent)
	mk("Part", { Name = "Pole", Size = Vector3.new(0.6, 12, 0.6), CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)), Color = Color3.fromRGB(50, 40, 70), Material = Enum.Material.Metal }, m)
	local bulb = mk("Part", { Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, CFrame = CFrame.new(pos + Vector3.new(0, 12.5, 0)), Color = color or Color3.fromRGB(255, 220, 140), Material = Enum.Material.Neon, CanCollide = false }, m)
	mk("PointLight", { Range = 22, Brightness = 1.3, Color = color or Color3.fromRGB(255, 210, 150), Shadows = false }, bulb)
	return m
end

local function stripedAwning(parent: Instance, cf: CFrame, width: number, depth: number, colors: { Color3 })
	local stripes = math.max(2, math.floor(width / 3))
	local w = width / stripes
	for i = 0, stripes - 1 do
		mk("Part", {
			Name = "Awning",
			Size = Vector3.new(w, 0.4, depth),
			CFrame = cf * CFrame.new(-width / 2 + w * (i + 0.5), 0, 0) * CFrame.Angles(math.rad(-15), 0, 0),
			Color = colors[(i % #colors) + 1],
			Material = Enum.Material.Fabric,
			CanCollide = false,
		}, parent)
	end
end

local function buildLighting()
	Lighting.ClockTime = 20.6
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(70, 55, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 100, 160)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end
	mk("Atmosphere", { Density = 0.28, Offset = 0.1, Color = Color3.fromRGB(150, 110, 200), Decay = Color3.fromRGB(80, 60, 140), Glare = 0.2, Haze = 1.2 }, Lighting)
	mk("BloomEffect", { Intensity = 0.45, Size = 24, Threshold = 1.6 }, Lighting)
	mk("ColorCorrectionEffect", { Brightness = 0.03, Contrast = 0.08, Saturation = 0.18, TintColor = Color3.fromRGB(255, 240, 230) }, Lighting)
end

local function buildGround(world: Instance)
	mk("Part", { Name = "Ground", Size = Vector3.new(660, 2, 660), CFrame = CFrame.new(0, -1, 0), Color = Color3.fromRGB(60, 50, 95), Material = Enum.Material.Pavement }, world)
	-- Faixas coloridas (padronagem simples)
	for i = -5, 5 do
		mk("Part", { Name = "Stripe", Size = Vector3.new(4, 0.05, 660), CFrame = CFrame.new(i * 60, 0.02, 0), Color = Color3.fromRGB(80, 65, 125), Material = Enum.Material.SmoothPlastic, CanCollide = false }, world)
	end
	-- Paredes invisíveis do limite do mapa
	local half = 320
	for _, data in { { Vector3.new(half, 60, 0), Vector3.new(2, 120, 660) }, { Vector3.new(-half, 60, 0), Vector3.new(2, 120, 660) }, { Vector3.new(0, 60, half), Vector3.new(660, 120, 2) }, { Vector3.new(0, 60, -half), Vector3.new(660, 120, 2) } } do
		mk("Part", { Name = "Boundary", Size = data[2], CFrame = CFrame.new(data[1]), Transparency = 1, CanQuery = false }, world)
	end
	-- Caminhos até as zonas
	mk("Part", { Name = "PathEast", Size = Vector3.new(230, 0.1, 14), CFrame = CFrame.new(155, 0.05, 0), Color = Color3.fromRGB(240, 200, 120), Material = Enum.Material.Cobblestone, CanCollide = false }, world)
	mk("Part", { Name = "PathWest", Size = Vector3.new(110, 0.1, 14), CFrame = CFrame.new(-95, 0.05, 0), Color = Color3.fromRGB(240, 200, 120), Material = Enum.Material.Cobblestone, CanCollide = false }, world)
	mk("Part", { Name = "PathNS", Size = Vector3.new(14, 0.1, 200), CFrame = CFrame.new(0, 0.05, 0), Color = Color3.fromRGB(240, 200, 120), Material = Enum.Material.Cobblestone, CanCollide = false }, world)
	for x = 40, 270, 40 do
		lamp(world, Vector3.new(x, 0, 10), Color3.fromRGB(255, 170, 220))
		lamp(world, Vector3.new(x, 0, -10))
	end
end

local function buildPlaza(world: Instance)
	local plaza = mk("Model", { Name = "Plaza" }, world)
	local R = Config.World.PlazaRadius
	mk("Part", { Name = "PlazaFloor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, R * 2, R * 2), CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 170, 210), Material = Enum.Material.Slate }, plaza)
	mk("Part", { Name = "PlazaRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, R * 2 + 3, R * 2 + 3), CFrame = CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 240, 140), Material = Enum.Material.Neon, CanCollide = false }, plaza)
	billboard(mk("Part", { Name = "SafeSign", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 20, 0), Transparency = 1, CanCollide = false }, plaza), "🎡 Praça segura — sem poderes aqui", UDim2.fromOffset(320, 40), Vector3.zero, Color3.fromRGB(255, 250, 200))

	for i = 1, 10 do
		local a = i * math.pi * 2 / 10
		lamp(plaza, Vector3.new(math.cos(a) * (R - 3), 0, math.sin(a) * (R - 3)), i % 2 == 0 and Color3.fromRGB(150, 220, 255) or nil)
	end

	mk("SpawnLocation", { Name = "PlazaSpawn", Size = Vector3.new(10, 1, 10), CFrame = CFrame.new(0, 0.6, 30), Color = Color3.fromRGB(255, 255, 200), Material = Enum.Material.Neon, Transparency = 0.5, Neutral = true, Duration = 0 }, plaza)

	-- Carrossel (Boo surpresa com Cash)
	local carousel = mk("Model", { Name = "Carousel" }, plaza)
	mk("Part", { Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 18, 18), CFrame = CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Marble }, carousel)
	mk("Part", { Name = "CenterPole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(14, 2, 2), CFrame = CFrame.new(0, 8, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 210, 90), Material = Enum.Material.Metal }, carousel)
	local roof = mk("Model", { Name = "Roof" }, carousel)
	for i = 0, 3 do
		mk("Part", { Name = "RoofTier", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 20 - i * 5, 20 - i * 5), CFrame = CFrame.new(0, 15 + i, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = i % 2 == 0 and Color3.fromRGB(255, 110, 170) or Color3.fromRGB(255, 255, 255), Material = Enum.Material.Fabric }, roof)
	end
	for i = 1, 6 do
		local a = i * math.pi * 2 / 6
		mk("Part", { Name = "Pole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(14, 0.4, 0.4), CFrame = CFrame.new(math.cos(a) * 7, 8, math.sin(a) * 7) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 210, 90), Material = Enum.Material.Metal, CanCollide = false }, roof)
	end
	local carouselStand = mk("Part", { Name = "CarouselStand", Size = Vector3.new(4, 3, 2), CFrame = CFrame.new(0, 1.5, 11), Color = Color3.fromRGB(255, 120, 180), Material = Enum.Material.SmoothPlastic }, carousel)
	prompt(carouselStand, "Boo surpresa", "Carrossel", 0.3, "CarouselPrompt")
	billboard(carouselStand, "🎠 Boo Surpresa", UDim2.fromOffset(200, 40), Vector3.new(0, 4, 0))
	roof:SetAttribute("Spin", 0.4) -- o cliente gira localmente

	-- Loja física
	local shop = mk("Model", { Name = "ShopStall" }, plaza)
	mk("Part", { Name = "Counter", Size = Vector3.new(14, 4, 4), CFrame = CFrame.new(0, 2, -30), Color = Color3.fromRGB(150, 90, 255), Material = Enum.Material.WoodPlanks }, shop)
	mk("Part", { Name = "PostL", Size = Vector3.new(0.8, 10, 0.8), CFrame = CFrame.new(-6.6, 5, -31.6), Color = Color3.fromRGB(255, 255, 255) }, shop)
	mk("Part", { Name = "PostR", Size = Vector3.new(0.8, 10, 0.8), CFrame = CFrame.new(6.6, 5, -31.6), Color = Color3.fromRGB(255, 255, 255) }, shop)
	stripedAwning(shop, CFrame.new(0, 10.2, -30), 16, 7, { Color3.fromRGB(255, 90, 160), Color3.fromRGB(255, 255, 255) })
	local shopPrompt = prompt(shop.Counter, "Abrir Loja", "Loja do Boo", 0, "ShopPrompt")
	shopPrompt:SetAttribute("OpenUI", "Shop") -- o cliente abre a loja (nada é concedido aqui)
	billboard(shop.Counter, "🛒 LOJA", UDim2.fromOffset(180, 50), Vector3.new(0, 10, 0), Color3.fromRGB(255, 240, 120))

	-- Estação de treino: esteira (Speed)
	local tread = mk("Model", { Name = "SpeedStation" }, plaza)
	mk("Part", { Name = "Belt", Size = Vector3.new(6, 1, 12), CFrame = CFrame.new(-28, 0.9, -4), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Rubber }, tread)
	mk("Part", { Name = "RailL", Size = Vector3.new(0.5, 4, 12), CFrame = CFrame.new(-31.2, 3, -4), Color = Color3.fromRGB(90, 220, 255), Material = Enum.Material.Metal }, tread)
	mk("Part", { Name = "RailR", Size = Vector3.new(0.5, 4, 12), CFrame = CFrame.new(-24.8, 3, -4), Color = Color3.fromRGB(90, 220, 255), Material = Enum.Material.Metal }, tread)
	local speedPanel = mk("Part", { Name = "Panel", Size = Vector3.new(6, 4, 1), CFrame = CFrame.new(-28, 4, -10.5), Color = Color3.fromRGB(90, 220, 255), Material = Enum.Material.Neon }, tread)
	prompt(speedPanel, "Treinar Speed", "Esteira", 0, "TrainPrompt"):SetAttribute("Stat", "Speed")
	billboard(speedPanel, "🏃 Treino de Speed", UDim2.fromOffset(220, 40), Vector3.new(0, 5, 0))

	-- Estação de treino: alvo (Throw Power)
	local target = mk("Model", { Name = "ThrowStation" }, plaza)
	for i, c in ipairs({ Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 80, 120), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 80, 120) }) do
		local r = 10 - (i - 1) * 2.4
		mk("Part", { Name = "Ring" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4 + i * 0.05, r, r), CFrame = CFrame.new(28, 7, -10) * CFrame.Angles(0, math.rad(90), 0), Color = c, Material = Enum.Material.SmoothPlastic }, target)
	end
	local throwPanel = mk("Part", { Name = "Pedestal", Size = Vector3.new(4, 3, 4), CFrame = CFrame.new(28, 1.5, 2), Color = Color3.fromRGB(255, 200, 80), Material = Enum.Material.SmoothPlastic }, target)
	prompt(throwPanel, "Treinar Throw", "Alvo", 0, "TrainPrompt"):SetAttribute("Stat", "Throw")
	billboard(throwPanel, "🎯 Treino de Throw", UDim2.fromOffset(220, 40), Vector3.new(0, 4, 0))

	-- Baú diário
	local chest = mk("Model", { Name = "DailyChest" }, plaza)
	local chestBase = mk("Part", { Name = "ChestBase", Size = Vector3.new(5, 3, 3.5), CFrame = CFrame.new(-16, 1.5, 24), Color = Color3.fromRGB(170, 100, 50), Material = Enum.Material.WoodPlanks }, chest)
	mk("Part", { Name = "Lid", Size = Vector3.new(5.2, 1.2, 3.7), CFrame = CFrame.new(-16, 3.6, 24), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Metal }, chest)
	prompt(chestBase, "Pegar Daily", "Baú Diário", 0.3, "DailyPrompt")
	billboard(chestBase, "🎁 Daily", UDim2.fromOffset(160, 40), Vector3.new(0, 5, 0))

	-- Painéis de leaderboard
	for i, data in ipairs({ { "CashBoard", "💰 Mais Cash (all-time)", Vector3.new(30, 0, 30) }, { "RebirthBoard", "♻️ Mais Rebirths", Vector3.new(16, 0, 38) } }) do
		local board = mk("Part", { Name = data[1], Size = Vector3.new(12, 16, 1), Color = Color3.fromRGB(40, 30, 70), Material = Enum.Material.SmoothPlastic }, plaza)
		board.CFrame = CFrame.lookAt(data[3] + Vector3.new(0, 8, 0), Vector3.new(0, 8, 0)) -- frente para o centro
		local sg = mk("SurfaceGui", { Name = "BoardGui", Face = Enum.NormalId.Front, CanvasSize = Vector2.new(400, 540), LightInfluence = 0 }, board)
		mk("TextLabel", { Name = "Title", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = Color3.fromRGB(255, 230, 120), Text = data[2] }, sg)
		mk("TextLabel", { Name = "Rows", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 70), Size = UDim2.new(1, -32, 1, -80), Font = Enum.Font.GothamBold, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.new(1, 1, 1), Text = "Carregando..." }, sg)
		board:SetAttribute("Index", i)
	end
end

local function buildPlot(plotsFolder: Instance, index: number, cf: CFrame)
	local plot = mk("Model", { Name = "Plot_" .. index }, plotsFolder)
	plot:SetAttribute("Index", index)
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("Locked", false)
	local color = PLOT_COLORS[((index - 1) % #PLOT_COLORS) + 1]
	local S = Config.World.PlotSize
	local hx, hz = S.X / 2, S.Z / 2

	local floor = mk("Part", { Name = "Floor", Size = Vector3.new(S.X, 1, S.Z), CFrame = cf * CFrame.new(0, 0.5, 0), Color = color:Lerp(Color3.new(1, 1, 1), 0.55), Material = Enum.Material.WoodPlanks }, plot)
	plot.PrimaryPart = floor
	local wallColor = color
	mk("Part", { Name = "WallBack", Size = Vector3.new(S.X, 12, 1), CFrame = cf * CFrame.new(0, 6, hz), Color = wallColor, Material = Enum.Material.WoodPlanks }, plot)
	mk("Part", { Name = "WallLeft", Size = Vector3.new(1, 12, S.Z), CFrame = cf * CFrame.new(-hx, 6, 0), Color = wallColor, Material = Enum.Material.WoodPlanks }, plot)
	mk("Part", { Name = "WallRight", Size = Vector3.new(1, 12, S.Z), CFrame = cf * CFrame.new(hx, 6, 0), Color = wallColor, Material = Enum.Material.WoodPlanks }, plot)
	local gateW = 12
	local segW = (S.X - gateW) / 2
	mk("Part", { Name = "WallFrontL", Size = Vector3.new(segW, 12, 1), CFrame = cf * CFrame.new(-(gateW / 2 + segW / 2), 6, -hz), Color = wallColor, Material = Enum.Material.WoodPlanks }, plot)
	mk("Part", { Name = "WallFrontR", Size = Vector3.new(segW, 12, 1), CFrame = cf * CFrame.new(gateW / 2 + segW / 2, 6, -hz), Color = wallColor, Material = Enum.Material.WoodPlanks }, plot)
	mk("Part", { Name = "GateTop", Size = Vector3.new(gateW, 2, 1), CFrame = cf * CFrame.new(0, 11, -hz), Color = wallColor, Material = Enum.Material.WoodPlanks }, plot)
	stripedAwning(plot, cf * CFrame.new(0, 12.4, -hz - 2), S.X, 5, { color, Color3.new(1, 1, 1) })

	-- Portão: não colide; a trava é aplicada pelo servidor (expulsa intrusos)
	mk("Part", { Name = "Gate", Size = Vector3.new(gateW, 10, 0.6), CFrame = cf * CFrame.new(0, 5, -hz), Color = Color3.fromRGB(90, 255, 140), Material = Enum.Material.ForceField, Transparency = 1, CanCollide = false, CanQuery = false }, plot)
	local light = mk("Part", { Name = "StatusLight", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = cf * CFrame.new(0, 13.2, -hz - 0.6), Color = Color3.fromRGB(255, 70, 70), Material = Enum.Material.Neon, CanCollide = false }, plot)
	mk("PointLight", { Name = "Glow", Range = 14, Brightness = 2, Color = Color3.fromRGB(255, 70, 70) }, light)

	local lockButton = mk("Part", { Name = "LockButton", Size = Vector3.new(3, 3, 3), CFrame = cf * CFrame.new(8, 1.5, -hz + 4), Color = Color3.fromRGB(60, 200, 120), Material = Enum.Material.SmoothPlastic }, plot)
	prompt(lockButton, "Trancar base", "Portão", 0.2, "LockPrompt")

	-- Placa com nome do dono e Cash/s (texto atualizado pelo PlotService)
	local sign = mk("Part", { Name = "Sign", Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, 17, -hz), Transparency = 1, CanCollide = false, CanQuery = false }, plot)
	billboard(sign, "Base livre", UDim2.fromOffset(300, 70), Vector3.zero)

	mk("Part", { Name = "OwnerSpawn", Size = Vector3.new(4, 1, 4), CFrame = cf * CFrame.new(0, 1.1, 13) * CFrame.Angles(0, math.pi, 0), Transparency = 1, CanCollide = false, CanQuery = false }, plot)
	mk("Part", { Name = "StealDrop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 7, 7), CFrame = cf * CFrame.new(-14, 1.05, -hz + 5) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 255, 160), Material = Enum.Material.Neon, Transparency = 0.4, CanCollide = false }, plot)

	-- Slots: 12 no térreo (frente -> fundo) + 4 no mezanino
	local slots = mk("Folder", { Name = "Slots" }, plot)
	local i = 0
	for _, z in ipairs({ -10, -2, 6 }) do
		for _, x in ipairs({ -15, -5, 5, 15 }) do
			i += 1
			local pad = mk("Part", { Name = "Slot_" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 6, 6), CFrame = cf * CFrame.new(x, 1.2, z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.SmoothPlastic }, slots)
			pad:SetAttribute("SlotIndex", i)
		end
	end
	-- Mezanino com escada
	mk("Part", { Name = "Mezzanine", Size = Vector3.new(S.X - 2, 1, 8), CFrame = cf * CFrame.new(0, 7, hz - 4.5), Color = color:Lerp(Color3.new(1, 1, 1), 0.4), Material = Enum.Material.WoodPlanks }, plot)
	for step = 1, 7 do
		mk("Part", { Name = "Step", Size = Vector3.new(5, 1, 2), CFrame = cf * CFrame.new(-hx + 3.5, step - 0.5 + 0.5, hz - 9 - (7 - step) * 2), Color = Color3.fromRGB(240, 230, 255), Material = Enum.Material.WoodPlanks }, plot)
	end
	for _, x in ipairs({ -10, -2, 6, 14 }) do
		i += 1
		local pad = mk("Part", { Name = "Slot_" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 6, 6), CFrame = cf * CFrame.new(x, 7.7, hz - 4.5) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.SmoothPlastic }, slots)
		pad:SetAttribute("SlotIndex", i)
	end
	for _, pad in slots:GetChildren() do
		local p = prompt(pad, "Colocar Boo", "Slot " .. pad:GetAttribute("SlotIndex"), 0, "PlacePrompt")
		p.MaxActivationDistance = 8
		p.Enabled = false -- o cliente do dono liga localmente
	end

	lamp(plot, (cf * CFrame.new(-hx - 2, 0, -hz - 2)).Position, color)
	lamp(plot, (cf * CFrame.new(hx + 2, 0, -hz - 2)).Position, color)
	return plot
end

local ZONE_ICONS = { Fairground = "🎪", Midway = "🎯", MoonLot = "🌙", SecretTent = "🔮" }

local function buildZone(zonesFolder: Instance, zone)
	local m = mk("Model", { Name = zone.name }, zonesFolder)
	m:SetAttribute("MinStat", zone.minStat)
	mk("Part", { Name = "ZoneFloor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, zone.radius * 2, zone.radius * 2), CFrame = CFrame.new(zone.center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = zone.color:Lerp(Color3.fromRGB(40, 30, 70), 0.45), Material = Enum.Material.Grass }, m)
	mk("Part", { Name = "ZoneRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, zone.radius * 2 + 2, zone.radius * 2 + 2), CFrame = CFrame.new(zone.center + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = zone.color, Material = Enum.Material.Neon, CanCollide = false }, m)
	local signPart = mk("Part", { Name = "ZoneSign", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(zone.center + Vector3.new(0, 16, 0)), Transparency = 1, CanCollide = false, CanQuery = false }, m)
	local req = zone.minStat > 0 and string.format("Precisa de %d Speed ou Throw", zone.minStat) or "Livre para todos"
	billboard(signPart, string.format("%s %s\n%s", ZONE_ICONS[zone.name] or "⭐", zone.label, req), UDim2.fromOffset(320, 80), Vector3.zero, zone.color:Lerp(Color3.new(1, 1, 1), 0.4))

	-- Decoração temática simples
	if zone.name == "Midway" then
		for k = -1, 1, 2 do
			local stall = CFrame.new(zone.center + Vector3.new(0, 0, k * (zone.radius + 6)))
			mk("Part", { Name = "Stall", Size = Vector3.new(14, 5, 5), CFrame = stall * CFrame.new(0, 2.5, 0), Color = Color3.fromRGB(255, 200, 90), Material = Enum.Material.WoodPlanks }, m)
			stripedAwning(m, stall * CFrame.new(0, 8, 0), 16, 6, { Color3.fromRGB(80, 180, 255), Color3.new(1, 1, 1) })
		end
	elseif zone.name == "MoonLot" then
		local moon = mk("Part", { Name = "BigMoon", Shape = Enum.PartType.Ball, Size = Vector3.one * 18, CFrame = CFrame.new(zone.center + Vector3.new(0, 40, 30)), Color = Color3.fromRGB(255, 245, 190), Material = Enum.Material.Neon, CanCollide = false }, m)
		mk("PointLight", { Range = 60, Brightness = 1.5, Color = Color3.fromRGB(200, 200, 255) }, moon)
	elseif zone.name == "SecretTent" then
		local base = CFrame.new(zone.center)
		for t = 0, 4 do
			local r = zone.radius * 2 + 4 - t * 9
			mk("Part", { Name = "TentTier", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.5, r, r), CFrame = base * CFrame.new(0, 16 + t * 2.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = t % 2 == 0 and Color3.fromRGB(120, 60, 200) or Color3.fromRGB(80, 255, 200), Material = Enum.Material.Fabric, CanCollide = false }, m)
		end
		for k = 1, 8 do
			local a = k * math.pi * 2 / 8
			mk("Part", { Name = "TentPole", Size = Vector3.new(1, 16, 1), CFrame = base * CFrame.new(math.cos(a) * (zone.radius + 1), 8, math.sin(a) * (zone.radius + 1)), Color = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Metal }, m)
		end
	elseif zone.name == "Fairground" then
		-- roda-gigante decorativa
		local wheelCF = CFrame.new(zone.center + Vector3.new(0, 22, -34))
		local wheel = mk("Model", { Name = "Wheel" }, m)
		for k = 1, 12 do
			local a = k * math.pi * 2 / 12
			mk("Part", { Name = "Spoke", Size = Vector3.new(0.6, 36, 0.6), CFrame = wheelCF * CFrame.Angles(0, 0, a), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Metal, CanCollide = false }, wheel)
			mk("Part", { Name = "Cabin", Shape = Enum.PartType.Ball, Size = Vector3.one * 3, CFrame = wheelCF * CFrame.Angles(0, 0, a) * CFrame.new(0, 18, 0), Color = PLOT_COLORS[(k % #PLOT_COLORS) + 1], Material = Enum.Material.Neon, CanCollide = false }, wheel)
		end
		mk("Part", { Name = "WheelLeg", Size = Vector3.new(1.5, 24, 1.5), CFrame = CFrame.new(zone.center + Vector3.new(0, 11, -36)), Color = Color3.fromRGB(200, 200, 220), Material = Enum.Material.Metal }, m)
		wheel:SetAttribute("SpinAxis", "Z")
		wheel:SetAttribute("Spin", 0.15)
	end
	return m
end

function WorldBuilder.build()
	local existing = Workspace:FindFirstChild("StealABooWorld")
	buildLighting()
	if existing then
		print("[WorldBuilder] mapa existente encontrado, não vou reconstruir")
		for _, name in { "ZoneBoos", "DroppedBoos" } do
			if not existing:FindFirstChild(name) then
				mk("Folder", { Name = name }, existing)
			end
		end
		return existing
	end
	local world = mk("Folder", { Name = "StealABooWorld" }, Workspace)
	buildGround(world)
	buildPlaza(world)

	local plots = mk("Folder", { Name = "Plots" }, world)
	local xs = { -90, -30, 30, 90 }
	local index = 0
	for row = 1, 2 do
		local z = row == 1 and 105 or -105
		local rot = row == 1 and 0 or math.pi
		for _, x in ipairs(xs) do
			index += 1
			if index <= Config.World.MaxPlayersPlotCount then
				buildPlot(plots, index, CFrame.new(x, 0, z) * CFrame.Angles(0, rot, 0))
			end
		end
	end

	local zones = mk("Folder", { Name = "Zones" }, world)
	for _, zone in ipairs(Config.Zones) do
		buildZone(zones, zone)
	end

	mk("Folder", { Name = "ZoneBoos" }, world)
	mk("Folder", { Name = "DroppedBoos" }, world)
	print("[WorldBuilder] mapa montado: " .. index .. " plots, " .. #Config.Zones .. " zonas")
	return world
end

return WorldBuilder
