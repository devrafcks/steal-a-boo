local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Rarity = require(Shared.Util.Rarity)

local RebirthService = {}

local ctx

function RebirthService.cost(data): number
	local R = Config.Rebirth
	return math.floor(R.CashRequiredBase * R.CashRequiredGrowth ^ data.Rebirths)
end

function RebirthService.rebirth(player: Player)
	local data = ctx.PlayerData.data(player)
	if not data or not ctx.Net.cooldown(player, "rebirth", 2) then
		return
	end
	local cost = RebirthService.cost(data)
	if data.Cash < cost then
		ctx.notify(player, string.format("Você precisa de $%d para o Rebirth.", cost), "warn")
		return
	end
	if ctx.Boos.isCarrying(player) then
		ctx.notify(player, "Entregue o Boo que você está carregando primeiro.", "warn")
		return
	end
	data.Rebirths += 1
	data.Cash = Config.Economy.StartingCash
	data.Vault = 0
	ctx.Boos.clearBelowTier(player, data, Rarity.tier(Config.Rebirth.KeepRarityAtOrAbove))

	if next(data.PlotLayout) == nil and next(data.Inventory) == nil then
		ctx.Boos.giveBoo(player, data, Config.Economy.StarterBoo)
	end
	local bonus = math.floor(data.Rebirths * Config.Rebirth.IncomeMultiplierPerRebirth * 100)
	ctx.notify(player, string.format("Rebirth %d! Sua renda agora tem +%d%%.", data.Rebirths, bonus), "success")
	ctx.notifyAll(string.format("%s fez Rebirth %d!", player.DisplayName, data.Rebirths), "rare")
	ctx.fx("Rebirth", { userId = player.UserId, rebirths = data.Rebirths })
	ctx.Leaderboards.push(player)
	ctx.PlayerData.markDirty(player)
end

function RebirthService.init(c)
	ctx = c
	ctx.Net.on("RequestRebirth", RebirthService.rebirth)
end

return RebirthService
