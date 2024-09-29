local state = require('./init')

local function outdateAll(self: state.State)
	self.updated = false

	for state in self.listeners do
		state.updated = false
	end
end
local function updateAll(self: state.State)
	self.updated = true

	for state, update in self.listeners do
		update(state)
	end
end
return table.freeze { outdateAll = outdateAll, updateAll = updateAll }
