local package = script.Parent.Parent
local propagate = require(package.state.propagate)
local scope = require(package.memory.scope)
local state = require(package.state)
local isSimilar = require(package.utils.isSimilar)

local Value = {}

function Value.new<Value, Derived>(
    parent: scope.scope<Derived>,
    value: Value
): StateValue<Value, Derived>

    return parent:child({
        listeners = {},
        value = value,

        get = Value.get,
        set = Value.set,
    })
end
function Value.set<Value>(
    self: StateValue<Value>,
    newValue: Value,
    shouldPropagate: 'propagate'?
): Value

    if not shouldPropagate and isSimilar(newValue, self.value) then return newValue end

    propagate.outdateAll(self)
    self.value = newValue
    
    propagate.updateAll(self)
    return newValue
end
function Value.get<Value>(self: StateValue<Value>): Value
    return self.value
end

export type StateValue<Value = any, Derived = {}, extra = {}>
    = state.State<Value, Derived, extra & {
        set: (StateValue<Value, Derived, extra>, newValue: Value, shouldPropagate: 'propagate') -> Value,
    }>
return Value.new