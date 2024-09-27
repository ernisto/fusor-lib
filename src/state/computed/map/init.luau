--!nolint LocalShadow
--!strict

local package = script.Parent.Parent.Parent
local propagate = require(package.state.propagate)
local Computed = require(package.state.computed)
local Value = require(package.state.value)
local Scope = require(package.memory.scope)
local State = require(package.state)
local isSimilar = require(package.utils.isSimilar)

local NOT_USING_KEY = newproxy(true)

--// Module
local Map = {}
local update

--// Constructor
function Map.new<IK, IV, OK, OV, D>(
    parent: Scope.scope<D>,
    subject: State.UsedAs<{ [IK]: IV }>,
    pairComputer: pairComputer<IK, IV, OK, OV, D>
): Map<IK, IV, OK, OV, D>

    local subjectAsState, alreadyIsState = State.cast(parent, subject)

    local self: Map<IK, IV, OK, OV, D> = parent:child({
        updated = true,
        busy = false,

        listening = { subjectAsState.listeners },
        listeners = {},
        value = {},

        freeProcessors = {},
        processors = {},

        subject = subjectAsState,
        removingOutPairs = {},
        pairComputer = pairComputer,

        getKey = Map.getKey,
        get = Map.get,
    } :: any)

    update(self)

    if alreadyIsState then

        subjectAsState.listeners[self] = update :: any
        propagate.updateAll(self)
    end

    return self
end

--// Methods
function Map.get<OK, OV>(self: Map<unknown, unknown, OK, OV>): { [OK]: OV }
    if not self.updated then update(self) end
    return self.value
end
function Map.getKey<OK, OV>(self: Map<unknown, unknown, OK, OV>, key: OK): OV
    return self.value[key]
end

function update<IK, IV, OK, OV>(self: Map<IK, IV, OK, OV>, updateId: number?, nextMutations: { { [State.State]: any }}?, deltaKeys: { [IK]: IV }?)

    type myProcessor = processor<IK, IV, OK, OV>

    local newValue = self.subject.value
    local output = self.value

    local pairComputer = self.pairComputer
    local freeProcessors = self.freeProcessors
    local processors = self.processors

    local remainingPairs = table.clone(newValue)

    local removingOutPairs = table.clone(output)
    self.removingOutPairs = removingOutPairs

    -- update all processors that is kept by some key or value
    for processor, usingKey in processors do    -- im storing usingKey here (faster than .usingKey) bcuz is the most common case

        -- local usingKey = processor.usingKey
        if usingKey ~= NOT_USING_KEY then

            local value = remainingPairs[usingKey]
            if value ~= nil then

                remainingPairs[usingKey] = nil
                processor.value:set(value)

                continue
            end
        end

        local usingValue = processor.usingValue
        if usingValue ~= nil then
            
            local found = false
            for index, value in remainingPairs do

                if value ~= usingValue then continue end

                remainingPairs[index] = nil
                processor.key:set(index)

                local outKey = processor.outKey
                if outKey then removingOutPairs[outKey] = nil end

                found = true
                break
            end
            if found then continue end
        end

        table.insert(freeProcessors, processor :: any)
    end
    -- reuse or create processors for new pairs
    for key, value in remainingPairs do

        local processor = table.remove(freeProcessors) :: myProcessor
        if processor then   -- reuse existing free processor

            -- processor.usingKey = nil
            processor.usingValue = nil

            processor.value.value = value
            processor.key.value = key
            processor.outPair.updated = false
            processor.syncOutput:get()
        else    -- create new processor

            local keyState = Value(self, key)
            local valueState = Value(self, value)
            local processor: myProcessor = {
                key = keyState, value = valueState,
                outPair = {}, syncOutput = nil,
                usingValue = nil , -- usingKey = nil,
                outKey = nil,
            } :: any

            local function keepBy<C>(state: State.State<C>): C

                local consumed = state.value :: any
                if state == keyState then processors[processor] = consumed
                elseif state == valueState then processor.usingValue = consumed
                else error(`invalid state (must to be the received state for key or value)`)
                end
                return consumed
            end
            local outPair = Computed(self, function(use, inner)

                processors[processor] = NOT_USING_KEY
                processor.usingValue = nil

                local r = table.pack(xpcall(pairComputer, debug.traceback, use, inner, keyState, valueState, keepBy))
                if not r[1] then warn(r[2]); return { 0 :: any } end
                local l = r.n

                return if l == 1 then { 0 }
                    elseif l == 2 then { 1, nil :: any, r[2] :: any }
                    else { 2, r[2] :: any, r[3] :: any }
            end)
            processor.outPair = outPair :: any
            processor.syncOutput = Computed(self, function(use)

                local outPair = use(outPair)
                local l, key, value = outPair[1], outPair[2], outPair[3]

                if l == 0 and value == nil then value = use(valueState) end
                if l ~= 2 and key == nil then key = use(keyState) end

                processor.outKey = key
                if key == nil then return nil end

                self.removingOutPairs[key] = nil
                output[key] = value

                return nil
            end)
        end
    end
    -- clear free processors
    for _,freeProcessor in freeProcessors do

        freeProcessor.key.value = nil
        if freeProcessor.outPair.lastComputation then freeProcessor.outPair.lastComputation:destroy() end
    end
    -- remove old out pairs
    for index in removingOutPairs do
        output[index] = nil
    end
    table.clear(removingOutPairs)

    propagate.updateAll(self)
end

--// Types
export type Map<IK = any, IV = any, OK = IK, OV = IV, D = {}, processor = processor<IK, IV, OK, OV>> = State.ConsumerState<{ [OK]: OV }, D, {
    pairComputer: pairComputer<IK, IV, OK, OV, D>,
    removingOutPairs: { [OK]: any },
    freeProcessors: { processor },
    processors:{ [processor]: IK },
    subject: State.State<{ [IK]: IV }>,

    getKey: (Map<IK, IV, OK, OV, D, processor>, key: OK) -> OV,
}>
type pairComputer<IK, IV, OK, OV, D> = (
    use: <C>(State.UsedAs<C>) -> C,
    scope: Scope.scope<D>,
    key: State.State<IK, D>,
    value: State.State<IV, D>,
    keepBy: <C>(State.State<C>) -> C
) -> (OK|OV?, OV?)
type processor<IK, IV, OK, OV> = {
    key: State.State<IK?>, value: State.State<IV>,
    outPair: Computed.Computed<{ OK|OV }>, syncOutput: State.State,
    usingValue: IV?, -- usingKey: IK,
    outKey: OK,
}

--// End
return Map.new