--[[
	WorldBuilder.luau — monta o mapa inteiro quando o jogo começa.

	Se já existir workspace.StealABooWorld (você editou o mapa à mão e salvou),
	ele NÃO reconstrói: só usa o que está lá (mesmos nomes de peças).

	Layout (vista de cima, +X = leste):
	  - Terreno de grama (Terrain) com lago, morros e mata em volta
	  - Praça neutra no centro (0,0,0), raio Config.World.PlazaRadius
	  - 8 bases: 4 ao norte (z = -105) e 4 ao sul (z = +105), frente virada para a praça
	  - Zonas de captura a leste (Feirinha, Corredor, Terreno da Lua) e a Tenda Secreta a oeste

	Visual: primitivas + MaterialVariants gerados (Config.Materials) + modelos gratuitos
	do Creator Store guardados em ServerStorage.ExternalAssets (ver assets/CREDITS.md).
	Se algum desses não existir, usa a versão feita com primitivas.
]]
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local WorldBuilder = {}

local M = Config.Materials
local P = Config.Plot
local rng = Random.new(20261110) -- semente fixa: o mapa sai igual em todo servidor

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

local function billboard(
	parent: Instance,
	text: string,
	size: UDim2,
	offset: Vector3,
	color: Color3?,
	maxDistance: number?
)
	local gui = mk("BillboardGui", {
		Name = "Label",
		Size = size,
		StudsOffsetWorldSpace = offset,
		MaxDistance = maxDistance or 120,
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
	mk("Part", {
		Name = "Pole",
		Size = Vector3.new(0.6, 12, 0.6),
		CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)),
		Color = Color3.fromRGB(50, 40, 70),
		Material = Enum.Material.Metal,
	}, m)
	mk("Part", {
		Name = "Cap",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 2.6, 2.6),
		CFrame = CFrame.new(pos + Vector3.new(0, 13.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(50, 40, 70),
		Material = Enum.Material.Metal,
	}, m)
	local bulb = mk("Part", {
		Name = "Bulb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.8,
		CFrame = CFrame.new(pos + Vector3.new(0, 12.5, 0)),
		Color = color or Color3.fromRGB(255, 220, 140),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, m)
	mk(
		"PointLight",
		{ Range = 22, Brightness = 1.3, Color = color or Color3.fromRGB(255, 210, 150), Shadows = false },
		bulb
	)
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
			MaterialVariant = M.Tent,
			CanCollide = false,
		}, parent)
	end
end

-- Coloca um modelo com a base encostada no chão (y = groundY)
local function placeOnGround(model: Model, pos: Vector3, yaw: number?, groundY: number?)
	model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0))
	local cf, size = model:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, (groundY or 0) - bottom, 0))
	return model
end

-- Clona um modelo de ServerStorage.ExternalAssets (nil se não existir)
local function asset(name: string): Model?
	local folder = ServerStorage:FindFirstChild("ExternalAssets")
	local src = folder and folder:FindFirstChild(name)
	if not src or not src:IsA("Model") then
		return nil
	end
	local c = src:Clone()
	for _, d in c:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy() -- nunca roda script de modelo de terceiros
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return c
end

----------------------------------------------------------------------
-- Céu e luz
----------------------------------------------------------------------
local function buildLighting()
	Lighting.ClockTime = 22.4
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(80, 65, 115)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 110, 170)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	-- Sky padrão do engine (estrelas e lua embutidas), com lua grande e muitas estrelas
	mk("Sky", {
		StarCount = 5000,
		MoonAngularSize = 24,
		SunAngularSize = 0,
		CelestialBodiesShown = true,
	}, Lighting)
	mk("Atmosphere", {
		Density = 0.22,
		Offset = 0.05,
		Color = Color3.fromRGB(170, 120, 210),
		Decay = Color3.fromRGB(90, 60, 150),
		Glare = 0.25,
		Haze = 1.0,
	}, Lighting)
	mk("BloomEffect", { Intensity = 0.5, Size = 26, Threshold = 1.5 }, Lighting)
	mk("SunRaysEffect", { Intensity = 0.04, Spread = 0.6 }, Lighting)
	mk(
		"ColorCorrectionEffect",
		{ Brightness = 0.04, Contrast = 0.1, Saturation = 0.2, TintColor = Color3.fromRGB(255, 242, 235) },
		Lighting
	)

	-- Nuvens rosadas
	local terrain = Workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.45
	clouds.Color = Color3.fromRGB(255, 190, 230)
	clouds.Parent = terrain
end

----------------------------------------------------------------------
-- Chão: grama, lago, morros, caminhos
----------------------------------------------------------------------
local function buildGround(world: Instance)
	local terrain = Workspace.Terrain
	terrain:Clear()
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(80, 150, 90))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(70, 135, 85))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(240, 210, 160))
	-- (a graminha 3D é Terrain.Decoration, ligada no Studio: não pode ser alterada por script em jogo)
	terrain.WaterColor = Color3.fromRGB(90, 160, 220)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.1

	-- Chão inteiro de grama (topo em y = 0)
	terrain:FillBlock(CFrame.new(0, -10, 0), Vector3.new(760, 16, 760), Enum.Material.Grass) -- o FillBlock arredonda 2 studs para cima: superfície fica em y = 0
	-- Morros fora do mapa (horizonte)
	for i = 1, 22 do
		local a = i * math.pi * 2 / 22
		local r = 360 + rng:NextNumber(0, 40)
		terrain:FillBall(
			Vector3.new(math.cos(a) * r, -10, math.sin(a) * r),
			rng:NextNumber(50, 85),
			Enum.Material.LeafyGrass
		)
	end
	-- Lago com areia (sul-oeste das bases do norte)
	terrain:FillCylinder(CFrame.new(-10, -2, -225), 6, 36, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(-10, -3, -225), 8, 30, Enum.Material.Water)

	-- Embaixo de construções e caminhos: terra batida (sem graminha atravessando o chão)
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(150, 115, 85))
	local function dirt(center: Vector3, size: Vector3)
		local half = size / 2
		local region = Region3.new(center - Vector3.new(half.X, 8, half.Z), center + Vector3.new(half.X, 4, half.Z))
			:ExpandToGrid(4)
		terrain:ReplaceMaterial(region, 4, Enum.Material.Grass, Enum.Material.Ground)
	end
	dirt(Vector3.zero, Vector3.new(104, 0, 104)) -- praça
	for _, x in ipairs({ -90, -30, 30, 90 }) do
		dirt(Vector3.new(x, 0, 105), Vector3.new(56, 0, 56))
		dirt(Vector3.new(x, 0, -105), Vector3.new(56, 0, 56))
	end
	for _, zone in ipairs(Config.Zones) do
		dirt(zone.center, Vector3.new(zone.radius * 2 + 6, 0, zone.radius * 2 + 6))
	end
	dirt(Vector3.new(155, 0, 0), Vector3.new(236, 0, 18))
	dirt(Vector3.new(-95, 0, 0), Vector3.new(116, 0, 18))
	dirt(Vector3.new(0, 0, 0), Vector3.new(18, 0, 236))
	dirt(Vector3.new(0, 0, -72), Vector3.new(206, 0, 14))
	dirt(Vector3.new(0, 0, 72), Vector3.new(206, 0, 14))

	-- Paredes invisíveis do limite do mapa
	local half = 320
	for _, data in
		{
			{ Vector3.new(half, 60, 0), Vector3.new(2, 120, 660) },
			{ Vector3.new(-half, 60, 0), Vector3.new(2, 120, 660) },
			{ Vector3.new(0, 60, half), Vector3.new(660, 120, 2) },
			{ Vector3.new(0, 60, -half), Vector3.new(660, 120, 2) },
		}
	do
		mk(
			"Part",
			{ Name = "Boundary", Size = data[2], CFrame = CFrame.new(data[1]), Transparency = 1, CanQuery = false },
			world
		)
	end

	-- Caminhos de pedra até as zonas e bases
	local paths = {
		{ "PathEast", Vector3.new(230, 0.2, 14), CFrame.new(155, 0.1, 0) },
		{ "PathWest", Vector3.new(110, 0.2, 14), CFrame.new(-95, 0.1, 0) },
		{ "PathNS", Vector3.new(14, 0.2, 230), CFrame.new(0, 0.1, 0) },
		{ "PathPlotsN", Vector3.new(200, 0.2, 10), CFrame.new(0, 0.1, -72) },
		{ "PathPlotsS", Vector3.new(200, 0.2, 10), CFrame.new(0, 0.1, 72) },
	}
	for _, p in ipairs(paths) do
		mk("Part", {
			Name = p[1],
			Size = p[2],
			CFrame = p[3],
			Color = Color3.fromRGB(245, 215, 175),
			Material = Enum.Material.Cobblestone,
			MaterialVariant = M.Cobble,
			CanCollide = false,
		}, world)
	end
	for x = 40, 270, 40 do
		lamp(world, Vector3.new(x, 0, 10), Color3.fromRGB(255, 170, 220))
		lamp(world, Vector3.new(x, 0, -10))
	end
	for x = -90, 90, 60 do
		lamp(world, Vector3.new(x, 0, -66), Color3.fromRGB(150, 220, 255))
		lamp(world, Vector3.new(x, 0, 66), Color3.fromRGB(150, 220, 255))
	end
end

----------------------------------------------------------------------
-- Natureza e decoração
----------------------------------------------------------------------
local function primitiveTree(parent: Instance, pos: Vector3, scale: number)
	local m = mk("Model", { Name = "Tree" }, parent)
	local trunkH = 8 * scale
	mk("Part", {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(trunkH, 1.6 * scale, 1.6 * scale),
		CFrame = CFrame.new(pos + Vector3.new(0, trunkH / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 80, 55),
		Material = Enum.Material.Wood,
	}, m)
	local green = Color3.fromRGB(70, 160 + rng:NextInteger(-20, 20), 90)
	for k = 0, 2 do
		mk("Part", {
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (7 - k * 1.6) * scale,
			CFrame = CFrame.new(
				pos + Vector3.new(rng:NextNumber(-0.6, 0.6), trunkH + k * 2.6 * scale, rng:NextNumber(-0.6, 0.6))
			),
			Color = green:Lerp(Color3.fromRGB(150, 220, 140), k * 0.15),
			Material = Enum.Material.Grass,
		}, m)
	end
	return m
end

local function bush(parent: Instance, pos: Vector3)
	local m = mk("Model", { Name = "Bush" }, parent)
	local base = Color3.fromRGB(60, 140 + rng:NextInteger(-15, 25), 75)
	for _ = 1, 3 do
		mk("Part", {
			Name = "Leaf",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(2.2, 3.6),
			CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-1.4, 1.4), 1, rng:NextNumber(-1.4, 1.4))),
			Color = base,
			Material = Enum.Material.Grass,
			CanCollide = false,
		}, m)
	end
	if rng:NextNumber() < 0.5 then
		local flower = ({ Color3.fromRGB(255, 120, 190), Color3.fromRGB(255, 230, 90), Color3.fromRGB(200, 150, 255) })[rng:NextInteger(
			1,
			3
		)]
		for _ = 1, 4 do
			mk("Part", {
				Name = "Flower",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.6,
				CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-1.6, 1.6), 2.2, rng:NextNumber(-1.6, 1.6))),
				Color = flower,
				Material = Enum.Material.Neon,
				CanCollide = false,
			}, m)
		end
	end
	return m
end

-- Lugares onde NÃO pode ter árvore (praça, bases, zonas, caminhos, lago)
local function isFree(x: number, z: number): boolean
	if Vector2.new(x, z).Magnitude < 70 then
		return false
	end
	if math.abs(x) < 130 and math.abs(z) > 60 and math.abs(z) < 150 then
		return false -- bases
	end
	if math.abs(z) < 24 and x > -180 and x < 290 then
		return false -- caminhos leste/oeste
	end
	if math.abs(x) < 16 and math.abs(z) < 140 then
		return false
	end
	for _, zone in ipairs(Config.Zones) do
		if (Vector2.new(x, z) - Vector2.new(zone.center.X, zone.center.Z)).Magnitude < zone.radius + 26 then
			return false
		end
	end
	if (Vector2.new(x, z) - Vector2.new(-10, -225)).Magnitude < 46 then
		return false -- lago
	end
	return math.abs(x) < 306 and math.abs(z) < 306
end

local function buildNature(world: Instance)
	local nature = mk("Folder", { Name = "Nature" }, world)
	local trees, bushes = 0, 0
	for _ = 1, 600 do
		if trees >= 90 then
			break
		end
		local x, z = rng:NextNumber(-305, 305), rng:NextNumber(-305, 305)
		if isFree(x, z) then
			local model = asset("Tree")
			if model then
				model.Name = "Tree"
				model:ScaleTo(rng:NextNumber(0.55, 0.95))
				placeOnGround(model, Vector3.new(x, 0, z), rng:NextNumber(0, math.pi * 2), -0.3)
				model.Parent = nature
			else
				primitiveTree(nature, Vector3.new(x, 0, z), rng:NextNumber(0.9, 1.5))
			end
			trees += 1
		end
	end
	for _ = 1, 600 do
		if bushes >= 110 then
			break
		end
		local x, z = rng:NextNumber(-305, 305), rng:NextNumber(-305, 305)
		if isFree(x, z) or (math.abs(z) > 140 and math.abs(z) < 160) then
			bush(nature, Vector3.new(x, 0, z))
			bushes += 1
		end
	end
	-- Arbustos em volta da praça e na frente das bases
	for i = 1, 16 do
		local a = i * math.pi * 2 / 16 + 0.1
		bush(nature, Vector3.new(math.cos(a) * 52, 0, math.sin(a) * 52))
	end
end

local function balloonBunch(parent: Instance, pos: Vector3)
	local colors = {
		Color3.fromRGB(255, 90, 150),
		Color3.fromRGB(90, 200, 255),
		Color3.fromRGB(255, 220, 80),
		Color3.fromRGB(170, 110, 255),
	}
	local m = mk("Model", { Name = "Balloons" }, parent)
	for k = 1, 5 do
		local top = pos + Vector3.new(rng:NextNumber(-1.5, 1.5), 9 + rng:NextNumber(0, 3), rng:NextNumber(-1.5, 1.5))
		mk("Part", {
			Name = "Balloon",
			Size = Vector3.new(2, 2.4, 2),
			CFrame = CFrame.new(top),
			Color = colors[(k % #colors) + 1],
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		}, m):SetAttribute("Bob", true)
		local mid = (pos + top) / 2
		mk("Part", {
			Name = "String",
			Size = Vector3.new(0.08, (top - pos).Magnitude, 0.08),
			CFrame = CFrame.lookAt(mid, top) * CFrame.Angles(math.rad(90), 0, 0),
			Color = Color3.new(1, 1, 1),
			CanCollide = false,
		}, m)
	end
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	for _, b in m:GetChildren() do
		if b.Name == "Balloon" then
			mesh:Clone().Parent = b
		end
	end
	return m
end

local function buildDecor(world: Instance)
	local decor = mk("Folder", { Name = "Decor" }, world)
	-- Bancos na praça, virados para o centro
	for i = 0, 3 do
		local a = math.rad(45 + i * 90)
		local pos = Vector3.new(math.cos(a) * 36, 0, math.sin(a) * 36)
		local bench = asset("Bench")
		if bench then
			placeOnGround(bench, pos, -a + math.pi / 2, 0.4).Parent = decor
		end
	end
	-- Carrinhos de pipoca
	for _, data in ipairs({
		{ Vector3.new(-34, 0, -24), math.rad(40) },
		{ Vector3.new(125, 0, 18), math.rad(-90) },
		{ Vector3.new(195, 0, -18), math.rad(90) },
	}) do
		local cart = asset("PopcornCart")
		if cart then
			placeOnGround(cart, data[1], data[2], 0.4).Parent = decor
		end
	end
	-- Varais de luzes atravessando o caminho
	for _, x in ipairs({ 55, 135, 215 }) do
		local lights = asset("StringLights")
		if lights then
			placeOnGround(lights, Vector3.new(x, 0, 0), 0, 0.2).Parent = decor
		end
	end
	-- Balões
	for _, pos in ipairs({
		Vector3.new(9, 0, 14),
		Vector3.new(-9, 0, 14),
		Vector3.new(40, 0, 14),
		Vector3.new(-40, 0, -14),
	}) do
		balloonBunch(decor, pos)
	end
end

----------------------------------------------------------------------
-- Praça
----------------------------------------------------------------------
local function buildPlaza(world: Instance)
	local plaza = mk("Model", { Name = "Plaza" }, world)
	local R = Config.World.PlazaRadius
	mk("Part", {
		Name = "PlazaFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, R * 2, R * 2),
		CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(235, 220, 255),
		Material = Enum.Material.Pavement,
		MaterialVariant = M.Tiles,
	}, plaza)
	mk("Part", {
		Name = "PlazaRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, R * 2 + 3, R * 2 + 3),
		CFrame = CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 240, 140),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, plaza)
	billboard(
		mk("Part", {
			Name = "SafeSign",
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(0, 24, 0),
			Transparency = 1,
			CanCollide = false,
		}, plaza),
		"🎡 Praça segura — sem poderes aqui",
		UDim2.fromOffset(300, 36),
		Vector3.zero,
		Color3.fromRGB(255, 250, 200),
		90
	)

	for i = 1, 10 do
		local a = i * math.pi * 2 / 10
		lamp(
			plaza,
			Vector3.new(math.cos(a) * (R - 3), 0, math.sin(a) * (R - 3)),
			i % 2 == 0 and Color3.fromRGB(150, 220, 255) or nil
		)
	end

	mk("SpawnLocation", {
		Name = "PlazaSpawn",
		Size = Vector3.new(10, 1, 10),
		CFrame = CFrame.new(0, 0.6, 30),
		Color = Color3.fromRGB(255, 255, 200),
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		Neutral = true,
		Duration = 0,
	}, plaza)

	-- Carrossel (Boo surpresa com Cash)
	local carousel = mk("Model", { Name = "Carousel" }, plaza)
	mk("Part", {
		Name = "Base",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 18, 18),
		CFrame = CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Marble,
	}, carousel)
	mk("Part", {
		Name = "CenterPole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(14, 2, 2),
		CFrame = CFrame.new(0, 8, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 210, 90),
		Material = Enum.Material.Metal,
	}, carousel)
	local roof = mk("Model", { Name = "Roof" }, carousel)
	for i = 0, 3 do
		mk("Part", {
			Name = "RoofTier",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 20 - i * 5, 20 - i * 5),
			CFrame = CFrame.new(0, 15 + i, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = i % 2 == 0 and Color3.fromRGB(255, 110, 170) or Color3.fromRGB(255, 255, 255),
			Material = Enum.Material.Fabric,
			MaterialVariant = M.Tent,
		}, roof)
	end
	for i = 1, 6 do
		local a = i * math.pi * 2 / 6
		mk("Part", {
			Name = "Pole",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(14, 0.4, 0.4),
			CFrame = CFrame.new(math.cos(a) * 7, 8, math.sin(a) * 7) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 210, 90),
			Material = Enum.Material.Metal,
			CanCollide = false,
		}, roof)
		mk("Part", {
			Name = "Bulb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9,
			CFrame = CFrame.new(math.cos(a) * 9.6, 14.3, math.sin(a) * 9.6),
			Color = Color3.fromRGB(255, 230, 140),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, roof)
	end
	local carouselStand = mk("Part", {
		Name = "CarouselStand",
		Size = Vector3.new(4, 3, 2),
		CFrame = CFrame.new(0, 1.5, 11),
		Color = Color3.fromRGB(255, 120, 180),
		Material = Enum.Material.SmoothPlastic,
	}, carousel)
	prompt(carouselStand, "Boo surpresa", "Carrossel", 0.3, "CarouselPrompt")
	billboard(carouselStand, "🎠 Boo Surpresa", UDim2.fromOffset(180, 36), Vector3.new(0, 4, 0), nil, 70)
	roof:SetAttribute("Spin", 0.4) -- o cliente gira localmente

	-- Loja física
	local shop = mk("Model", { Name = "ShopStall" }, plaza)
	mk("Part", {
		Name = "Counter",
		Size = Vector3.new(14, 4, 4),
		CFrame = CFrame.new(0, 2, -30),
		Color = Color3.fromRGB(255, 200, 230),
		Material = Enum.Material.WoodPlanks,
		MaterialVariant = M.Planks,
	}, shop)
	for _, x in ipairs({ -6.6, 6.6 }) do
		mk("Part", {
			Name = "Post",
			Size = Vector3.new(0.8, 10, 0.8),
			CFrame = CFrame.new(x, 5, -31.6),
			Color = Color3.fromRGB(255, 255, 255),
		}, shop)
	end
	stripedAwning(
		shop,
		CFrame.new(0, 10.2, -30),
		16,
		7,
		{ Color3.fromRGB(255, 90, 160), Color3.fromRGB(255, 255, 255) }
	)
	local shopPrompt = prompt(shop.Counter, "Abrir Loja", "Loja do Boo", 0, "ShopPrompt")
	shopPrompt:SetAttribute("OpenUI", "Shop") -- o cliente abre a loja (nada é concedido aqui)
	billboard(
		shop.Counter,
		"🛒 LOJA",
		UDim2.fromOffset(160, 44),
		Vector3.new(0, 10, 0),
		Color3.fromRGB(255, 240, 120),
		110
	)

	-- Estação de treino: esteira (Speed)
	local tread = mk("Model", { Name = "SpeedStation" }, plaza)
	local belt = mk("Part", {
		Name = "Belt",
		Size = Vector3.new(6, 1, 12),
		CFrame = CFrame.new(-28, 0.9, -4),
		Color = Color3.fromRGB(200, 200, 210),
		Material = Enum.Material.Rubber,
		MaterialVariant = M.Belt,
	}, tread)
	belt:SetAttribute("Conveyor", true)
	for _, x in ipairs({ -31.2, -24.8 }) do
		mk("Part", {
			Name = "Rail",
			Size = Vector3.new(0.5, 4, 12),
			CFrame = CFrame.new(x, 3, -4),
			Color = Color3.fromRGB(90, 220, 255),
			Material = Enum.Material.Metal,
		}, tread)
	end
	local speedPanel = mk("Part", {
		Name = "Panel",
		Size = Vector3.new(6, 4, 1),
		CFrame = CFrame.new(-28, 4, -10.5),
		Color = Color3.fromRGB(90, 220, 255),
		Material = Enum.Material.Neon,
	}, tread)
	prompt(speedPanel, "Treinar Speed", "Esteira", 0, "TrainPrompt"):SetAttribute("Stat", "Speed")
	billboard(speedPanel, "🏃 Treino de Speed", UDim2.fromOffset(200, 36), Vector3.new(0, 5, 0), nil, 80)

	-- Estação de treino: alvo (Throw Power)
	local target = mk("Model", { Name = "ThrowStation" }, plaza)
	for i, c in ipairs({
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(255, 80, 120),
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(255, 80, 120),
	}) do
		local r = 10 - (i - 1) * 2.4
		mk("Part", {
			Name = "Ring" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4 + i * 0.05, r, r),
			CFrame = CFrame.new(28, 7, -10) * CFrame.Angles(0, math.rad(90), 0),
			Color = c,
			Material = Enum.Material.SmoothPlastic,
		}, target)
	end
	mk("Part", {
		Name = "TargetLeg",
		Size = Vector3.new(1, 7, 1),
		CFrame = CFrame.new(28, 3.5, -10.5),
		Color = Color3.fromRGB(120, 80, 55),
		Material = Enum.Material.Wood,
	}, target)
	local throwPanel = mk("Part", {
		Name = "Pedestal",
		Size = Vector3.new(4, 3, 4),
		CFrame = CFrame.new(28, 1.5, 2),
		Color = Color3.fromRGB(255, 200, 80),
		Material = Enum.Material.SmoothPlastic,
	}, target)
	prompt(throwPanel, "Treinar Throw", "Alvo", 0, "TrainPrompt"):SetAttribute("Stat", "Throw")
	billboard(throwPanel, "🎯 Treino de Throw", UDim2.fromOffset(200, 36), Vector3.new(0, 4, 0), nil, 80)

	-- Baú diário
	local chest = mk("Model", { Name = "DailyChest" }, plaza)
	local chestBase = mk("Part", {
		Name = "ChestBase",
		Size = Vector3.new(5, 3, 3.5),
		CFrame = CFrame.new(-16, 1.5, 24),
		Color = Color3.fromRGB(170, 100, 50),
		Material = Enum.Material.WoodPlanks,
	}, chest)
	mk("Part", {
		Name = "Lid",
		Size = Vector3.new(5.2, 1.2, 3.7),
		CFrame = CFrame.new(-16, 3.6, 24),
		Color = Color3.fromRGB(255, 200, 60),
		Material = Enum.Material.Metal,
	}, chest)
	local glow = mk("Part", {
		Name = "Glow",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.6,
		CFrame = CFrame.new(-16, 4.5, 24),
		Color = Color3.fromRGB(255, 230, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 1,
	}, chest)
	mk("PointLight", { Range = 12, Brightness = 2, Color = Color3.fromRGB(255, 220, 120) }, glow)
	prompt(chestBase, "Pegar Daily", "Baú Diário", 0.3, "DailyPrompt")
	billboard(chestBase, "🎁 Daily", UDim2.fromOffset(140, 36), Vector3.new(0, 5, 0), nil, 80)

	-- Painéis de leaderboard
	for i, data in ipairs({
		{ "CashBoard", "💰 Mais Cash (all-time)", Vector3.new(-22, 0, -54) },
		{ "RebirthBoard", "♻️ Mais Rebirths", Vector3.new(22, 0, -54) },
	}) do
		local board = mk("Part", {
			Name = data[1],
			Size = Vector3.new(12, 16, 1),
			Color = Color3.fromRGB(40, 30, 70),
			Material = Enum.Material.SmoothPlastic,
		}, plaza)
		board.CFrame = CFrame.lookAt(data[3] + Vector3.new(0, 8, 0), Vector3.new(0, 8, 0))
		local sg = mk(
			"SurfaceGui",
			{ Name = "BoardGui", Face = Enum.NormalId.Front, CanvasSize = Vector2.new(400, 540), LightInfluence = 0 },
			board
		)
		mk("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 60),
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 230, 120),
			Text = data[2],
		}, sg)
		mk("TextLabel", {
			Name = "Rows",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(16, 70),
			Size = UDim2.new(1, -32, 1, -80),
			Font = Enum.Font.GothamBold,
			TextSize = 26,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "Carregando...",
		}, sg)
		board:SetAttribute("Index", i)
	end
end

----------------------------------------------------------------------
-- Bases
----------------------------------------------------------------------
local function buildPlot(plotsFolder: Instance, index: number, cf: CFrame)
	local plot = mk("Model", { Name = "Plot_" .. index }, plotsFolder)
	plot:SetAttribute("Index", index)
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("Locked", false)
	local color = PLOT_COLORS[((index - 1) % #PLOT_COLORS) + 1]
	plot:SetAttribute("Color", color)
	local S = Config.World.PlotSize
	local hx, hz = S.X / 2, S.Z / 2
	local H = P.FloorHeight
	local wallColor = color:Lerp(Color3.new(1, 1, 1), 0.25)

	local floor = mk("Part", {
		Name = "Floor",
		Size = Vector3.new(S.X, 1, S.Z),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Color = color:Lerp(Color3.new(1, 1, 1), 0.6),
		Material = Enum.Material.WoodPlanks,
		MaterialVariant = M.Planks,
	}, plot)
	plot.PrimaryPart = floor
	local function wall(name, size, offset)
		return mk("Part", {
			Name = name,
			Size = size,
			CFrame = cf * offset,
			Color = wallColor,
			Material = Enum.Material.WoodPlanks,
			MaterialVariant = M.Planks,
		}, plot)
	end
	wall("WallBack", Vector3.new(S.X, H, 1), CFrame.new(0, H / 2, hz))
	wall("WallLeft", Vector3.new(1, H, S.Z), CFrame.new(-hx, H / 2, 0))
	wall("WallRight", Vector3.new(1, H, S.Z), CFrame.new(hx, H / 2, 0))
	local gateW = 12
	local segW = (S.X - gateW) / 2
	wall("WallFrontL", Vector3.new(segW, H, 1), CFrame.new(-(gateW / 2 + segW / 2), H / 2, -hz))
	wall("WallFrontR", Vector3.new(segW, H, 1), CFrame.new(gateW / 2 + segW / 2, H / 2, -hz))
	wall("GateTop", Vector3.new(gateW, H - 10, 1), CFrame.new(0, 10 + (H - 10) / 2, -hz))
	stripedAwning(plot, cf * CFrame.new(0, H + 0.4, -hz - 2), S.X, 5, { color, Color3.new(1, 1, 1) })
	-- Luzinhas no topo do muro
	for x = -hx + 2, hx - 2, 4 do
		mk("Part", {
			Name = "WallLight",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.8,
			CFrame = cf * CFrame.new(x, H + 0.6, -hz - 0.4),
			Color = (x % 8 == 0) and Color3.fromRGB(255, 230, 120) or color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, plot)
	end

	-- Portão: não colide; a trava é aplicada pelo servidor (expulsa intrusos)
	mk("Part", {
		Name = "Gate",
		Size = Vector3.new(gateW, 10, 0.6),
		CFrame = cf * CFrame.new(0, 5, -hz),
		Color = Color3.fromRGB(90, 255, 140),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, plot)
	local light = mk("Part", {
		Name = "StatusLight",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		CFrame = cf * CFrame.new(0, H + 1.4, -hz - 0.6),
		Color = Color3.fromRGB(255, 70, 70),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, plot)
	mk("PointLight", { Name = "Glow", Range = 14, Brightness = 2, Color = Color3.fromRGB(255, 70, 70) }, light)

	local lockButton = mk("Part", {
		Name = "LockButton",
		Size = Vector3.new(3, 3, 3),
		CFrame = cf * CFrame.new(8, 1.5, -hz + 4),
		Color = Color3.fromRGB(60, 200, 120),
		Material = Enum.Material.SmoothPlastic,
	}, plot)
	prompt(lockButton, "Trancar base", "Portão", 0.2, "LockPrompt")
	billboard(lockButton, "🔒 Portão", UDim2.fromOffset(110, 28), Vector3.new(0, 3, 0), nil, 50)

	-- Placa com nome do dono e Cash/s (texto atualizado pelo PlotService)
	local sign = mk("Part", {
		Name = "Sign",
		Size = Vector3.one,
		CFrame = cf * CFrame.new(0, H + 5, -hz),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, plot)
	billboard(sign, "Base livre", UDim2.fromOffset(200, 48), Vector3.zero, nil, 110)
	-- Luz quente dentro da base (a feira é à noite)
	local inner = mk(
		"Part",
		{
			Name = "InnerLight",
			Size = Vector3.one,
			CFrame = cf * CFrame.new(0, 11, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		},
		plot
	)
	mk("PointLight", { Range = 34, Brightness = 1.2, Color = Color3.fromRGB(255, 225, 200), Shadows = false }, inner)

	mk("Part", {
		Name = "OwnerSpawn",
		Size = Vector3.new(4, 1, 4),
		CFrame = cf * CFrame.new(0, 1.1, 12) * CFrame.Angles(0, math.pi, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, plot)
	mk("Part", {
		Name = "StealDrop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 7, 7),
		CFrame = cf * CFrame.new(-14, 1.05, -hz + 5) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 255, 160),
		Material = Enum.Material.Neon,
		Transparency = 0.4,
		CanCollide = false,
	}, plot)

	-- Esteira de coleta + cofre (pise no pad dourado para coletar)
	local collector = mk("Part", {
		Name = "CollectorBelt",
		Size = Vector3.new(16, 0.5, 4),
		CFrame = cf * CFrame.new(0, 1.25, 19),
		Color = Color3.fromRGB(220, 220, 230),
		Material = Enum.Material.Rubber,
		MaterialVariant = M.Belt,
	}, plot)
	collector:SetAttribute("Conveyor", true)
	local pad = mk("Part", {
		Name = "CollectPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 7, 7),
		CFrame = cf * CFrame.new(12.5, 1.2, 19) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 210, 60),
		Material = Enum.Material.Neon,
	}, plot)
	billboard(pad, "Cofre", UDim2.fromOffset(170, 40), Vector3.new(0, 4, 0), Color3.fromRGB(255, 230, 120), 80)
	mk("PointLight", { Range = 12, Brightness = 1.5, Color = Color3.fromRGB(255, 210, 90) }, pad)

	-- Esteiras pagas 2x / 3x / 4x (o prompt abre a compra no cliente)
	local belts = {
		{ "Belt2x", "2x", Color3.fromRGB(90, 220, 140), -12 },
		{ "Belt3x", "3x", Color3.fromRGB(255, 170, 70), -4 },
		{ "Belt4x", "4x", Color3.fromRGB(255, 90, 170), 4 },
	}
	for _, b in ipairs(belts) do
		local def = Config.Products[b[1]]
		local part = mk("Part", {
			Name = "PaidBelt_" .. b[2],
			Size = Vector3.new(4, 0.5, 7),
			CFrame = cf * CFrame.new(20.5, 1.25, b[4]),
			Color = b[3],
			Material = Enum.Material.Rubber,
			MaterialVariant = M.Belt,
		}, plot)
		part:SetAttribute("Conveyor", true)
		part:SetAttribute("BoostMult", def.mult)
		local p = prompt(part, "Ativar " .. b[2] .. " (R$" .. def.price .. ")", "Esteira paga", 0.2, "BeltPrompt")
		p:SetAttribute("BuyProduct", b[1])
		p.MaxActivationDistance = 8
		billboard(
			part,
			string.format("%s RENDA\n2 min · R$%d", b[2], def.price),
			UDim2.fromOffset(120, 44),
			Vector3.new(0, 3.5, 0),
			b[3],
			60
		)
	end

	-- Placa de upgrade (construir andares)
	local board = mk("Part", {
		Name = "UpgradeBoard",
		Size = Vector3.new(6, 5, 0.6),
		CFrame = cf * CFrame.new(-hx + 1, 3.5, -14) * CFrame.Angles(0, math.rad(-90), 0),
		Color = Color3.fromRGB(255, 240, 200),
		Material = Enum.Material.WoodPlanks,
		MaterialVariant = M.Planks,
	}, plot)
	prompt(board, "Construir andar", "Melhorar base", 0.3, "UpgradePrompt").MaxActivationDistance = 9
	billboard(
		board,
		"🏗️ Melhorar base",
		UDim2.fromOffset(150, 34),
		Vector3.new(0, 4, 0),
		Color3.fromRGB(255, 240, 150),
		60
	)

	-- Elevador do térreo (o andar 2 só existe depois do upgrade)
	local lift = mk("Part", {
		Name = "LiftUp",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 5, 5),
		CFrame = cf * CFrame.new(-19, 1.2, 19) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(90, 220, 255),
		Material = Enum.Material.Neon,
	}, plot)
	lift:SetAttribute("Target", "Level_2Landing")
	mk("ProximityPrompt", {
		ActionText = "Subir",
		ObjectText = "Elevador",
		HoldDuration = 0.15,
		MaxActivationDistance = 7,
		RequiresLineOfSight = false,
	}, lift)
	billboard(lift, "SUBIR", UDim2.fromOffset(90, 30), Vector3.new(0, 2.5, 0), nil, 60)
	mk("Part", {
		Name = "GroundLanding",
		Size = Vector3.new(4, 0.2, 4),
		CFrame = cf * CFrame.new(-19, 1.1, 13),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, plot)

	-- Slots do térreo (frente -> fundo); andares de cima são criados pelo PlotService
	local slots = mk("Folder", { Name = "Slots" }, plot)
	local i = 0
	for _, z in ipairs({ -10, -2, 6 }) do
		for _, x in ipairs({ -15, -5, 5, 15 }) do
			i += 1
			local slot = mk("Part", {
				Name = "Slot_" .. i,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.4, 6, 6),
				CFrame = cf * CFrame.new(x, 1.2, z) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(255, 255, 255),
				Material = Enum.Material.SmoothPlastic,
			}, slots)
			slot:SetAttribute("SlotIndex", i)
		end
	end

	lamp(plot, (cf * CFrame.new(-hx - 2, 0, -hz - 2)).Position, color)
	lamp(plot, (cf * CFrame.new(hx + 2, 0, -hz - 2)).Position, color)
	return plot
end

----------------------------------------------------------------------
-- Zonas de captura
----------------------------------------------------------------------
local ZONE_ICONS = { Fairground = "🎪", Midway = "🎯", MoonLot = "🌙", SecretTent = "🔮" }

local function buildZone(zonesFolder: Instance, zone)
	local m = mk("Model", { Name = zone.name }, zonesFolder)
	m:SetAttribute("MinStat", zone.minStat)
	mk("Part", {
		Name = "ZoneFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, zone.radius * 2, zone.radius * 2),
		CFrame = CFrame.new(zone.center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = zone.color:Lerp(Color3.new(1, 1, 1), 0.35),
		Material = Enum.Material.Pavement,
		MaterialVariant = M.Tiles,
	}, m)
	mk("Part", {
		Name = "ZoneRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, zone.radius * 2 + 2, zone.radius * 2 + 2),
		CFrame = CFrame.new(zone.center + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = zone.color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, m)
	-- Arco de entrada
	local archCF = CFrame.new(zone.center + Vector3.new(-zone.radius - 2, 0, 0)) * CFrame.Angles(0, math.rad(90), 0)
	if zone.name == "SecretTent" then
		archCF = CFrame.new(zone.center + Vector3.new(zone.radius + 2, 0, 0)) * CFrame.Angles(0, math.rad(90), 0)
	end
	for side = -1, 1, 2 do
		mk("Part", {
			Name = "ArchPost",
			Size = Vector3.new(1.4, 14, 1.4),
			CFrame = archCF * CFrame.new(side * 9, 7, 0),
			Color = zone.color,
			Material = Enum.Material.SmoothPlastic,
		}, m)
	end
	local archTop = mk("Part", {
		Name = "ArchTop",
		Size = Vector3.new(20, 3, 1.2),
		CFrame = archCF * CFrame.new(0, 15, 0),
		Color = zone.color:Lerp(Color3.new(1, 1, 1), 0.3),
		Material = Enum.Material.SmoothPlastic,
	}, m)
	local req = zone.minStat > 0 and string.format("Precisa de %d Speed ou Throw", zone.minStat) or "Livre para todos"
	billboard(
		archTop,
		string.format("%s %s", ZONE_ICONS[zone.name] or "⭐", zone.label),
		UDim2.fromOffset(260, 40),
		Vector3.new(0, 3.5, 0),
		zone.color:Lerp(Color3.new(1, 1, 1), 0.4),
		160
	)
	billboard(
		mk("Part", {
			Name = "ZoneSign",
			Size = Vector3.one,
			CFrame = archCF * CFrame.new(0, 11, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		}, m),
		req,
		UDim2.fromOffset(240, 26),
		Vector3.zero,
		Color3.new(1, 1, 1),
		80
	)

	if zone.name == "Midway" then
		for k = -1, 1, 2 do
			local stall = CFrame.new(zone.center + Vector3.new(0, 0, k * (zone.radius + 6)))
			mk("Part", {
				Name = "Stall",
				Size = Vector3.new(14, 5, 5),
				CFrame = stall * CFrame.new(0, 2.5, 0),
				Color = Color3.fromRGB(255, 230, 190),
				Material = Enum.Material.WoodPlanks,
				MaterialVariant = M.Planks,
			}, m)
			stripedAwning(m, stall * CFrame.new(0, 8, 0), 16, 6, { Color3.fromRGB(80, 180, 255), Color3.new(1, 1, 1) })
		end
	elseif zone.name == "MoonLot" then
		local moon = mk("Part", {
			Name = "BigMoon",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 18,
			CFrame = CFrame.new(zone.center + Vector3.new(0, 40, 30)),
			Color = Color3.fromRGB(255, 245, 190),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, m)
		mk("PointLight", { Range = 60, Brightness = 1.5, Color = Color3.fromRGB(200, 200, 255) }, moon)
	elseif zone.name == "SecretTent" then
		local base = CFrame.new(zone.center)
		for t = 0, 4 do
			local r = zone.radius * 2 + 4 - t * 9
			mk("Part", {
				Name = "TentTier",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(2.5, r, r),
				CFrame = base * CFrame.new(0, 16 + t * 2.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Color = t % 2 == 0 and Color3.fromRGB(150, 90, 230) or Color3.fromRGB(120, 255, 210),
				Material = Enum.Material.Fabric,
				MaterialVariant = M.Tent,
				CanCollide = false,
			}, m)
		end
		for k = 1, 8 do
			local a = k * math.pi * 2 / 8
			mk("Part", {
				Name = "TentPole",
				Size = Vector3.new(1, 16, 1),
				CFrame = base * CFrame.new(math.cos(a) * (zone.radius + 1), 8, math.sin(a) * (zone.radius + 1)),
				Color = Color3.fromRGB(255, 220, 120),
				Material = Enum.Material.Metal,
			}, m)
		end
	elseif zone.name == "Fairground" then
		-- roda-gigante decorativa
		local wheelCF = CFrame.new(zone.center + Vector3.new(0, 22, -34))
		local wheel = mk("Model", { Name = "Wheel" }, m)
		for k = 1, 12 do
			local a = k * math.pi * 2 / 12
			mk("Part", {
				Name = "Spoke",
				Size = Vector3.new(0.6, 36, 0.6),
				CFrame = wheelCF * CFrame.Angles(0, 0, a),
				Color = Color3.fromRGB(255, 255, 255),
				Material = Enum.Material.Metal,
				CanCollide = false,
			}, wheel)
			mk("Part", {
				Name = "Cabin",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 3,
				CFrame = wheelCF * CFrame.Angles(0, 0, a) * CFrame.new(0, 18, 0),
				Color = PLOT_COLORS[(k % #PLOT_COLORS) + 1],
				Material = Enum.Material.Neon,
				CanCollide = false,
			}, wheel)
		end
		mk("Part", {
			Name = "WheelLeg",
			Size = Vector3.new(1.5, 24, 1.5),
			CFrame = CFrame.new(zone.center + Vector3.new(0, 11, -36)),
			Color = Color3.fromRGB(200, 200, 220),
			Material = Enum.Material.Metal,
		}, m)
		wheel:SetAttribute("SpinAxis", "Z")
		wheel:SetAttribute("Spin", 0.15)
	end
	return m
end

----------------------------------------------------------------------

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
	-- Remove o Baseplate e o SpawnLocation que vêm no place vazio do Studio
	for _, name in { "Baseplate", "SpawnLocation" } do
		local default = Workspace:FindFirstChild(name)
		if default and default:IsA("BasePart") then
			default:Destroy()
		end
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

	buildNature(world)
	buildDecor(world)

	mk("Folder", { Name = "ZoneBoos" }, world)
	mk("Folder", { Name = "DroppedBoos" }, world)
	print("[WorldBuilder] mapa montado: " .. index .. " plots, " .. #Config.Zones .. " zonas")
	return world
end

return WorldBuilder
