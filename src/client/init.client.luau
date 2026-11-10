--[[
	init.client.luau — bootstrap do cliente de Steal a Boo!
	O cliente só desenha UI, efeitos e manda PEDIDOS ao servidor.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Controllers = script:WaitForChild("Controllers")
local State = require(Controllers.State)
local UI = require(Controllers.UIController)
require(Controllers.HUD)
require(Controllers.Panels)
require(Controllers.ShopUI)
local Effects = require(Controllers.EffectsController)
local Sound = require(Controllers.Sound)
UI.clickSound = function()
	Sound.play("Click", 0.35, 1)
end
local Input = require(Controllers.InputController)

Remotes.get("DataUpdated").OnClientEvent:Connect(function(snapshot)
	State.set(snapshot)
end)

Remotes.get("Notify").OnClientEvent:Connect(function(text, kind)
	UI.toast(text, kind)
end)

Effects.init()
Input.init()
