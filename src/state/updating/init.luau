--// Module
local static = {}

export type onUpdate<Object = any> = (Object, whoChanged: Object, rootUpdateId: number, nestedUpdateId: number) -> ()
export type listeners<Object = any> = {{ [Object]: onUpdate<Object> }}

--// Vars
local updateId = -2^53    -- lowest integer (lower than it will be turned into a float, that havent enough precision for adictions)

--// Methods
local function update(pool: listeners, state: any, _rootId: number?)

    updateId += 1

    local rootUpdateId = _rootId or updateId
    local reupdate = {}

    for priority, watchers in ipairs(pool) do
        for object, update in watchers do
            local lastUpdate = update(object, state, rootUpdateId, updateId)
            if lastUpdate then reupdate[state] = update end   -- TODO: resolve cyclic updates
        end
    end
    while next(reupdate) do
        for object, update in reupdate do
            local alreadyUpdated = update(object, state, rootUpdateId, updateId)
            if alreadyUpdated then reupdate[state] = update end
        end
    end
end
local function unlisten<Object>(self: listeners, priority: number, state: Object)

    self[priority][state] = nil
end
local function listen<Object>(self: listeners, priority: number, state: Object, onUpdate: onUpdate<Object>)

    local len = #self
    if len >= priority then
        self[priority][state] = onUpdate
    else
        for i = len, priority-1 do self[i] = {} end
        self[priority] = setmetatable({ [state] = onUpdate }, { __mode = 'k' }) :: any
    end
end

--// End
static.update = update
static.listen = listen
static.unlisten = unlisten
return table.freeze(static)