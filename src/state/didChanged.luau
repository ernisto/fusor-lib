return function(value1, value2)
    return if typeof(value1) == 'table' and not table.isfrozen(value1) then false
        else value1 == value2
end