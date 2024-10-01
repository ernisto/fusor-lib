--!nolint LocalShadow

local State = require('../..')
local propagate = require('../../propagate')
local Computed = require('../../computed')
local Value = require('../../value')
local Scope = require('../../../memory/scope')
local isSimilar = require('../../../utils/isSimilar')
local never = require('../../../utils/never')
local warn = require('../../../debug/warn')

local SAME = newproxy(true)

--// Module
local Map = {}
local update

--// Constructor
function Map.new<IK, IV, OK, OV, D>(
	parent: Scope.scope<D>,
	subject: State.UsedAs<{ [IK]: IV }>,
	pairComputer: pairComputer<IK, IV, OK, OV, D>
): Map<IK, IV, OK, OV, D>
	local subjectAsState = State.is(subject)

	local self: Map<IK, IV, OK, OV, D> = parent:child({
		updated = false,
		busy = false,

		listening = { subjectAsState },
		listeners = {},
		value = {},

		freeProcessors = {},
		processors = {},

		subject = subjectAsState,
		pairComputer = pairComputer,

		getKey = Map.getKey,
		get = Map.get,
	} :: any)

	if subjectAsState then subjectAsState.listeners[self] = update :: any end
	update(self)
	return self
end

--// Methods
function Map.get<OK, OV>(self: Map<unknown, unknown, OK, OV>, possiblyBusy: 'possiblyBusy'): { [OK]: OV }
	if self.busy then
		warn(`attempt to read a Map() value while is busy (if it is proposital, pls use 'possiblyBusy' flag)`)
	end
	return update(self)
end
function Map.getKey<OK, OV>(self: Map<unknown, unknown, OK, OV>, key: OK, possiblyBusy: 'possiblyBusy'): OV
	if self.busy then
		warn(`attempt to read a Map() value while is busy (if it is proposital, pls use 'possiblyBusy' flag)`)
	end
	return self.value[key]
end

function update<IK, IV, OK, OV>(
	self: Map<IK, IV, OK, OV>,
	updateId: number?,
	nextMutations: { { [State.State]: any } }?,
	deltaKeys: { [IK]: IV }?
): { [OK]: OV }
	type myProcessor = processor<IK, IV, OK, OV>
	type listenable = { listeners: { [any]: (any) -> () } }
	local output = self.value

	if self.updated then return output end
	if self.busy then return output end
	self.busy = true

	local processors = self.processors
	local freeProcessors = self.freeProcessors
	local outdatedStates = {} :: { listenable }
	local pairComputer = self.pairComputer

	local updateId = outdatedStates -- just something that is unique for each `update` callment

	-- update all `processors` that is kept by some key or value
	-- queue all updates in `outdatedStates` for batched update
	-- keep `unprocessedPairs` only with pairs that wasnt processed here by an existing processor
	local unprocessedPairs = table.clone(State.get(self.subject))
	for _, processor in processors do
		local usingKey = processor.usingKey
		if usingKey ~= nil then
			local value = unprocessedPairs[usingKey]
			if value ~= nil then
				local valueState = processor.value
				if not isSimilar(valueState.value, value) then
					table.insert(outdatedStates, valueState)
					propagate.outdateAll(valueState :: any)
					valueState.value = value
				end
				unprocessedPairs[usingKey] = nil
				continue
			end
		end

		local usingValue = processor.usingValue
		if usingValue ~= nil then
			local found = false
			for key, value in unprocessedPairs do
				if value ~= usingValue then continue end

				local keyState = processor.key
				if not isSimilar(keyState.value, key) then
					table.insert(outdatedStates, keyState :: any)
					propagate.outdateAll(keyState :: any)
					keyState.value = key
				end
				unprocessedPairs[key] = nil
				found = true
				break
			end
			if found then continue end
		end
		table.insert(freeProcessors, processor :: any)
	end

	-- reuse unused processors to process remaining pairs
	-- if no more available unused processors, create new for the remaining pairs
	for key, value in unprocessedPairs do
		local processor: myProcessor? = table.remove(freeProcessors)
		if processor then -- reuse existing free processor
			local keyState = processor.key
			local valueState = processor.value

			if not isSimilar(keyState.value, key) then
				keyState.value = key
				propagate.outdateAll(keyState)
			end
			if not isSimilar(valueState.value, value) then
				valueState.value = value
				propagate.outdateAll(valueState)
			end
			processor.outPair.updated = false
			processor.updated = false
		else -- create new processor
			local keyState = Value(self, key)
			local valueState = Value(self, value)
			processor = {
				key = keyState,
				value = valueState,
				outPair = {},
				usingKey = nil,
				usingValue = nil,
				listeners = {},
				updated = false,
			} :: any
			assert(processor)

			local function keepBy<C>(state: State.State<C>): C
				local consumed = state.value :: any
				if state == keyState then
					processor.usingKey = consumed
				elseif state == valueState then
					processor.usingValue = consumed
				else
					error(`invalid state (must to be the received state for key or value)`)
				end
				return consumed
			end
			local outPair = Computed(self, function(use, inner)
				processor.usingKey = nil
				processor.usingValue = nil

				if keyState.value == nil then return {} end

				local r = table.pack(xpcall(pairComputer, debug.traceback, use, inner, keyState, valueState, keepBy))
				if not r[1] then
					warn(r[2])
					return { 0 :: any }
				end

				local l = r.n
				return if l == 1 then { SAME, SAME } elseif l == 2 then { SAME, r[2] } else { r[2], r[3] }
			end)

			local lastKey
			local lastValue
			local busy = false
			local function syncOutput()
				if processor.updated or busy then return end
				processor.updated = true
				busy = true

				local outPair = processor.outPair:get()
				local outKey = outPair[1] :: OK
				local outValue = outPair[2] :: OV

				-- solve special outputs
				if outKey == SAME then
					keyState.listeners[processor] = syncOutput
					outKey = keyState.value :: any
				else
					keyState.listeners[processor] = nil :: any
				end
				if outValue == SAME then
					valueState.listeners[processor] = syncOutput
					outValue = valueState.value :: any
				else
					valueState.listeners[processor] = nil :: any
				end

				-- update processors and output
				local valueChanged = not isSimilar(outValue, lastValue)
				local keyChanged = not isSimilar(outKey, lastKey)
				local outputChanged = false

				if keyChanged and lastKey ~= nil and processors[lastKey] == processor then
					processors[lastKey] = nil
					output[lastKey] = nil
					outputChanged = true
				end
				if outKey ~= nil then
					if keyChanged then processors[outKey] = processor end
					if keyChanged or valueChanged then
						output[outKey] = outValue
						outputChanged = true
					end
				end
				lastValue = outValue
				lastKey = outKey
				busy = false

				-- propagate update for Map object if output changed
				if not outputChanged then return end
				if self.busy then
					self.lastOutputChange = updateId
					return
				end
				propagate.outdateAll(self)
				propagate.updateAll(self)
			end
			processor.listeners[processor] = syncOutput
			outPair.listeners[processor] = syncOutput
			processor.outPair = outPair
		end
		table.insert(outdatedStates, processor or never())
	end

	-- clear free processors (happens when more keys has removed over added)
	for _, freeProcessor in freeProcessors do
		freeProcessor.key.value = nil
		freeProcessor.outPair.updated = false
		freeProcessor.outPair:get()
	end

	-- bulk update all `outdatedStates`, and sync all `outPair` to `output`
	for _, listenable in outdatedStates do
		for object, update in listenable.listeners do
			update(object)
		end
	end

	-- end
	self.updated = true
	self.busy = false

	if self.lastOutputChange == updateId then
		propagate.outdateAll(self)
		propagate.updateAll(self)
	end
	return output
end

--// Types
export type Map<IK = any, IV = any, OK = IK, OV = IV, D = {}, processor = processor<IK, IV, OK, OV>> = State.ConsumerState<
	{ [OK]: OV },
	D,
	{
		pairComputer: pairComputer<IK, IV, OK, OV, D>,
		freeProcessors: { processor },
		processors: { [OK]: processor },
		subject: State.State<{ [IK]: IV }>,

		lastOutputChange: any,
		getKey: (Map<IK, IV, OK, OV, D, processor>, key: OK) -> OV,
	}
>
type pairComputer<IK, IV, OK, OV, D> = (
	use: <C>(State.UsedAs<C>) -> C,
	scope: Scope.scope<D>,
	key: State.State<IK, D>,
	value: State.State<IV, D>,
	keepBy: <C>(State.State<C>) -> C
) -> (OK?, OV?)
type processor<IK, IV, OK, OV> = {
	key: State.State<IK?>,
	value: State.State<IV>,
	outPair: Computed.Computed<{ OK | OV }>,
	usingKey: IK?,
	usingValue: IV?,

	listeners: { [any]: (any) -> () },
	updated: boolean,
}

--// End
return Map.new
