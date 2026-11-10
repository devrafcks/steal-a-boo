--[[
	CombatService.luau — poderes e sustos cômicos (consumíveis).

	Regras de fair play (todas no servidor):
	- Precisa ter estoque (Data.Consumables) e estar fora do cooldown.
	- Poderes de alvo (Slap, Freeze) e sustos NÃO funcionam na praça (zona neutra),
	  nem em quem acabou de nascer (SafeSpawnSeconds), nem atravessando paredes.
	- O estoque só é gasto se o efeito aconteceu (ninguém perto = não gasta).
	- Susto: 1,5s de overlay fofo no alvo. Quem marcou "Reduzir sustos" vê só um ícone.
	- Levar Slap ou susto faz o ladrão soltar o Boo roubado (defesa divertida).
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local CombatService = {}

local ctx

local CONSUMABLE_TYPE = {}
for _, c in ipairs(Config.Consumables) do
	CONSUMABLE_TYPE[c.key] = c.type
end

local function hasLineOfSight(a: Player, b: Player): boolean
	local ca, cb = a.Character, b.Character
	local pa, pb = ctx.Net.position(a), ctx.Net.position(b)
	if not (ca and cb and pa and pb) then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances =
		{ ca, cb, Workspace.StealABooWorld.ZoneBoos, Workspace.StealABooWorld.DroppedBoos }
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(pa, pb - pa, params)
	return hit == nil
end

-- Alvo é válido? (o atacante já foi checado antes)
local function validTarget(attacker: Player, target: Player, range: number, from: Vector3): boolean
	if target == attacker or not ctx.Net.alive(target) then
		return false
	end
	local pos = ctx.Net.position(target)
	if not pos or (pos - from).Magnitude > range then
		return false
	end
	if ctx.Character.isSafe(target) then
		return false
	end
	return hasLineOfSight(attacker, target)
end

local function nearestTarget(attacker: Player, range: number): Player?
	local from = ctx.Net.position(attacker)
	if not from then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, other in Players:GetPlayers() do
		if validTarget(attacker, other, range, from) then
			local d = (ctx.Net.position(other) - from).Magnitude
			if d < bestDist then
				best, bestDist = other, d
			end
		end
	end
	return best
end

local function targetsInRadius(attacker: Player, radius: number): { Player }
	local from = ctx.Net.position(attacker)
	local list = {}
	if not from then
		return list
	end
	for _, other in Players:GetPlayers() do
		if validTarget(attacker, other, radius, from) then
			table.insert(list, other)
		end
	end
	return list
end

local function attackerAllowed(player: Player): boolean
	local pos = ctx.Net.position(player)
	if not pos then
		return false
	end
	if ctx.Net.inPlaza(pos) then
		ctx.notify(player, "A praça é zona neutra. Nada de poderes aqui!", "warn")
		return false
	end
	return true
end

local function scare(attacker: Player, target: Player, duration: number, fovPunch: number)
	local tData = ctx.PlayerData.data(target)
	local reduce = tData and tData.Settings.ReduceScares or false
	ctx.fx("Scared", { from = attacker.DisplayName, duration = duration, fovPunch = fovPunch, reduce = reduce }, target)
	ctx.fx("ScarePop", { userId = target.UserId })
	ctx.Boos.dropCarried(target, "scared")
end

-- Cada efeito retorna true se aconteceu (aí gasta 1 do estoque)
local EFFECTS = {}

EFFECTS.SpeedRush = function(player)
	ctx.Character.set(player, "rushUntil", Config.Powers.SpeedRush.duration)
	return true
end

EFFECTS.SuperJump = function(player)
	ctx.Character.set(player, "jumpUntil", Config.Powers.SuperJump.duration)
	return true
end

EFFECTS.Invis = function(player)
	if ctx.Boos.isCarrying(player) then
		ctx.notify(player, "Não dá para ficar invisível carregando um Boo.", "warn")
		return false
	end
	ctx.Character.set(player, "invisUntil", Config.Powers.Invis.duration)
	return true
end

EFFECTS.Slap = function(player)
	if not attackerAllowed(player) then
		return false
	end
	local cfg = Config.Powers.Slap
	local target = nearestTarget(player, cfg.range)
	if not target then
		ctx.notify(player, "Ninguém perto para levar um Slap.", "info")
		return false
	end
	local from = ctx.Net.position(player)
	local to = ctx.Net.position(target)
	local dir = (to - from) * Vector3.new(1, 0, 1)
	dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.new(0, 0, 1)
	ctx.Boos.dropCarried(target, "slapped")
	-- O empurrão é aplicado pelo cliente do alvo (dono da física do próprio boneco)
	ctx.fx("Knockback", { velocity = dir * cfg.force + Vector3.new(0, cfg.force * 0.45, 0) }, target)
	ctx.fx("Slap", { from = player.UserId, to = target.UserId, position = to })
	ctx.notify(target, string.format("%s te deu um Boo Slap!", player.DisplayName), "danger")
	return true
end

EFFECTS.Freeze = function(player)
	if not attackerAllowed(player) then
		return false
	end
	local cfg = Config.Powers.Freeze
	local target = nearestTarget(player, cfg.range)
	if not target then
		ctx.notify(player, "Ninguém perto para congelar.", "info")
		return false
	end
	ctx.Character.set(target, "frozenUntil", cfg.duration)
	ctx.fx("Freeze", { to = target.UserId, duration = cfg.duration })
	ctx.notify(target, string.format("%s te congelou!", player.DisplayName), "danger")
	return true
end

EFFECTS.DecoyBoo = function(player)
	return ctx.Boos.spawnDecoy(player, Config.Powers.DecoyBoo.duration)
end

EFFECTS.BaseAlarm = function(player)
	if ctx.Plots.alarm(player, Config.Powers.BaseAlarm.duration) then
		ctx.notify(player, string.format("Alarme ligado por %ds.", Config.Powers.BaseAlarm.duration), "success")
		return true
	end
	return false
end

EFFECTS.ScareClassic = function(player)
	if not attackerAllowed(player) then
		return false
	end
	local cfg = Config.Scares.Classic
	local target = nearestTarget(player, cfg.range)
	if not target then
		ctx.notify(player, "Ninguém perto para assustar.", "info")
		return false
	end
	scare(player, target, cfg.duration, cfg.maxFovPunch)
	return true
end

EFFECTS.ScareParty = function(player)
	if not attackerAllowed(player) then
		return false
	end
	local cfg = Config.Scares.Party
	local list = targetsInRadius(player, cfg.radius)
	if #list == 0 then
		ctx.notify(player, "Ninguém por perto para a festa do susto.", "info")
		return false
	end
	for _, t in ipairs(list) do
		scare(player, t, cfg.duration, Config.Scares.Classic.maxFovPunch)
	end
	ctx.fx("ScareParty", { from = player.UserId, position = ctx.Net.position(player), radius = cfg.radius })
	return true
end

local COOLDOWNS = {
	SpeedRush = Config.Powers.SpeedRush.cooldown,
	SuperJump = Config.Powers.SuperJump.cooldown,
	Invis = Config.Powers.Invis.cooldown,
	Slap = Config.Powers.Slap.cooldown,
	Freeze = Config.Powers.Freeze.cooldown,
	DecoyBoo = Config.Powers.DecoyBoo.cooldown,
	BaseAlarm = Config.Powers.BaseAlarm.cooldown,
	ScareClassic = Config.Scares.Classic.cooldown,
	ScareParty = Config.Scares.Party.cooldown,
}

local function use(player: Player, key, expectedType: string)
	if not ctx.Net.isString(key) or CONSUMABLE_TYPE[key] ~= expectedType then
		return
	end
	local data = ctx.PlayerData.data(player)
	if not data or not ctx.Net.alive(player) then
		return
	end
	if (data.Consumables[key] or 0) <= 0 then
		ctx.notify(player, "Você não tem esse item. Pegue na Loja!", "info")
		return
	end
	local left = ctx.Net.cooldownLeft(player, "use_" .. key)
	if left > 0 then
		ctx.notify(player, string.format("Recarregando: %.1fs", left), "info")
		return
	end
	if ctx.Character.isFrozen(player) then
		return
	end
	local ok = EFFECTS[key](player)
	if ok then
		data.Consumables[key] -= 1
		ctx.Net.cooldown(player, "use_" .. key, COOLDOWNS[key] or 5)
		ctx.fx("Power", { userId = player.UserId, key = key, cooldown = COOLDOWNS[key] or 5 })
		ctx.PlayerData.markDirty(player)
	end
end

function CombatService.init(c)
	ctx = c
	ctx.Net.on("RequestUsePower", function(player, key)
		use(player, key, "Power")
	end)
	ctx.Net.on("RequestUseScare", function(player, key)
		use(player, key, "Scare")
	end)
end

return CombatService
