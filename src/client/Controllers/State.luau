--[[
	State.luau — último snapshot que o servidor mandou (DataUpdated).
	Só leitura para a UI: o cliente nunca altera dinheiro, inventário etc.
]]
local State = {}

local changed = Instance.new("BindableEvent")
State.Changed = changed.Event
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
