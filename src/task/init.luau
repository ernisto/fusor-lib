local funcs = table.clone(task)
funcs.afterYield = task.defer

return table.freeze(funcs) :: typeof(task) & {
    afterYield: typeof(task.defer)
}