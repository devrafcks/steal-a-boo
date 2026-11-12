local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: Connection) -> () }

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handlers = self._handlers
	local entry = { fn = fn }
	table.insert(handlers, entry)
	return {
		Disconnect = function()
			local i = table.find(handlers, entry)
			if i then
				table.remove(handlers, i)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, entry in ipairs(table.clone(self._handlers)) do
		task.spawn(entry.fn, ...)
	end
end

return Signal
