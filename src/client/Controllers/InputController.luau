local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Remotes)
local UI = require(script.Parent.UIController)
local HUD = require(script.Parent.HUD)
local ShopUI = require(script.Parent.ShopUI)

local player = Players.LocalPlayer

local InputController = {}

local KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

local function updatePrompts()
	local world = Workspace:FindFirstChild("StealABooWorld")
	local plots = world and world:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in plots:GetChildren() do
		local mine = plot:GetAttribute("OwnerUserId") == player.UserId
		local lockPrompt = plot:FindFirstChild("LockButton") and plot.LockButton:FindFirstChild("LockPrompt")
		if lockPrompt then
			lockPrompt.Enabled = mine
		end
		local upgrade = plot:FindFirstChild("UpgradeBoard") and plot.UpgradeBoard:FindFirstChild("UpgradePrompt")
		if upgrade then
			upgrade.Enabled = mine
		end
		for _, child in plot:GetChildren() do
			if child.Name:match("^PaidBelt_") then
				local bp = child:FindFirstChild("BeltPrompt")
				if bp then
					bp.Enabled = mine
				end
			end
		end
		local slots = plot:FindFirstChild("Slots")
		if slots then
			for _, pad in slots:GetChildren() do
				local p = pad:FindFirstChild("PlacePrompt")
				if p then
					p.Enabled = mine and pad:GetAttribute("Unlocked") == true and pad:GetAttribute("Occupied") ~= true
				end
			end
		end
		for _, child in plot:GetChildren() do
			if child:IsA("Model") and child.PrimaryPart then
				local sp = child.PrimaryPart:FindFirstChild("StealPrompt")
				if sp then
					local own = child:GetAttribute("OwnerUserId") == player.UserId
					if own then
						sp.Enabled = not child:GetAttribute("Decoy")
						sp.ActionText = "Guardar"
						sp.HoldDuration = 0.2
					else
						sp.Enabled = true
						sp.ActionText = "Roubar"

						sp.HoldDuration = child:GetAttribute("StealHold") or 0.8
					end
				end

				local pp = child.PrimaryPart:FindFirstChild("PedestalPrompt")
				if pp then
					pp.Enabled = child:GetAttribute("OwnerUserId") == player.UserId
				end
			end
		end
	end
end

local function updateTakePrompts()
	for _, other in Players:GetPlayers() do
		local carried = other.Character and other.Character:FindFirstChild("CarriedBoo")
		local take = carried and carried.PrimaryPart and carried.PrimaryPart:FindFirstChild("TakePrompt")
		if take then
			take.Enabled = other ~= player
		end
	end
end

function InputController.init()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local idx = KEYS[input.KeyCode]
		if idx then
			HUD.use(idx)
		elseif input.KeyCode == Enum.KeyCode.B then
			UI.toggle("Inventory")
		elseif input.KeyCode == Enum.KeyCode.L then
			UI.toggle("Shop")
		elseif input.KeyCode == Enum.KeyCode.Q then
			Remotes.get("RequestPunch"):FireServer()
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		if prompt:GetAttribute("OpenUI") == "Shop" then
			ShopUI.openTab("Boosts")
		elseif prompt:GetAttribute("BuyProduct") then
			ShopUI.buyProduct(prompt:GetAttribute("BuyProduct"))
		end
	end)

	task.spawn(function()
		while true do
			updatePrompts()
			updateTakePrompts()
			task.wait(0.4)
		end
	end)
end

return InputController
