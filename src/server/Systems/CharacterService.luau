--[[
	CharacterService.luau — tudo que mexe no boneco, decidido SÓ no servidor.

	WalkSpeed = BaseWalkSpeed + Speed (treino), limitado a MaxSpeed
	  * Speed Rush: pelo menos Powers.SpeedRush.walkSpeed
	  * carregando Boo roubado: * StealCarrySpeedPenalty
	  * congelado: 0
	Também cuida de: super pulo, invisibilidade, proteção ao nascer, tag/aura VIP.
]]
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local CharacterService = {}

local ctx
type State = { rushUntil: number, jumpUntil: number, frozenUntil: number, invisUntil: number, safeUntil: number }
local states: { [Player]: State } = {}

local function state(player: Player): State
	local s = states[player]
	if not s then
		s = { rushUntil = 0, jumpUntil = 0, frozenUntil = 0, invisUntil = 0, safeUntil = 0 }
		states[player] = s
	end
	return s
end

function CharacterService.set(player: Player, field: string, seconds: number)
	local s = state(player)
	s[field] = math.max(s[field], os.clock() + seconds)
	CharacterService.refresh(player)
end

-- só a proteção de quem acabou de nascer (a praça NÃO conta): usada para socar/tomar de ladrões
function CharacterService.isSpawnSafe(player: Player): boolean
	return state(player).safeUntil > os.clock()
end

function CharacterService.isSafe(player: Player): boolean
	local s = state(player)
	if s.safeUntil > os.clock() then
		return true
	end
	local pos = ctx.Net.position(player)
	return pos ~= nil and ctx.Net.inPlaza(pos)
end

function CharacterService.isInvisible(player: Player): boolean
	return state(player).invisUntil > os.clock()
end

function CharacterService.isFrozen(player: Player): boolean
	return state(player).frozenUntil > os.clock()
end

local function setFrozenVisual(char: Model, on: boolean)
	local h = char:FindFirstChild("FreezeHighlight")
	if on and not h then
		h = Instance.new("Highlight")
		h.Name = "FreezeHighlight"
		h.FillColor = Color3.fromRGB(150, 230, 255)
		h.FillTransparency = 0.35
		h.OutlineColor = Color3.new(1, 1, 1)
		h.Parent = char
	elseif not on and h then
		h:Destroy()
	end
end

function CharacterService.refresh(player: Player)
	local char, hum = ctx.Net.alive(player)
	if not char then
		return
	end
	local data = ctx.PlayerData.data(player)
	local s = state(player)
	local now = os.clock()
	local E = Config.Economy

	local speed = math.min(E.BaseWalkSpeed + (data and data.Speed or 0), E.MaxSpeed)
	if s.rushUntil > now then
		speed = math.max(speed * 1.35, Config.Powers.SpeedRush.walkSpeed)
	end
	if ctx.Boos.isCarrying(player) then
		speed *= Config.World.StealCarrySpeedPenalty
	end
	local frozen = s.frozenUntil > now
	if frozen then
		speed = 0
	end
	hum.WalkSpeed = speed
	hum.UseJumpPower = true
	hum.JumpPower = frozen and 0 or (s.jumpUntil > now and Config.Powers.SuperJump.jumpPower or 50)
	setFrozenVisual(char, frozen)

	local invis = s.invisUntil > now
	if char:GetAttribute("Invisible") ~= invis then
		char:SetAttribute("Invisible", invis) -- os outros clientes aplicam a transparência
		hum.DisplayDistanceType = invis and Enum.HumanoidDisplayDistanceType.None
			or Enum.HumanoidDisplayDistanceType.Viewer
	end
	char:SetAttribute("Safe", s.safeUntil > now)
end

-- Tag VIP e aura (cosmético do passe)
function CharacterService.applyCosmetics(player: Player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local vip = ctx.Passes.owns(player, "VIP")
	local tag = head:FindFirstChild("VIPTag")
	if vip and not tag then
		tag = Instance.new("BillboardGui")
		tag.Name = "VIPTag"
		tag.Size = UDim2.fromOffset(80, 26)
		tag.StudsOffset = Vector3.new(0, 2.6, 0)
		tag.MaxDistance = 80
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.LuckiestGuy
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(255, 215, 60)
		t.TextStrokeTransparency = 0.2
		t.Text = "VIP"
		t.Parent = tag
		tag.Parent = head

		local root = char:FindFirstChild("HumanoidRootPart")
		if root and not root:FindFirstChild("VIPAura") then
			local aura = Instance.new("ParticleEmitter")
			aura.Name = "VIPAura"
			aura.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 120, 200))
			aura.LightEmission = 0.7
			aura.Size = NumberSequence.new(0.35, 0)
			aura.Lifetime = NumberRange.new(0.8, 1.4)
			aura.Rate = 8
			aura.Speed = NumberRange.new(0.5, 1.5)
			aura.SpreadAngle = Vector2.new(180, 180)
			aura.Parent = root
		end
	elseif not vip and tag then
		tag:Destroy()
	end
end

local function onCharacter(player: Player, char: Model)
	local s = state(player)
	s.frozenUntil = 0
	s.invisUntil = 0
	s.safeUntil = os.clock() + Config.World.SafeSpawnSeconds
	local hum = char:WaitForChild("Humanoid", 5) :: Humanoid
	if not hum then
		return
	end
	hum.Died:Connect(function()
		ctx.Boos.dropCarried(player, "died")
	end)
	task.wait()
	CharacterService.refresh(player)
	CharacterService.applyCosmetics(player)
end

function CharacterService.init(c)
	ctx = c
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(p)
		states[p] = nil
	end)

	-- Expira efeitos e reaplica velocidades
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, p in Players:GetPlayers() do
				CharacterService.refresh(p)
			end
		end
	end)
end

return CharacterService
