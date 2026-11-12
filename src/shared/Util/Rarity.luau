local Config = require(script.Parent.Parent.Config)

local Rarity = {}

function Rarity.tier(rarityName: string): number
	local r = Config.Rarities[rarityName]
	return r and r.tier or 0
end

function Rarity.color(rarityName: string): Color3
	local r = Config.Rarities[rarityName]
	return r and r.color or Color3.new(1, 1, 1)
end

function Rarity.label(rarityName: string): string
	local r = Config.Rarities[rarityName]
	return r and r.label or rarityName
end

function Rarity.booTier(booKey: string): number
	local def = Config.Boos[booKey]
	return def and Rarity.tier(def.rarity) or 0
end

local poolCache = {}
function Rarity.pool(zoneName: string): { string }
	if poolCache[zoneName] then
		return poolCache[zoneName]
	end
	local list = {}
	for key, def in pairs(Config.Boos) do
		if def.zone == zoneName then
			table.insert(list, key)
		end
	end
	table.sort(list, function(a, b)
		local ta, tb = Rarity.booTier(a), Rarity.booTier(b)
		if ta == tb then
			return a < b
		end
		return ta < tb
	end)
	poolCache[zoneName] = list
	return list
end

function Rarity.roll(zoneName: string, luck: number, rng: Random?): string?
	local pool = Rarity.pool(zoneName)
	local total = 0
	local weights = {}
	for i, key in ipairs(pool) do
		local def = Config.Boos[key]
		local w = def.weight
		if Rarity.tier(def.rarity) >= Config.LuckAffectsFromTier then
			w *= math.max(1, luck)
		end
		weights[i] = w
		total += w
	end
	if total <= 0 then
		return nil
	end
	local pick = (rng or Random.new()):NextNumber() * total
	for i, key in ipairs(pool) do
		pick -= weights[i]
		if pick <= 0 then
			return key
		end
	end
	return pool[#pool]
end

function Rarity.better(a: string?, b: string?): string?
	if not a then
		return b
	end
	if not b then
		return a
	end
	local ta, tb = Rarity.booTier(a), Rarity.booTier(b)
	if ta ~= tb then
		return ta > tb and a or b
	end
	return Config.Boos[a].incomePerSec >= Config.Boos[b].incomePerSec and a or b
end

return Rarity
