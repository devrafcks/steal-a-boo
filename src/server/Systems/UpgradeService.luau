--[[
	UpgradeService.luau — o Laboratório e os pedestais.

	Trilhas (Config.Upgrades): Gerador (+renda), Cofre (+capacidade), Sorte (+chance de raros),
	Segurança (ladrão demora mais, solta mais fácil, portão fica trancado mais tempo).
	Pedestal (Config.Pedestal): cada slot da base evolui separado e multiplica a renda do Boo ali.

	Tudo é comprado com Cash do jogo, validado aqui. Produto "Promoção de Upgrades" divide o custo
	de upgrades E de andares pela metade enquanto durar (ver `discount`).
	Dentro da própria base, o cofre é coletado antes de cobrar (o dinheiro dos Boos já conta).
]]
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local UpgradeService = {}

local ctx
local U = Config.Upgrades

----------------------------------------------------------------------
-- Níveis e efeitos (funções puras, usadas por BooService/PlotService/snapshot)
----------------------------------------------------------------------
function UpgradeService.level(data, track: string): number
	return math.clamp(data.Upgrades[track] or 0, 0, U[track].max)
end

-- multiplicador de renda do Gerador
function UpgradeService.incomeMultiplier(data): number
	return 1 + UpgradeService.level(data, "Income") * U.Income.perLevel
end

-- multiplicador de sorte pessoal (Sorte)
function UpgradeService.luckMultiplier(data): number
	return 1 + UpgradeService.level(data, "Luck") * U.Luck.perLevel
end

function UpgradeService.securityLevel(data): number
	return UpgradeService.level(data, "Security")
end

-- segundos de renda que o cofre guarda
function UpgradeService.vaultSeconds(data): number
	return Config.Vault.BaseSeconds + UpgradeService.level(data, "Vault") * Config.Vault.SecondsPerLevel
end

-- capacidade em Cash (nunca menos que MinCapacity, para quem tem renda quase zero)
function UpgradeService.vaultCapacity(data, incomePerSec: number): number
	return math.max(Config.Vault.MinCapacity, incomePerSec * UpgradeService.vaultSeconds(data))
end

function UpgradeService.pedestalLevel(data, slot): number
	return math.clamp(data.PedestalLevels[tostring(slot)] or 1, 1, Config.Pedestal.max)
end

function UpgradeService.pedestalMultiplier(level: number): number
	return 1 + (level - 1) * Config.Pedestal.perLevel
end

-- 1 normal, 0.5 durante a Promoção de Upgrades
function UpgradeService.discount(data): number
	if (data.UpgradeSaleEnds or 0) > os.time() then
		return Config.SaleCostMultiplier
	end
	return 1
end

function UpgradeService.cost(data, track: string): number?
	local def = U[track]
	local level = UpgradeService.level(data, track)
	if not def or level >= def.max then
		return nil
	end
	return math.floor(def.baseCost * def.growth ^ level * UpgradeService.discount(data))
end

function UpgradeService.pedestalCost(data, slot): number?
	local P = Config.Pedestal
	local level = UpgradeService.pedestalLevel(data, slot)
	if level >= P.max then
		return nil
	end
	return math.floor(P.baseCost * P.growth ^ (level - 1) * UpgradeService.discount(data))
end

----------------------------------------------------------------------
-- Compras
----------------------------------------------------------------------
function UpgradeService.buyTrack(player: Player, track)
	if not ctx.Net.isString(track, 16) or not U[track] or not table.find(U.Order, track) then
		return
	end
	local data = ctx.PlayerData.data(player)
	if not data or not ctx.Net.cooldown(player, "upgradeTrack", 0.3) then
		return
	end
	ctx.Plots.collectIfHome(player)
	local cost = UpgradeService.cost(data, track)
	if not cost then
		ctx.notify(player, U[track].name .. " já está no máximo!", "info")
		return
	end
	if data.Cash < cost then
		ctx.notify(
			player,
			string.format("Faltam $%s para evoluir %s.", ctx.Format.compact(cost - data.Cash), U[track].name),
			"warn"
		)
		return
	end
	data.Cash -= cost
	data.Upgrades[track] = UpgradeService.level(data, track) + 1
	ctx.Plots.refreshOwner(player) -- portão/cofre/prompts dependem dos níveis
	ctx.notify(player, string.format("%s nível %d!", U[track].name, data.Upgrades[track]), "success")
	ctx.fx("UpgradeBought", { userId = player.UserId, track = track, level = data.Upgrades[track] })
	ctx.PlayerData.markDirty(player)
end

function UpgradeService.buyPedestal(player: Player, slot)
	if not ctx.Net.isInt(slot, 1, Config.Plot.MaxSlots) then
		return
	end
	local data = ctx.PlayerData.data(player)
	if not data or not ctx.Net.cooldown(player, "upgradePedestal", 0.25) then
		return
	end
	if not ctx.Plots.isUnlocked(player, slot) or not ctx.Plots.getPlot(player) then
		return
	end
	-- o pedestal precisa estar perto (o prompt F só aparece perto do Boo)
	local pad = ctx.Plots.pad(ctx.Plots.getPlot(player), slot)
	if not pad or not ctx.Net.near(player, pad.Position, 14) then
		return
	end
	if data.PlotLayout[tostring(slot)] == nil then
		ctx.notify(player, "Coloque um Boo no pedestal para evoluir.", "info")
		return
	end
	ctx.Plots.collectIfHome(player)
	local cost = UpgradeService.pedestalCost(data, slot)
	if not cost then
		ctx.notify(player, "Esse pedestal já está no nível máximo!", "info")
		return
	end
	if data.Cash < cost then
		ctx.notify(
			player,
			string.format("Faltam $%s para evoluir o pedestal.", ctx.Format.compact(cost - data.Cash)),
			"warn"
		)
		return
	end
	data.Cash -= cost
	local level = UpgradeService.pedestalLevel(data, slot) + 1
	data.PedestalLevels[tostring(slot)] = level
	ctx.Plots.refreshSlotLabel(player, slot)
	ctx.fx("PedestalUp", { userId = player.UserId, position = pad.Position + Vector3.new(0, 3, 0), level = level })
	ctx.notify(
		player,
		string.format(
			"Pedestal %d evoluiu para o nível %d! (x%.1f de renda)",
			slot,
			level,
			UpgradeService.pedestalMultiplier(level)
		),
		"success"
	)
	ctx.PlayerData.markDirty(player)
end

function UpgradeService.init(c)
	ctx = c
	ctx.Net.on("RequestUpgradeTrack", UpgradeService.buyTrack)
	ctx.Net.on("RequestUpgradePedestal", UpgradeService.buyPedestal)
end

return UpgradeService
