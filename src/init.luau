local package = script
local isSimilar = require(package.utils.isSimilar)

local state = require(package.state)
local Value = require(package.state.value)
local Computed = require(package.state.computed)
local Map = require(package.state.computed.map)

local Scope = require(package.memory.scope)
local whichIsParent = require(package.memory.whichIsParent)

export type ValueState<Value = any, Derived = {}> = Value.StateValue<Value, Derived>
export type Computed<Value = any, Derived = {}> = Computed.Computed<Value, Derived>
export type State<Value = any, Derived = {}> = state.State<Value, Derived>
export type UsedAs<Value = any> = state.UsedAs<Value>

export type Scope<Derived = {}, Fields = {}> = Scope.scope<Derived, Fields>

return Scope:derivable {
	State = state,
	Value = Value,
	Computed = Computed,
	Map = Map,

	whichIsParent = whichIsParent,
	isSimilar,
}
