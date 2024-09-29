local isSimilar = require('./utils/isSimilar')
local never = require('./utils/never')

local traceback = require('./debug/traceback')
local warn = require('./debug/warn')

local state = require('./state/init')
local Value = require('./state/value')
local Computed = require('./state/computed')
local Map = require('./state/computed/map')

local Scope = require('./memory/scope')
local whichIsParent = require('./memory/whichIsParent')

export type ValueState<Value = any, Write = Value, Derived = {}> = Value.StateValue<Value, Write, Derived>
export type Computed<Value = any, Derived = {}> = Computed.Computed<Value, Derived>
export type State<Value = any, Derived = {}> = state.State<Value, Derived>
export type UsedAs<Value = any> = state.UsedAs<Value>

export type Scope<Derived = {}, Fields = {}> = Scope.scope<Derived, Fields>

local builders = Scope:derivable {
	State = state,
	Value = Value,
	Computed = Computed,
	Map = Map,
}
return builders:unhostedChild {
	whichIsParent = whichIsParent,
	isSimilar = isSimilar,
	traceback = traceback,
	never = never,
	warn = warn,

	isState = state.is,
	peek = state.get,
}
