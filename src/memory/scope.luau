--// Packages
local traceback = require('../debug/traceback')

--// Settings
local TRACEBACK_SCOPES = _G.TRACEBACK_SCOPES

--// Root
local scope = { depth = 0, parent = nil }
scope.__cachedMerges = setmetatable({}, { __mode = 'k' })
scope.__index = scope

local destroying = setmetatable({}, { __mode = 'k' })

--// Methods
function scope.destroy(self: scope): ()
	local parent = self.parent
	if parent == nil then return end

	if destroying[self] then return end
	destroying[self] = true

	for i = #self, 1, -1 do
		local v = (self :: any)[i]

		if typeof(v) == 'table' then
			scope.destroy(v)
		elseif typeof(v) == 'function' then
			v(self)
		end
		(self :: any)[i] = nil
	end
	self.parent = nil
end
function scope.host<Child...>(parent: _scope, ...: Child...): Child...
	for _, child in { select(1, ...) } do
		table.insert(parent, child)

		if type(child) ~= 'table' then continue end
		if rawget(child, 'parent') == nil then continue end

		table.insert(child, function()
			if destroying[parent] then return end

			local index = table.find(parent, child)
			if index then table.remove(parent, index) end
		end)
	end
	return ...
end

function scope.derivable(root: _scope, ...): _scope
	local out = root.__index

	for _, data in { ... } do
		local cache = root.__cachedMerges

		local cached = cache[data]
		if cached then
			out = cached
			continue
		end

		out = table.clone(out) :: any
		for index, value in data do
			out[index] = value
		end

		out.__cachedMerges = setmetatable({}, { __mode = 'k' }) :: any
		out.__index = out
		cache[data] = table.freeze(setmetatable(out, root)) :: any
	end
	return out
end
function scope.derive<Fields, Derived>(parent: _scope<{}, Derived>, fields: Fields, ...): _scope<Fields, Derived>
	local sub = setmetatable(fields or {} :: any, scope.derivable(parent, ...))
	sub.__index = parent.__index
	sub.timestamp = os.clock()
	sub.parent = parent.parent
	sub.depth = parent.depth

	if TRACEBACK_SCOPES ~= false then sub.backtrace = traceback() end
	return sub
end

function scope.unhostedChild<Fields, Derived>(parent: _scope<{}, Derived>, fields: Fields, ...): _scope<Fields, Derived>
	local child = setmetatable(fields or {} :: any, scope.derivable(parent, ...))
	child.__index = parent.__index
	child.timestamp = os.clock()
	child.parent = parent
	child.depth = parent.depth + 1

	if TRACEBACK_SCOPES ~= false then child.backtrace = traceback() end
	return child
end
function scope.child<Fields, Derived>(parent: _scope<{}, Derived>, fields: Fields, ...): _scope<Fields, Derived>
	return scope.host(parent, scope.unhostedChild(parent, fields, ...))
end

--// Types
export type scope<H = {}, F = {}> = _scope<funcs & H, F> & { child<H, F> }
type child<H, F> = _scope<H, F> | (_scope<H, F>) -> ()

type _scope<H = {}, F = {}> = F & H & {
	timestamp: number,
	depth: number,
	parent: _scope<H, F>?,
	__cachedMerges: { [any]: _scope<H, F> },
	__index: _scope<H, F>,
}
type derive =
	(<C, H>(parent: _scope<H>, C) -> _scope<H, C>)
	& (<C, H, H1>(parent: _scope<H>, C, H1) -> _scope<H & H1, C>)
	& (<C, H, H1, H2>(parent: _scope<H>, C, H1, H2) -> _scope<H & H1 & H2, C>)
	& (<C, H, H1, H2, H3>(parent: _scope<H>, C, H1, H2, H3) -> _scope<H & H1 & H2 & H3, C>)
	& (<C, H, H1, H2, H3, H4>(parent: _scope<H>, C, H1, H2, H3, H4) -> _scope<H & H1 & H2 & H3 & H4, C>)
	& (<C, H, H1, H2, H3, H4, H5>(parent: _scope<H>, C, H1, H2, H3, H4, H5) -> _scope<H & H1 & H2 & H3 & H4 & H5, C>)
	& (<C, H, H1, H2, H3, H4, H5, H6>(
		parent: _scope<H>,
		C,
		H1,
		H2,
		H3,
		H4,
		H5,
		H6
	) -> _scope<H & H1 & H2 & H3 & H4 & H5 & H6, C>)

type funcs = {
	destroy: (self: _scope) -> (),
	host: <H, F, C...>(parent: _scope<H, F>, C...) -> C...,

	unhostedChild: derive,
	child: derive,

	derive: derive,
	derivable: (<H, H1>(parent: _scope<H>, H1) -> _scope<H & H1>)
		& (<H, H1, H2>(parent: _scope<H>, H1, H2) -> _scope<H & H1 & H2>)
		& (<H, H1, H2, H3>(parent: _scope<H>, H1, H2, H3) -> _scope<H & H1 & H2 & H3>)
		& (<H, H1, H2, H3, H4>(parent: _scope<H>, H1, H2, H3, H4) -> _scope<H & H1 & H2 & H3 & H4>)
		& (<H, H1, H2, H3, H4, H5>(parent: _scope<H>, H1, H2, H3, H4, H5) -> _scope<H & H1 & H2 & H3 & H4 & H5>)
		& (<H, H1, H2, H3, H4, H5, H6>(
			parent: _scope<H>,
			H1,
			H2,
			H3,
			H4,
			H5,
			H6
		) -> _scope<H & H1 & H2 & H3 & H4 & H5 & H6>),
}
return table.freeze(scope :: any) :: scope
