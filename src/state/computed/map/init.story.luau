local package = script.Parent.Parent.Parent.Parent
local Scope = require(package.memory.scope)
local Map = require(package.state.computed.map)
local Value = require(package.state.value)
local Computed = require(package.state.computed)

return function()

    local test = Scope:unhostedChild({})

    local function itsPerfect(self)

        local list = Value(self, { 'ernisto', 'malvadao' })
        
        local id = 0
        local upperPlayers = Map(self, list, function(use, scope, key, value, keepBy)

            keepBy(value)
            local name = use(value)

            id += 1
            local id = id
            
            assert(value.value ~= 'ernisto' or id == 1)
            local firstUpdate = true

            Computed(scope, function(use)
                
                local pos = use(key)
                if firstUpdate then firstUpdate = false; return nil end
                
                print(`{name}#{id} moved to {pos}`)
                return
            end)
            print('new', name, '#', id)
            table.insert(scope, function() print('bye', name, '#', id) end)

            return string.upper(name)
        end)
        warn('list: [', table.concat(list.value, ', '), '] -> [', table.concat(upperPlayers.value, ', '), ']')

        list:set{ 'preto', 'ernisto' }
        warn('list: [', table.concat(list.value, ', '), '] -> [', table.concat(upperPlayers:get(), ', '), ']')

        list:set{ 'pobre', 'preto', 'ernisto' }
        warn('list: [', table.concat(list.value, ', '), '] -> [', table.concat(upperPlayers:get(), ', '), ']')
        
        list:set{ 'ernisto', 'preto', 'chama' }
        warn('list: [', table.concat(list.value, ', '), '] -> [', table.concat(upperPlayers:get(), ', '), ']')

        list:set{ 'preto', 'chama' }
        warn('list: [', table.concat(list.value, ', '), '] -> [', table.concat(upperPlayers:get(), ', '), ']')
    end

    local t = task.spawn(itsPerfect, test:child({}))
    table.insert(test, function() task.cancel(t) end)

    return function()

        test:destroy()
    end
end