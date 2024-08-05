local package = script.Parent.Parent
local state = require(package.state)

local function outdateAll(self: state.State)

    self.updated = false
    if self.isUpdated then self.isUpdated:set(false) end

    for state in self.listeners do
    
        state.updated = false
        if state.isUpdated then state.isUpdated:set(false) end
    end
end
local function updateAll(self: state.State)

    self.updated = true
    if self.isUpdated then self.isUpdated:set(true) end

    for state, update in self.listeners do update(state) end
end
return table.freeze{ outdateAll = outdateAll, updateAll = updateAll }