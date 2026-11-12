local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local GamePasses = {}

local ctx
local owned: { [Player]: { [string]: boolean } } = {}

local function keyById(passId: number): string?
	for key, def in pairs(Config.GamePasses) do
		if def.id ~= 0 and def.id == passId then
			return key
		end
	end
	return nil
end

local function checkApi(player: Player, passId: number): boolean
	local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	return ok and result == true
end

function GamePasses.owns(player: Player, key: string): boolean
	local map = owned[player]
	return map ~= nil and map[key] == true
end

local function apply(player: Player, key: string)
	owned[player] = owned[player] or {}
	owned[player][key] = true
	player:SetAttribute("Pass_" .. key, true)

	ctx.Plots.renderSlots(player)
	ctx.Character.applyCosmetics(player)
	ctx.Character.refresh(player)
	ctx.PlayerData.markDirty(player)
end

function GamePasses.studioGrant(player: Player, key: string)
	if not RunService:IsStudio() or not Config.GamePasses[key] then
		return
	end
	apply(player, key)
	ctx.notify(player, "[Studio] Passe de teste: " .. Config.GamePasses[key].name, "success")
end

local function loadPlayer(player: Player)
	owned[player] = owned[player] or {}
	local any = false
	for key, def in pairs(Config.GamePasses) do
		if def.id ~= 0 and checkApi(player, def.id) then
			owned[player][key] = true
			player:SetAttribute("Pass_" .. key, true)
			any = true
		end
	end

	if any and player.Parent == Players then
		ctx.Plots.renderSlots(player)
		ctx.Character.applyCosmetics(player)
		ctx.PlayerData.markDirty(player)
	end
end

function GamePasses.init(c)
	ctx = c
	for _, p in Players:GetPlayers() do
		task.spawn(loadPlayer, p)
	end
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(function(p)
		owned[p] = nil
	end)

	ctx.PlayerData.Loaded:Connect(function(player)
		task.defer(function()
			ctx.Plots.renderSlots(player)
			ctx.Character.applyCosmetics(player)
		end)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		local key = keyById(passId)
		if not key or not wasPurchased then
			return
		end
		for attempt = 1, 4 do
			if checkApi(player, passId) then
				apply(player, key)
				ctx.notify(
					player,
					string.format("Você recebeu %s! Obrigado pelo apoio!", Config.GamePasses[key].name),
					"success"
				)
				ctx.fx("Purchase", { userId = player.UserId, name = Config.GamePasses[key].name })
				return
			end
			task.wait(attempt * 1.5)
		end
		ctx.notify(
			player,
			"A compra foi feita, mas a Roblox ainda não confirmou. O passe aparece ao entrar de novo.",
			"warn"
		)
	end)
end

return GamePasses
