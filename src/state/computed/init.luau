--// Packages
local state = require('..')
local propagate = require('../propagate')
local isSimilar = require('../../utils/isSimilar')
local scope = require('../../memory/scope')
local warn = require('../../debug/warn')

local Computed = {}
local update, destroy

function Computed.new<Value, Derived>(parent: scope.scope<Derived>, computer: computer<Value, Derived>): Computed<Value, Derived>
	local self = parent:child({
		listeners = {},
		listening = {},
		updated = false,
		busy = false,

		computer = computer,
		get = Computed.get,
	})

	table.insert(self, destroy)
	update(self)

	return self
end
function Computed.get<Value>(self: Computed<Value>, possiblyBusy: 'possiblyBusy'): Value
	if self.busy then
		warn(`attempt to read a Computed() value while is busy (if it is proposital, pls use 'possiblyBusy' flag)`)
		return self.value
	end
	if self.updated then return self.value end
	return update(self) :: any
end

function destroy(self: Computed)
	for _, listeningListeners in self.listening do
		listeningListeners[self] = nil
	end
	table.clear(self.listeners)
	if self.lastComputation then self.lastComputation:destroy() end
end
function update<Value, Derived>(self: Computed<Value, Derived>)
	if self.busy then return end
	if self.updated then return end

	self.busy = true

	for _, listeners in self.listening do
		listeners[self] = nil
	end
	local newDepending = table.create(10)

	--// Compute
	local function use<Consumed>(state: state.UsedAs<Consumed>, possiblyDead: 'possiblyDead'?): Consumed
		if typeof(state) ~= 'table' then return state end

		local stateListeners = state.listeners
		if stateListeners == nil then return state :: any end -- isnt a state

		if not possiblyDead and state.parent == nil then
			error(`attempt to read a dead state (if it is proposital, pls use 'possiblyDead' flag)`)
		end

		local value = state:get()

		if stateListeners[self] ~= update then
			table.insert(newDepending, stateListeners :: any)
			stateListeners[self] = update :: any
		end
		return value
	end

	local computation = self:unhostedChild({})
	local success, newValue = xpcall(self.computer, debug.traceback, use, computation)

	if not success then
		computation:destroy()
		self.busy = false

		warn(newValue)
		return self.value
	end

	--// Finish
	if self.lastComputation then self.lastComputation:destroy() end
	self.lastComputation = computation

	self.listening = newDepending
	if isSimilar(newValue, self.value) then
		self.busy = false
		return newValue
	end

	propagate.outdateAll(self)
	self.value = newValue
	self.busy = false

	propagate.updateAll(self)
	return newValue
end

export type Computed<Value = any, Derived = {}, extra = {}> = state.ConsumerState<Value, Derived, extra & {
	computer: computer<Value, Derived>,
	lastComputation: scope.scope<Derived>,
}>
type computer<Value, Derived> = (
	use: <Consumed>(state: state.UsedAs<Consumed>) -> Consumed,
	scope: scope.scope<Derived>
) -> Value
return Computed.new
