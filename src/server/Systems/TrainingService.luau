--[[
	TrainingService.luau — esteira (Speed) e alvo (Throw Power) na praça.
	Custo cresce: TrainingCashCostBase * TrainingCostGrowth ^ (treinos feitos naquele status).
	2x Training (passe) dobra o ganho, não o custo.
]]
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local TrainingService = {}

local ctx
local stations: { [string]: BasePart } = {}

local STATS = {
	Speed = { field = "Speed", trains = "SpeedTrains", per = "SpeedPerTrain", max = "MaxSpeed", label = "Speed" },
	Throw = { field = "ThrowPower", trains = "ThrowTrains", per = "ThrowPerTrain", max = "MaxThrow", label = "Throw Power" },
}

function TrainingService.cost(data, stat: string): number
	local s = STATS[stat]
	local E = Config.Economy
	return math.floor(E.TrainingCashCostBase * E.TrainingCostGrowth ^ data[s.trains])
end

-- Speed é somado ao WalkSpeed base, então o máximo do STATUS é MaxSpeed - BaseWalkSpeed
local function statCap(stat: string): number
	if stat == "Speed" then
		return Config.Economy.MaxSpeed - Config.Economy.BaseWalkSpeed
	end
	return Config.Economy.MaxThrow
end

function TrainingService.train(player: Player, stat)
	local s = STATS[stat]
	local station = stations[stat]
	if not s or not station then
		return
	end
	local data = ctx.PlayerData.data(player)
	if not data then
		return
	end
	if not ctx.Net.cooldown(player, "train", 0.2) then
		return
	end
	if not ctx.Net.near(player, station.Position, Config.World.TrainRange + 6) then
		ctx.notify(player, "Chegue mais perto da estação de treino.", "warn")
		return
	end
	local cap = statCap(stat)
	if data[s.field] >= cap then
		ctx.notify(player, string.format("%s no máximo! Faça Rebirth para ir mais longe.", s.label), "info")
		return
	end
	local cost = TrainingService.cost(data, stat)
	if data.Cash < cost then
		ctx.notify(player, string.format("Faltam $%d para treinar.", math.ceil(cost - data.Cash)), "warn")
		return
	end
	local gain = Config.Economy[s.per]
	if ctx.Passes.owns(player, "DoubleTraining") then
		gain *= 2
	end
	data.Cash -= cost
	data[s.field] = math.min(cap, data[s.field] + gain)
	data[s.trains] += 1
	ctx.Character.refresh(player)
	ctx.fx("Train", { userId = player.UserId, stat = stat, gain = gain, value = data[s.field] }, player)
	ctx.PlayerData.markDirty(player)
end

function TrainingService.init(c)
	ctx = c
	local plaza = Workspace:WaitForChild("StealABooWorld"):WaitForChild("Plaza")
	for _, d in plaza:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "TrainPrompt" then
			local stat = d:GetAttribute("Stat")
			stations[stat] = d.Parent
			d.Triggered:Connect(function(player)
				if ctx.Net.allowPrompt(player, "Train") then
					TrainingService.train(player, stat)
				end
			end)
		end
	end
	ctx.Net.on("RequestTrain", TrainingService.train)
end

return TrainingService
