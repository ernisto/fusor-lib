--// Packages
local package = script.Parent.Parent
local isSimilar = require(package.utils.isSimilar)
local propagate = require(package.state.propagate)
local scope = require(package.memory.scope)
local state = require(package.state)

local Computed = {}
local update, destroy

function Computed.new<Value, Derived>(
    parent: scope.scope<Derived>,
    computer: computer<Value, Derived>
): Computed<Value, Derived>

    local self = parent:child({
        listeners = {},
        listening = {},
        updated = false,
        busy = false,

        computer = computer,
        get = Computed.get
    })

    table.insert(self, destroy)
    update(self)
    
    return self
end
function Computed.get<Value>(self: Computed<Value>): Value
    if self.updated then return self.value end
    return update(self)
end

function destroy(self: Computed)

    for _,listeningListeners in self.listening do
        listeningListeners[self] = nil
    end
    table.clear(self.listeners)
    if self.lastComputation then self.lastComputation:destroy() end
end
function update<Value, Derived>(self: Computed<Value, Derived>)

    if self.busy then return end
    if self.updated then return end

    self.busy = true; do
        if self.isBusy then self.isBusy:set(true) end
    end

    for _,listeners in self.listening do listeners[self] = nil end
    local newDepending = table.create(10)

    --// Compute
    if self.watchedPriority then self.watchedPriority:set(1) end
    local function use<Consumed>(state: state.UsedAs<Consumed>, possiblyDead: 'possiblyDead'?): Consumed

        if typeof(state) ~= 'table' then return state end

        local stateListeners = state.listeners
        if stateListeners == nil then return state :: any end -- isnt a state

        if not possiblyDead and state.parent == nil then
            error(`attempt to read a dead state (if its was proposital, pls use 'possiblyDead' flag)`)
        end

        local value = state:get()

        if stateListeners[self] ~= update then

            table.insert(newDepending, stateListeners)
            stateListeners[self] = update
            
            if self.watchedPriority and state.watchedPriority then
                self.watchedPriority:set(math.max(self.watchedPriority.value, 1 + state.watchedPriority.value))
            end
        end
        return value
    end

    local computation = self:unhostedChild({})
    local success, newValue = xpcall(self.computer, debug.traceback, use, computation)
    
    if not success then
        computation:destroy()
        self.busy = false; do
            if self.isBusy then self.isBusy:set(false) end
        end
        warn(newValue)
        return self.value
    end

    --// Finish
    if self.lastComputation then self.lastComputation:destroy() end
    self.lastComputation = computation

    self.listening = newDepending
    if isSimilar(newValue, self.value) then
        
        self.busy = false; do
            if self.isBusy then self.isBusy:set(false) end
        end
        return newValue
    end
    
    propagate.outdateAll(self)
    self.value = newValue

    if self.isUpdated then self.isUpdated:set(true) end
    self.busy = false; do
        if self.isBusy then self.isBusy:set(false) end
    end
    
    propagate.updateAll(self)
    return newValue
end

export type Computed<Value = any, Derived = {}, extra = {}>
    = state.ConsumerState<Value, Derived, extra & {
        computer: computer<Value, Derived>,
        lastComputation: scope.scope<Derived>,
    }>
type computer<Value, Derived> = (
    use: <Consumed>(state: state.UsedAs<Consumed>) -> Consumed,
    scope: scope.scope<Derived>
) -> Value
return Computed.new