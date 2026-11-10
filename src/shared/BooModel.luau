--[[
	BooModel.luau — monta o modelo visual de um Boo SÓ com primitivas do Studio.
	Nenhum mesh/textura externo: corpo redondinho, olhões, bochechas e um acessório
	diferente por Boo (Config.Boos[x].accessory). Raridade alta ganha luz e brilho.

	O modelo é leve: 1 corpo + poucas peças soldadas, sem colisão.
	O "balançar" fofo é feito no cliente (EffectsController) via tag "BooVisual".
]]
local CollectionService = game:GetService("CollectionService")

local Config = require(script.Parent.Config)
local Rarity = require(script.Parent.Util.Rarity)

local BooModel = {}

local function part(props): BasePart
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		if k ~= "ClassName" and k ~= "Mesh" then
			p[k] = v
		end
	end
	if props.Mesh then
		local m = Instance.new("SpecialMesh")
		m.MeshType = props.Mesh.Type or Enum.MeshType.Sphere
		m.Scale = props.Mesh.Scale or Vector3.one
		m.Parent = p
	end
	return p
end

-- Solda `p` no corpo, numa posição relativa (offset em CFrame do corpo)
local function attach(model: Model, body: BasePart, p: BasePart, offset: CFrame)
	p.CFrame = body.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

local function lighten(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), amount)
end

local ACCESSORIES = {}

ACCESSORIES.Stick = function(model, body, s, _def)
	attach(
		model,
		body,
		part({
			Name = "Stick",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.2 * s, 0.25 * s, 0.25 * s),
			Color = Color3.fromRGB(150, 100, 60),
			Material = Enum.Material.Wood,
		}),
		CFrame.new(0, -1.9 * s, 0) * CFrame.Angles(0, 0, math.rad(90))
	)
end

ACCESSORIES.Fluff = function(model, body, s, def)
	for i = -1, 1 do
		attach(
			model,
			body,
			part({
				Name = "Fluff",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 1.1 * s,
				Color = lighten(def.color, 0.35),
			}),
			CFrame.new(i * 0.7 * s, 1.35 * s, -0.1 * s)
		)
	end
end

ACCESSORIES.Ticket = function(model, body, s, _def)
	attach(
		model,
		body,
		part({ Name = "Ticket", Size = Vector3.new(1.6 * s, 0.9 * s, 0.1 * s), Color = Color3.fromRGB(255, 90, 90) }),
		CFrame.new(0.4 * s, 1.5 * s, 0) * CFrame.Angles(0, 0, math.rad(-20))
	)
end

ACCESSORIES.Popcorn = function(model, body, s, _def)
	attach(
		model,
		body,
		part({ Name = "Bucket", Size = Vector3.new(1.4 * s, 0.9 * s, 1.4 * s), Color = Color3.fromRGB(230, 60, 60) }),
		CFrame.new(0, 1.45 * s, 0)
	)
	for i = 1, 4 do
		local a = i * math.pi / 2
		attach(
			model,
			body,
			part({
				Name = "Kernel",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.55 * s,
				Color = Color3.fromRGB(255, 240, 170),
			}),
			CFrame.new(math.cos(a) * 0.35 * s, 2.0 * s, math.sin(a) * 0.35 * s)
		)
	end
end

ACCESSORIES.Sprinkles = function(model, body, s, _def)
	local colors = {
		Color3.fromRGB(255, 90, 160),
		Color3.fromRGB(255, 230, 80),
		Color3.fromRGB(90, 160, 255),
		Color3.fromRGB(255, 255, 255),
	}
	for i = 1, 8 do
		local a = i * math.pi / 4
		attach(
			model,
			body,
			part({ Name = "Sprinkle", Size = Vector3.new(0.12, 0.12, 0.4) * s, Color = colors[(i % #colors) + 1] }),
			CFrame.new(math.cos(a) * 1.0 * s, 0.9 * s, math.sin(a) * 1.0 * s) * CFrame.Angles(0, a, math.rad(30))
		)
	end
end

ACCESSORIES.Lamp = function(model, body, s, _def)
	attach(
		model,
		body,
		part({ Name = "Stalk", Size = Vector3.new(0.15, 0.9, 0.15) * s, Color = Color3.fromRGB(60, 50, 60) }),
		CFrame.new(0, 1.6 * s, 0)
	)
	local bulb = attach(
		model,
		body,
		part({
			Name = "Bulb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.7 * s,
			Color = Color3.fromRGB(255, 230, 120),
			Material = Enum.Material.Neon,
		}),
		CFrame.new(0, 2.15 * s, 0)
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 120)
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = bulb
end

ACCESSORIES.Balloon = function(model, body, s, _def)
	attach(
		model,
		body,
		part({ Name = "String", Size = Vector3.new(0.06, 2.2, 0.06) * s, Color = Color3.new(1, 1, 1) }),
		CFrame.new(0.9 * s, 2.0 * s, 0)
	)
	attach(
		model,
		body,
		part({
			Name = "Balloon",
			Size = Vector3.new(1.3, 1.6, 1.3) * s,
			Color = Color3.fromRGB(255, 80, 110),
			Mesh = { Type = Enum.MeshType.Sphere },
		}),
		CFrame.new(0.9 * s, 3.4 * s, 0)
	)
end

ACCESSORIES.Wobble = function(model, body, s, def)
	body.Material = Enum.Material.Glass
	body.Transparency = 0.25
	attach(
		model,
		body,
		part({
			Name = "Core",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.2 * s,
			Color = lighten(def.color, 0.4),
			Material = Enum.Material.Neon,
		}),
		CFrame.new(0, -0.2 * s, 0.2 * s)
	)
end

ACCESSORIES.Pole = function(model, body, s, _def)
	attach(
		model,
		body,
		part({
			Name = "Pole",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(5 * s, 0.3 * s, 0.3 * s),
			Color = Color3.fromRGB(255, 210, 90),
			Material = Enum.Material.Metal,
		}),
		CFrame.new(0, 0.5 * s, -0.9 * s) * CFrame.Angles(0, 0, math.rad(90))
	)
end

ACCESSORIES.Moon = function(model, body, s, def)
	attach(
		model,
		body,
		part({
			Name = "Moon",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9 * s,
			Color = Color3.fromRGB(255, 245, 170),
			Material = Enum.Material.Neon,
		}),
		CFrame.new(-0.7 * s, 1.55 * s, 0)
	)
	attach(
		model,
		body,
		part({ Name = "MoonBite", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.75 * s, Color = def.color }),
		CFrame.new(-0.4 * s, 1.7 * s, 0)
	)
end

ACCESSORIES.Comet = function(model, body, s, _def)
	for i = 1, 3 do
		attach(
			model,
			body,
			part({
				Name = "Tail",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * (1.1 - i * 0.25) * s,
				Color = Color3.fromRGB(140, 200, 255),
				Material = Enum.Material.Neon,
				Transparency = 0.15 * i,
			}),
			CFrame.new(0, 0.6 * s, (0.9 + i * 0.7) * s)
		)
	end
end

ACCESSORIES.Star = function(model, body, s, _def)
	for i = 0, 2 do
		attach(
			model,
			body,
			part({
				Name = "StarRay",
				Size = Vector3.new(1.6, 0.35, 0.2) * s,
				Color = Color3.fromRGB(255, 240, 90),
				Material = Enum.Material.Neon,
			}),
			CFrame.new(0, 1.8 * s, 0) * CFrame.Angles(0, 0, math.rad(i * 60))
		)
	end
end

ACCESSORIES.Crystal = function(model, body, s, _def)
	body.Material = Enum.Material.Glass
	body.Transparency = 0.15
	attach(
		model,
		body,
		part({
			Name = "Gem",
			Size = Vector3.one * 0.9 * s,
			Color = Color3.fromRGB(120, 255, 255),
			Material = Enum.Material.Neon,
		}),
		CFrame.new(0, 1.8 * s, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	)
end

ACCESSORIES.Prism = function(model, body, s, _def)
	local colors = {
		Color3.fromRGB(255, 90, 90),
		Color3.fromRGB(255, 220, 80),
		Color3.fromRGB(90, 255, 140),
		Color3.fromRGB(90, 160, 255),
	}
	for i, c in ipairs(colors) do
		local a = (i - 1) * math.pi / 2
		attach(
			model,
			body,
			part({ Name = "Shard", Size = Vector3.new(0.3, 0.9, 0.3) * s, Color = c, Material = Enum.Material.Neon }),
			CFrame.new(math.cos(a) * 0.6 * s, 1.55 * s, math.sin(a) * 0.6 * s) * CFrame.Angles(0, a, math.rad(20))
		)
	end
end

ACCESSORIES.Aurora = function(model, body, s, _def)
	attach(
		model,
		body,
		part({
			Name = "Halo",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, 2.4, 2.4) * s,
			Color = Color3.fromRGB(120, 255, 220),
			Material = Enum.Material.Neon,
			Transparency = 0.2,
		}),
		CFrame.new(0, 2.0 * s, 0) * CFrame.Angles(0, 0, math.rad(90))
	)
end

ACCESSORIES.Crown = function(model, body, s, _def)
	attach(
		model,
		body,
		part({
			Name = "CrownBase",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 1.5, 1.5) * s,
			Color = Color3.fromRGB(255, 200, 40),
			Material = Enum.Material.Metal,
		}),
		CFrame.new(0, 1.5 * s, 0) * CFrame.Angles(0, 0, math.rad(90))
	)
	for i = 1, 5 do
		local a = i * math.pi * 2 / 5
		attach(
			model,
			body,
			part({
				Name = "CrownGem",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.35 * s,
				Color = Color3.fromRGB(255, 60, 120),
				Material = Enum.Material.Neon,
			}),
			CFrame.new(math.cos(a) * 0.6 * s, 1.95 * s, math.sin(a) * 0.6 * s)
		)
	end
end

--[[
	BooModel.build(booKey, opts)
	opts.scale (number)   tamanho (padrão 1)
	opts.anchored (bool)  corpo ancorado (zonas e slots) ou não (carregado)
	opts.cframe (CFrame)  posição inicial
	opts.decoy (bool)     visual de isca (um pouquinho transparente)
]]
function BooModel.build(booKey: string, opts): Model
	opts = opts or {}
	local def = Config.Boos[booKey]
	assert(def, "Boo desconhecido: " .. tostring(booKey))
	local s = opts.scale or 1

	local model = Instance.new("Model")
	model.Name = def.name

	local body = part({
		Name = "Body",
		Size = Vector3.new(3, 2.7, 3) * s,
		Color = def.color,
		Mesh = { Type = Enum.MeshType.Sphere },
		CanQuery = true,
	})
	body.Anchored = opts.anchored ~= false
	body.CFrame = opts.cframe or CFrame.new()
	body.Parent = model
	model.PrimaryPart = body

	-- Olhões (frente = -Z do corpo)
	for side = -1, 1, 2 do
		attach(
			model,
			body,
			part({
				Name = "Eye",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.95 * s,
				Color = Color3.new(1, 1, 1),
			}),
			CFrame.new(side * 0.55 * s, 0.25 * s, -1.05 * s)
		)
		attach(
			model,
			body,
			part({
				Name = "Pupil",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.5 * s,
				Color = Color3.fromRGB(30, 25, 40),
			}),
			CFrame.new(side * 0.55 * s, 0.22 * s, -1.42 * s)
		)
		attach(
			model,
			body,
			part({
				Name = "Shine",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.16 * s,
				Color = Color3.new(1, 1, 1),
				Material = Enum.Material.Neon,
			}),
			CFrame.new(side * 0.55 * s + 0.12 * s, 0.36 * s, -1.6 * s)
		)
		attach(
			model,
			body,
			part({
				Name = "Cheek",
				Size = Vector3.new(0.5, 0.25, 0.15) * s,
				Color = Color3.fromRGB(255, 130, 160),
				Mesh = { Type = Enum.MeshType.Sphere },
			}),
			CFrame.new(side * 0.95 * s, -0.25 * s, -1.15 * s)
		)
	end
	attach(
		model,
		body,
		part({
			Name = "Mouth",
			Size = Vector3.new(0.35, 0.25, 0.12) * s,
			Color = Color3.fromRGB(60, 20, 40),
			Mesh = { Type = Enum.MeshType.Sphere },
		}),
		CFrame.new(0, -0.35 * s, -1.38 * s)
	)

	local acc = ACCESSORIES[def.accessory]
	if acc then
		acc(model, body, s, def)
	end

	-- Brilho por raridade
	local tier = Rarity.tier(def.rarity)
	if tier >= Rarity.tier("Epic") then
		local glow = Instance.new("PointLight")
		glow.Color = Rarity.color(def.rarity)
		glow.Range = 8 + tier
		glow.Brightness = 1
		glow.Parent = body
	end
	if tier >= Rarity.tier("Legendary") then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "RaritySparkle"
		sparkle.Color = ColorSequence.new(Rarity.color(def.rarity))
		sparkle.LightEmission = 0.8
		sparkle.Size = NumberSequence.new(0.25 * s, 0)
		sparkle.Lifetime = NumberRange.new(0.6, 1.1)
		sparkle.Rate = 6 + tier
		sparkle.Speed = NumberRange.new(1, 2)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = body
	end

	if opts.decoy then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = math.max(d.Transparency, 0.1)
			end
		end
	end

	model:SetAttribute("BooKey", booKey)
	model:SetAttribute("Rarity", def.rarity)
	CollectionService:AddTag(model, "BooVisual")
	return model
end

-- Billboard com nome, raridade e renda (usado em zonas e slots)
function BooModel.addLabel(model: Model, extraText: string?)
	local key = model:GetAttribute("BooKey")
	local def = Config.Boos[key]
	if not def then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BooLabel"
	gui.Size = UDim2.fromOffset(130, 42)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 45
	gui.LightInfluence = 0

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.5)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Text = def.name
	name.Parent = gui

	local info = Instance.new("TextLabel")
	info.BackgroundTransparency = 1
	info.Position = UDim2.fromScale(0, 0.5)
	info.Size = UDim2.fromScale(1, 0.5)
	info.Font = Enum.Font.FredokaOne
	info.TextScaled = true
	info.TextColor3 = Rarity.color(def.rarity)
	info.TextStrokeTransparency = 0.3
	info.Text = extraText or string.format("%s • $%d/s", Rarity.label(def.rarity), def.incomePerSec)
	info.Parent = gui

	gui.Parent = model.PrimaryPart
	return gui
end

return BooModel
