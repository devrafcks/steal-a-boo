--[[
	EffectsController.luau — SÓ visual e som. Nada aqui muda o jogo.
	O servidor manda ReplicateEffect(name, payload) depois de validar a ação.

	- Boos balançando e girando de leve (tag "BooVisual"), carrossel e roda-gigante girando
	- Personagens invisíveis (atributo Invisible) ficam quase transparentes para os outros
	- Susto fofo de 1,5s (ou só um ícone, se "Reduzir sustos" estiver ligado)
	- Partículas de captura, fumaça da isca, "PAF!" do slap, confete de compra
	- Sons só tocam se o ID estiver preenchido em Config.Sounds (padrão 0 = silêncio)
]]
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Rarity = require(Shared.Util.Rarity)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UIController)
local HUD = require(script.Parent.HUD)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local T = UI.Theme

local Effects = {}

----------------------------------------------------------------------
-- Som
----------------------------------------------------------------------
local soundCache: { [string]: Sound } = {}
function Effects.play(key: string, volumeMul: number?)
	local id = Config.Sounds[key]
	if not id or id == 0 then
		return
	end
	local s = soundCache[key]
	if not s then
		s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. tostring(id)
		s.Parent = SoundService
		soundCache[key] = s
	end
	s.Volume = Config.Sounds.Volume * (volumeMul or 1)
	s:Play()
end

local music: Sound? = nil
if Config.Sounds.Music ~= 0 then
	music = Instance.new("Sound")
	music.SoundId = "rbxassetid://" .. tostring(Config.Sounds.Music)
	music.Looped = true
	music.Volume = 0.15
	music.Parent = SoundService
	music:Play()
end
State.onReady(function(data)
	if music then
		music.Volume = 0.3 * data.Settings.MusicVolume
	end
end)

----------------------------------------------------------------------
-- Balanço dos Boos e giros (local)
----------------------------------------------------------------------
local bobbing: { [Model]: { base: CFrame, phase: number } } = {}
local function track(model: Instance)
	if not model:IsA("Model") then
		return
	end
	task.defer(function()
		local body = model.PrimaryPart
		if body and body.Anchored then
			bobbing[model] = { base = model:GetPivot(), phase = math.random() * math.pi * 2 }
		end
	end)
end
for _, m in CollectionService:GetTagged("BooVisual") do
	track(m)
end
CollectionService:GetInstanceAddedSignal("BooVisual"):Connect(track)
CollectionService:GetInstanceRemovedSignal("BooVisual"):Connect(function(m)
	bobbing[m] = nil
end)

local spinners: { { model: Model, base: CFrame, speed: number, axis: string } } = {}
task.spawn(function()
	local world = Workspace:WaitForChild("StealABooWorld", 30)
	if not world then
		return
	end
	task.wait(1)
	for _, d in world:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Spin") then
			table.insert(spinners, {
				model = d,
				base = d:GetPivot(),
				speed = d:GetAttribute("Spin"),
				axis = d:GetAttribute("SpinAxis") or "Y",
			})
		end
	end
end)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local cam = Workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for model, info in pairs(bobbing) do
		if model.Parent then
			if (info.base.Position - camPos).Magnitude < 160 then
				local y = math.sin(t * 2.2 + info.phase) * 0.35
				local r = math.sin(t * 1.3 + info.phase) * 0.15
				model:PivotTo(info.base * CFrame.new(0, y, 0) * CFrame.Angles(0, r, 0))
			end
		else
			bobbing[model] = nil
		end
	end
	for _, s in ipairs(spinners) do
		if s.model.Parent then
			local a = t * s.speed
			-- gira em volta do eixo do MUNDO (Y ou Z), no centro do modelo
			local rot = s.axis == "Z" and CFrame.Angles(0, 0, a) or CFrame.Angles(0, a, 0)
			local center = CFrame.new(s.base.Position)
			s.model:PivotTo(center * rot * center:Inverse() * s.base)
		end
	end
end)

----------------------------------------------------------------------
-- Invisibilidade dos outros
----------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	for _, other in Players:GetPlayers() do
		local char = other.Character
		if char then
			local invis = char:GetAttribute("Invisible") == true
			local target = invis and (other == player and 0.6 or 0.92) or 0
			if char:GetAttribute("LocalInvisApplied") ~= target then
				char:SetAttribute("LocalInvisApplied", target)
				for _, d in char:GetDescendants() do
					if d:IsA("BasePart") or d:IsA("Decal") then
						d.LocalTransparencyModifier = target
					end
				end
			end
		end
	end
end)

----------------------------------------------------------------------
-- Partículas e textos no mundo
----------------------------------------------------------------------
local function burst(position: Vector3, color: Color3, count: number?, size: number?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = CFrame.new(position)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.6
	e.Size = NumberSequence.new(size or 0.6, 0)
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(8, 16)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = p
	p.Parent = Workspace
	e:Emit(count or 24)
	Debris:AddItem(p, 1.5)
end

local function worldText(position: Vector3, text: string, color: Color3, seconds: number?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = CFrame.new(position)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = p
	local label = UI.text(gui, { Text = text, Font = T.FontTitle, Color = color })
	p.Parent = Workspace
	TweenService:Create(
		p,
		TweenInfo.new(seconds or 1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(position + Vector3.new(0, 4, 0)) }
	):Play()
	TweenService:Create(label, TweenInfo.new(seconds or 1.2), { TextTransparency = 1 }):Play()
	Debris:AddItem(p, (seconds or 1.2) + 0.1)
end

local function characterOf(userId: number)
	local p = Players:GetPlayerByUserId(userId)
	return p and p.Character
end

local function headPos(userId: number): Vector3?
	local char = characterOf(userId)
	local head = char and char:FindFirstChild("Head")
	return head and head.Position
end

----------------------------------------------------------------------
-- Popup central (raridade, rebirth...)
----------------------------------------------------------------------
local function bigPopup(title: string, subtitle: string, color: Color3)
	local f = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(460, 130),
		BackgroundColor3 = T.Panel,
		ZIndex = 85,
		Parent = UI.overlay,
	})
	UI.corner(f, 20)
	UI.make("UIStroke", { Thickness = 5, Color = color, Parent = f })
	UI.text(f, {
		Text = title,
		Font = T.FontTitle,
		Color = color,
		Size = UDim2.new(1, -20, 0, 64),
		Position = UDim2.fromOffset(10, 8),
		ZIndex = 86,
	})
	UI.text(f, {
		Text = subtitle,
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.fromOffset(10, 78),
		ZIndex = 86,
		MaxTextSize = 26,
	})
	local scale = UI.make("UIScale", { Scale = 0.2, Parent = f })
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	task.delay(1.8, function()
		TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0 }):Play()
		task.wait(0.25)
		f:Destroy()
	end)
end

----------------------------------------------------------------------
-- Susto fofo (overlay desenhado com UI, sem imagens)
----------------------------------------------------------------------
local function cuteBooFace(parent: Instance)
	local face = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(300, 270),
		BackgroundColor3 = Color3.fromRGB(255, 190, 230),
		ZIndex = 96,
		Parent = parent,
	})
	UI.corner(face, 140)
	UI.stroke(face, 6)
	for _, x in ipairs({ 0.32, 0.68 }) do
		local eye = UI.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.42),
			Size = UDim2.fromOffset(70, 80),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 97,
			Parent = face,
		})
		UI.corner(eye, 40)
		local pupil = UI.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.6),
			Size = UDim2.fromOffset(36, 40),
			BackgroundColor3 = Color3.fromRGB(30, 20, 50),
			ZIndex = 98,
			Parent = eye,
		})
		UI.corner(pupil, 20)
	end
	local mouth = UI.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.75),
		Size = UDim2.fromOffset(70, 50),
		BackgroundColor3 = Color3.fromRGB(80, 20, 50),
		ZIndex = 97,
		Parent = face,
	})
	UI.corner(mouth, 30)
	return face
end

local function scared(payload)
	if payload.reduce then
		local icon = UI.make("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 160),
			Size = UDim2.fromOffset(200, 44),
			BackgroundColor3 = T.Pink,
			ZIndex = 95,
			Parent = UI.overlay,
		})
		UI.corner(icon, 12)
		UI.stroke(icon, 3)
		UI.text(icon, { Text = "👻 Susto de " .. tostring(payload.from), MaxTextSize = 18, ZIndex = 96 })
		task.delay(payload.duration or 1.5, function()
			icon:Destroy()
		end)
		return
	end
	Effects.play("Boo", 0.8)
	local layer = UI.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(60, 20, 90),
		BackgroundTransparency = 0.35,
		ZIndex = 95,
		Parent = UI.overlay,
	})
	local face = cuteBooFace(layer)
	UI.text(layer, {
		Text = "BOO!",
		Font = T.FontTitle,
		Color = T.Yellow,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.45, 150),
		Size = UDim2.fromOffset(400, 90),
		ZIndex = 97,
	})
	UI.text(layer, {
		Text = "susto de " .. tostring(payload.from),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.45, 236),
		Size = UDim2.fromOffset(400, 34),
		ZIndex = 97,
		MaxTextSize = 24,
	})
	local scale = UI.make("UIScale", { Scale = 0.3, Parent = face })
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	local cam = Workspace.CurrentCamera
	if cam then
		local base = cam.FieldOfView
		local punch = math.min(payload.fovPunch or 6, 8) -- nunca exagera
		cam.FieldOfView = base + punch
		TweenService:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { FieldOfView = base }):Play()
	end
	task.delay(payload.duration or 1.5, function()
		TweenService:Create(layer, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		task.wait(0.2)
		layer:Destroy()
	end)
end

----------------------------------------------------------------------
-- Tutorial (4 toasts na primeira sessão)
----------------------------------------------------------------------
local TUTORIAL = {
	"1/4 Treine Speed e Throw na praça (esteira e alvo).",
	"2/4 Vá até a Feirinha (leste) e capture um Boo.",
	"3/4 Boos vão para a sua base e geram Cash por segundo.",
	"4/4 Tranque o portão para defender ou roube Boos de bases abertas!",
}

----------------------------------------------------------------------
-- Handlers dos efeitos do servidor
----------------------------------------------------------------------
local HANDLERS = {}

HANDLERS.Capture = function(p)
	local def = Config.Boos[p.booKey]
	if not def then
		return
	end
	burst(p.position, Rarity.color(def.rarity), 30)
	if p.userId == player.UserId then
		Effects.play("Pop")
		local tier = Rarity.tier(def.rarity)
		if tier >= Rarity.tier("Rare") then
			Effects.play("RareSting")
		end
		bigPopup(
			def.name,
			Rarity.label(def.rarity)
				.. string.format("  •  $%d/s", def.incomePerSec)
				.. (p.lucky and "  •  Super Sorte!" or ""),
			Rarity.color(def.rarity)
		)
	end
end

HANDLERS.Train = function(p)
	local pos = headPos(player.UserId)
	if pos then
		worldText(
			pos + Vector3.new(0, 2, 0),
			string.format("+%.2f %s", p.gain, p.stat),
			p.stat == "Speed" and T.Cyan or T.Pink
		)
	end
	Effects.play("Coin", 0.5)
end

HANDLERS.StealAlert = function(p)
	if p.thiefId ~= player.UserId then
		UI.toast(string.format("%s está roubando %s de %s!", p.thief, p.booKey, p.victim), "info")
	end
end

HANDLERS.StealSuccess = function(p)
	burst(p.position, T.Green, 40)
	if p.userId == player.UserId then
		bigPopup("ROUBO!", p.booKey .. " agora é seu", T.Green)
		Effects.play("RareSting")
	end
end

HANDLERS.Dropped = function(p)
	burst(p.position, T.Yellow, 16)
	worldText(p.position + Vector3.new(0, 3, 0), "CAIU!", T.Yellow)
end

HANDLERS.Recovered = function(p)
	local pos = headPos(p.userId)
	if pos then
		worldText(pos, "Recuperado!", T.Green)
	end
end

HANDLERS.Poof = function(p)
	if p.position then
		burst(p.position, Color3.fromRGB(200, 200, 210), 50, 1.4)
		worldText(p.position + Vector3.new(0, 2, 0), "POOF! Era isca", T.Muted)
	end
end

HANDLERS.Slap = function(p)
	if p.position then
		burst(p.position, T.Orange, 20)
		worldText(p.position + Vector3.new(0, 3, 0), "PAF!", T.Orange)
	end
	Effects.play("Whoosh", 0.6)
end

HANDLERS.Knockback = function(p)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum and typeof(p.velocity) == "Vector3" then
		local v = p.velocity
		if v.Magnitude > 120 then
			v = v.Unit * 120
		end
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		root.AssemblyLinearVelocity = v
	end
end

HANDLERS.Freeze = function(p)
	local pos = headPos(p.to)
	if pos then
		worldText(pos + Vector3.new(0, 2, 0), "CONGELADO!", T.Cyan, p.duration)
	end
end

HANDLERS.Scared = scared

HANDLERS.ScarePop = function(p)
	local pos = headPos(p.userId)
	if pos then
		worldText(pos + Vector3.new(0, 2.5, 0), "BOO!", T.Pink, 1.5)
	end
end

HANDLERS.ScareParty = function(p)
	if p.position then
		burst(p.position, T.Pink, 60, 1)
	end
end

HANDLERS.Power = function(p)
	if p.userId == player.UserId then
		HUD.startCooldown(p.key, p.cooldown or 5)
		Effects.play("Whoosh", 0.6)
	end
	local pos = headPos(p.userId)
	if pos and (p.key == "SpeedRush" or p.key == "SuperJump") then
		burst(pos, T.Cyan, 12, 0.4)
	end
end

HANDLERS.Alarm = function(p)
	local plots = Workspace.StealABooWorld.Plots
	local plot = plots:FindFirstChild("Plot_" .. tostring(p.plotIndex))
	if not plot then
		return
	end
	if plot:GetAttribute("OwnerUserId") == player.UserId then
		Effects.play("Alarm", 0.6)
	end
	local h = Instance.new("Highlight")
	h.FillColor = T.Red
	h.FillTransparency = 0.7
	h.OutlineColor = T.Red
	h.Parent = plot
	Debris:AddItem(h, 2.5)
end

HANDLERS.GateLocked = function(p)
	local plots = Workspace.StealABooWorld.Plots
	local plot = plots:FindFirstChild("Plot_" .. tostring(p.plotIndex))
	local light = plot and plot:FindFirstChild("StatusLight")
	if light then
		burst(light.Position, T.Green, 20)
	end
end

HANDLERS.Rebirth = function(p)
	local pos = headPos(p.userId)
	if pos then
		burst(pos, T.Yellow, 60, 1)
	end
	if p.userId == player.UserId then
		bigPopup("REBIRTH " .. tostring(p.rebirths), "Renda turbinada para sempre!", T.Yellow)
	end
end

HANDLERS.Daily = function(p)
	bigPopup("DAILY!", "Dia " .. tostring(p.streak) .. " da sequência", T.Yellow)
	Effects.play("Coin")
end

HANDLERS.Coin = function(p)
	if p.userId == player.UserId then
		Effects.play("Coin")
	end
end

HANDLERS.Purchase = function(p)
	local pos = headPos(p.userId)
	if pos then
		for _, c in ipairs({ T.Pink, T.Yellow, T.Cyan }) do
			burst(pos, c, 20, 0.5)
		end
	end
end

HANDLERS.LuckStarted = function(p)
	bigPopup(string.format("%dx LUCK!", p.mult), "presente de " .. tostring(p.buyer), T.Green)
	Effects.play("RareSting")
end

HANDLERS.Tutorial = function()
	for i, line in ipairs(TUTORIAL) do
		task.delay((i - 1) * 4.5, function()
			UI.toast(line, "info")
		end)
	end
end

function Effects.init()
	Remotes.get("ReplicateEffect").OnClientEvent:Connect(function(name, payload)
		local h = HANDLERS[name]
		if h then
			local ok, err = pcall(h, payload or {})
			if not ok then
				warn("[Effects] " .. tostring(name) .. ": " .. tostring(err))
			end
		end
	end)
end

return Effects
