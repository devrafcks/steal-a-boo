local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local DailyRewardService = {}

local ctx

local function today(): number
	return math.floor(os.time() / 86400)
end

function DailyRewardService.nextStreak(data): number
	local d = data.Daily
	if d.lastDay == today() - 1 then
		return (d.streak % Config.Daily.StreakMax) + 1
	end
	return 1
end

function DailyRewardService.canClaim(data): boolean
	return data.Daily.lastDay ~= today()
end

function DailyRewardService.info(data)
	local streak = DailyRewardService.canClaim(data) and DailyRewardService.nextStreak(data) or data.Daily.streak
	return {
		streak = streak,
		canClaim = DailyRewardService.canClaim(data),
		nextReward = Config.Daily.Rewards[streak] or Config.Daily.Rewards[1],
		secondsToReset = (today() + 1) * 86400 - os.time(),
	}
end

function DailyRewardService.claim(player: Player)
	local data = ctx.PlayerData.data(player)
	if not data or not ctx.Net.cooldown(player, "daily", 1) then
		return
	end
	if not DailyRewardService.canClaim(data) then
		local left = (today() + 1) * 86400 - os.time()
		ctx.notify(
			player,
			string.format("Volte em %dh%02dm para o próximo Daily.", left // 3600, (left % 3600) // 60),
			"info"
		)
		return
	end
	local streak = DailyRewardService.nextStreak(data)
	local reward = Config.Daily.Rewards[streak] or Config.Daily.Rewards[1]
	data.Daily.lastDay = today()
	data.Daily.streak = streak
	data.Cash += reward
	data.TotalCash += reward
	local extra = ""
	if streak == Config.Daily.StreakMax and Config.Daily.StreakBonusItemDay7 == "LuckyTicket" then
		data.LuckyCaptures += 1
		extra = " + 1 Super Lucky Capture"
	end
	ctx.notify(player, string.format("Daily dia %d: +$%d%s!", streak, reward, extra), "success")
	ctx.fx("Daily", { userId = player.UserId, streak = streak }, player)
	ctx.PlayerData.markDirty(player)
end

function DailyRewardService.init(c)
	ctx = c
	ctx.Net.on("RequestDaily", DailyRewardService.claim)
	local chest = Workspace:WaitForChild("StealABooWorld"):WaitForChild("Plaza"):FindFirstChild("DailyChest")
	local prompt = chest and chest:FindFirstChild("DailyPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(player)
			if ctx.Net.allowPrompt(player, "Daily") then
				DailyRewardService.claim(player)
			end
		end)
	end
end

return DailyRewardService
