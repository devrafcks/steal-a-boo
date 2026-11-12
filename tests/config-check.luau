--!nocheck

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local errors: { string } = {}
local warnings: { string } = {}
local function fail(msg: string)
	table.insert(errors, msg)
end
local function warnMsg(msg: string)
	table.insert(warnings, msg)
end

local source = fs.readFile("src/shared/Config.luau")
local chunk = luau.load(source, {
	debugName = "Config.luau",
	environment = {
		Vector3 = {
			new = function(x, y, z)
				return { X = x, Y = y, Z = z }
			end,
		},
		Color3 = {
			fromRGB = function(r, g, b)
				return { R = r, G = g, B = b }
			end,
		},
	},
})
local Config = chunk()

local function count(t): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

local booModel = fs.readFile("src/shared/BooModel.luau")
local zoneNames = {}
for _, z in ipairs(Config.Zones) do
	zoneNames[z.name] = true
	if type(z.minStat) ~= "number" or z.minStat < 0 then
		fail("zona " .. z.name .. ": minStat inválido")
	end
end
local boosPerZone = {}
for key, def in pairs(Config.Boos) do
	if def.name ~= key then
		fail("Boo " .. key .. ": name diferente da chave (" .. tostring(def.name) .. ")")
	end
	if not Config.Rarities[def.rarity] then
		fail("Boo " .. key .. ": raridade inexistente '" .. tostring(def.rarity) .. "'")
	end
	if not zoneNames[def.zone] then
		fail("Boo " .. key .. ": zona inexistente '" .. tostring(def.zone) .. "'")
	end
	if type(def.incomePerSec) ~= "number" or def.incomePerSec <= 0 then
		fail("Boo " .. key .. ": incomePerSec inválido")
	end
	if type(def.weight) ~= "number" or def.weight <= 0 then
		fail("Boo " .. key .. ": weight inválido")
	end
	if not string.find(booModel, "ACCESSORIES." .. tostring(def.accessory) .. " = function", 1, true) then
		fail("Boo " .. key .. ": acessório '" .. tostring(def.accessory) .. "' não existe em BooModel.luau")
	end
	boosPerZone[def.zone] = (boosPerZone[def.zone] or 0) + 1
end
for name in pairs(zoneNames) do
	if not boosPerZone[name] then
		fail("zona " .. name .. " não tem nenhum Boo")
	end
end
if not Config.Boos[Config.Economy.StarterBoo] then
	fail("StarterBoo não existe em Boos")
end

do
	local ordered = table.clone(Config.Zones)
	table.sort(ordered, function(a, b)
		return a.minStat < b.minStat
	end)
	local lastBest = 0
	for _, z in ipairs(ordered) do
		local best = 0
		for _, def in pairs(Config.Boos) do
			if def.zone == z.name then
				best = math.max(best, def.incomePerSec)
			end
		end
		if best < lastBest then
			fail("zona " .. z.name .. " (stat " .. z.minStat .. ") rende menos que uma zona mais fácil")
		end
		lastBest = best
	end
end

do
	local P = Config.Plot
	if P.Floors[1].cost ~= 0 then
		fail("o térreo (Floors[1]) precisa custar 0")
	end
	for i = 2, #P.Floors do
		if P.Floors[i].cost <= P.Floors[i - 1].cost then
			fail("andar " .. i .. " custa menos ou igual ao anterior")
		end
	end
	local expected = P.GroundSlots + P.FloorSlots * (#P.Floors - 1)
	if P.MaxSlots ~= expected then
		fail(("Plot.MaxSlots = %d mas andares/slots somam %d"):format(P.MaxSlots, expected))
	end
	if P.BaseGroundSlots + P.ExtraSlotsPass + P.VIPSlots ~= P.GroundSlots then
		fail("slots do térreo (base + ExtraSlots + VIP) não somam GroundSlots")
	end
end

do
	local U = Config.Upgrades
	if #U.Order ~= 4 then
		fail("Upgrades.Order precisa ter as 4 trilhas")
	end
	for _, track in ipairs(U.Order) do
		local def = U[track]
		if not def then
			fail("trilha " .. track .. " não existe")
		else
			if def.max < 1 or def.baseCost <= 0 or def.growth <= 1 then
				fail("trilha " .. track .. ": max/baseCost/growth inválidos")
			end
		end
	end
	local Pd = Config.Pedestal
	if Pd.max < 2 or Pd.baseCost <= 0 or Pd.growth <= 1 or Pd.perLevel <= 0 then
		fail("Pedestal inválido")
	end
	if Config.SaleCostMultiplier <= 0 or Config.SaleCostMultiplier >= 1 then
		fail("SaleCostMultiplier precisa estar entre 0 e 1")
	end
end

if #Config.Daily.Rewards ~= Config.Daily.StreakMax then
	fail("Daily.Rewards tem " .. #Config.Daily.Rewards .. " valores, StreakMax = " .. Config.Daily.StreakMax)
end

local consumableKeys = {}
for _, c in ipairs(Config.Consumables) do
	consumableKeys[c.key] = true
end
local VALID_KINDS = {
	ServerLuck = true,
	PersonalCash2x = true,
	LuckyCaptures = true,
	Consumable = true,
	Cash = true,
	IncomeBoost = true,
	UpgradeSale = true,
}
local VALID_TABS = { Boosts = true, Poderes = true, Sustos = true, Cash = true }
local seenIds, seenNames = {}, {}
local zeroIds = 0
local function checkItem(group: string, key: string, def, isProduct: boolean)
	local label = group .. "." .. key
	if type(def.name) ~= "string" or #def.name == 0 then
		fail(label .. ": sem name")
	elseif seenNames[def.name] then
		fail(label .. ": nome repetido '" .. def.name .. "' (também em " .. seenNames[def.name] .. ")")
	else
		seenNames[def.name] = label
	end
	if type(def.price) ~= "number" or def.price < 1 or def.price % 1 ~= 0 then
		fail(label .. ": price inválido")
	elseif def.price > 499 then
		fail(label .. ": preço acima de R$499")
	end
	if type(def.desc) ~= "string" or #def.desc == 0 then
		fail(label .. ": sem desc")
	end
	if type(def.icon) ~= "string" then
		fail(label .. ": sem icon")
	end
	if type(def.id) ~= "number" or def.id < 0 or def.id % 1 ~= 0 then
		fail(label .. ": id inválido")
	elseif def.id == 0 then
		zeroIds += 1
		warnMsg(label .. ": id = 0 (ainda não criado na Roblox)")
	elseif seenIds[def.id] then
		fail(label .. ": id " .. def.id .. " repetido (também em " .. seenIds[def.id] .. ")")
	else
		seenIds[def.id] = label
	end
	if isProduct then
		if not VALID_KINDS[def.kind] then
			fail(label .. ": kind inválido '" .. tostring(def.kind) .. "'")
		end
		if not VALID_TABS[def.tab] then
			fail(label .. ": tab inválida '" .. tostring(def.tab) .. "'")
		end
		if def.kind == "Consumable" and not consumableKeys[def.item] then
			fail(label .. ": consumível '" .. tostring(def.item) .. "' não existe em Config.Consumables")
		end
		if
			(def.kind == "ServerLuck" or def.kind == "IncomeBoost") and (type(def.mult) ~= "number" or def.mult <= 1)
		then
			fail(label .. ": mult precisa ser maior que 1")
		end
		if
			(
				def.kind == "ServerLuck"
				or def.kind == "IncomeBoost"
				or def.kind == "UpgradeSale"
				or def.kind == "PersonalCash2x"
			) and (type(def.duration) ~= "number" or def.duration <= 0)
		then
			fail(label .. ": duration inválida")
		end
		if
			(def.kind == "Cash" or def.kind == "LuckyCaptures" or def.kind == "Consumable")
			and (type(def.amount) ~= "number" or def.amount <= 0)
		then
			fail(label .. ": amount inválido")
		end
	end
end
for key, def in pairs(Config.Products) do
	checkItem("Products", key, def, true)
end
for key, def in pairs(Config.GamePasses) do
	checkItem("GamePasses", key, def, false)
end
if Config.GamePasses.AutoCollect == nil then
	fail("falta o passe AutoCollect (Coleta Automática)")
end

print(
	("Config OK? %d Boos, %d zonas, %d andares, %d produtos, %d passes"):format(
		count(Config.Boos),
		#Config.Zones,
		#Config.Plot.Floors,
		count(Config.Products),
		count(Config.GamePasses)
	)
)
for _, w in ipairs(warnings) do
	print("  aviso: " .. w)
end
if process.env.REQUIRE_IDS == "1" and zeroIds > 0 then
	fail(zeroIds .. " item(ns) com id = 0: crie na Roblox e cole o ID no Config antes de publicar")
end
if #errors > 0 then
	print("")
	for _, e in ipairs(errors) do
		print("  ERRO: " .. e)
	end
	process.exit(1)
end
print("tudo certo")
