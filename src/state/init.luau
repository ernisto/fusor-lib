local scope = require('../memory/scope')

type listeners<Value = any> = { [_State<Value>]: (_State<Value>) -> () }

type _State<Value> = {
	listeners: listeners<Value>,
	updated: boolean,
	value: Value,

	get: (_State<Value>) -> Value,
}

export type UsedAs<Value = any> = State<Value> | Value

export type State<Value = any, Derived = {}, extra = {}> = scope.scope<Derived, _State<Value> & extra>

export type ConsumerState<Value = any, Derived = {}, extra = {}> = State<Value, Derived, extra & {
	listening: { listeners<Value> },
	busy: boolean,

	get: (_State<Value>, possiblyBusy: 'possiblyBusy') -> Value,
}>

local function is(self: unknown): State?
	return if typeof(self) == 'table' and typeof((self :: any).listeners) == 'table' then self :: State else nil
end
local function get<Value>(value: UsedAs<Value>): Value return if is(value) then (value :: any).value else value end
local function cast<Value>(scope: scope.scope, value: UsedAs<Value>): (State<Value>, 'alreadyIsState'?)
	if is(value) then return value :: any, 'alreadyIsState' end
	return scope:child { value = value, listeners = {}, updated = true, get = get } :: any
end

return { cast = cast, is = is, get = get }
