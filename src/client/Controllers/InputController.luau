--[[
	InputController.luau
	- Teclas 1..9 usam os consumíveis da hotbar. B = Bolsa, L = Loja.
	- Ajusta prompts LOCALMENTE (só muda o que este cliente vê):
	    Boo da sua base -> "Guardar"; Boo dos outros -> "Roubar"
	    "Colocar Boo" só aparece nos slots livres da SUA base
	    "Trancar base" só aparece na SUA base
	  O servidor confere tudo de novo quando o prompt dispara.
	- Prompt da loja física abre a UI da loja.
]]
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

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
						sp.HoldDuration = 0.8
					end
				end
			end
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
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and prompt:GetAttribute("OpenUI") == "Shop" then
			ShopUI.openTab("Boosts")
		end
	end)

	task.spawn(function()
		while true do
			updatePrompts()
			task.wait(0.4)
		end
	end)
end

return InputController
