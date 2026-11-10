--[[
	Products.luau — o que cada Dev Product entrega (lido de Config.Products[x].kind).

	Server Luck: cada compra vira uma "entrada" com mult e fim próprios.
	A sorte ativa é o MAIOR mult entre as entradas que ainda não acabaram
	(2x + 8x = 8x; quando o 8x acaba, o 2x continua até o fim dele). Ninguém perde compra.
]]
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Products = {}

local ctx
type LuckEntry = { mult: number, endsAt: number, buyer: string }
local luckEntries: { LuckEntry } = {}

function Products.serverLuck(): number
	local now = Workspace:GetServerTimeNow()
	local best = 1
	for _, e in ipairs(luckEntries) do
		if e.endsAt > now and e.mult > best then
			best = e.mult
		end
	end
	return best
end

local function publishLuck()
	local now = Workspace:GetServerTimeNow()
	for i = #luckEntries, 1, -1 do
		if luckEntries[i].endsAt <= now then
			table.remove(luckEntries, i)
		end
	end
	local best: LuckEntry? = nil
	for _, e in ipairs(luckEntries) do
		if not best or e.mult > best.mult then
			best = e
		end
	end
	Workspace:SetAttribute("ServerLuck", best and best.mult or 1)
	Workspace:SetAttribute("ServerLuckEnds", best and best.endsAt or 0)
	Workspace:SetAttribute("ServerLuckBy", best and best.buyer or "")
end

-- Por produto: retorna true se entregou
local GRANTS = {}

GRANTS.ServerLuck = function(player, data, def)
	table.insert(luckEntries, { mult = def.mult, endsAt = Workspace:GetServerTimeNow() + def.duration, buyer = player.DisplayName })
	publishLuck()
	ctx.notifyAll(string.format("%s liberou %dx Luck por %d min!", player.DisplayName, def.mult, def.duration // 60), "rare")
	ctx.fx("LuckStarted", { buyer = player.DisplayName, mult = def.mult })
	return true
end

GRANTS.PersonalCash2x = function(player, data, def)
	data.Cash2xEnds = math.max(os.time(), data.Cash2xEnds or 0) + def.duration
	return true
end

GRANTS.LuckyCaptures = function(player, data, def)
	data.LuckyCaptures += def.amount
	return true
end

GRANTS.Consumable = function(player, data, def)
	if data.Consumables[def.item] == nil then
		return false
	end
	data.Consumables[def.item] += def.amount
	return true
end

GRANTS.Cash = function(player, data, def)
	data.Cash += def.amount
	data.TotalCash += def.amount
	return true
end

-- Acha a chave do produto pelo ProductId. ID 0 nunca bate (produto não configurado).
function Products.keyById(productId: number): string?
	if type(productId) ~= "number" or productId == 0 then
		return nil
	end
	for key, def in pairs(Config.Products) do
		if def.id ~= 0 and def.id == productId then
			return key
		end
	end
	return nil
end

-- Entrega de fato. Lança erro se algo estiver errado (o ProcessReceipt trata como NotProcessedYet).
function Products.grant(player: Player, data, key: string): boolean
	local def = Config.Products[key]
	assert(def, "produto desconhecido: " .. tostring(key))
	local fn = GRANTS[def.kind]
	assert(fn, "kind sem handler: " .. tostring(def.kind))
	local ok = fn(player, data, def)
	if ok then
		ctx.notify(player, string.format("Você recebeu %s!", def.name), "success")
		ctx.fx("Purchase", { userId = player.UserId, name = def.name })
		ctx.PlayerData.markDirty(player)
	end
	return ok
end

function Products.init(c)
	ctx = c
	publishLuck()
	task.spawn(function()
		while true do
			task.wait(1)
			publishLuck()
		end
	end)
end

return Products
