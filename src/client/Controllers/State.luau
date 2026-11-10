--[[
	State.luau — último snapshot que o servidor mandou (DataUpdated).
	Só leitura para a UI: o cliente nunca altera dinheiro, inventário etc.
]]
local Signal = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Util.Signal)

local State = {}

local changed = Signal.new()
State.Changed = changed
State.data = nil

function State.set(snapshot)
	State.data = snapshot
	changed:Fire(snapshot)
end

function State.onReady(callback)
	if State.data then
		task.spawn(callback, State.data)
	end
	return State.Changed:Connect(callback)
end

return State
