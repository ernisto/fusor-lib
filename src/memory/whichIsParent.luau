local never = require(script.Parent.Parent.utils.never)
local Scope = require(script.Parent.scope)

local function whichIsParent<A, B>(shallower: Scope.scope<A>, deeper: Scope.scope<B>): Scope.scope<A | B>?
	local shallowerDepth = shallower.depth
	local deeperDepth = deeper.depth

	if deeperDepth < shallowerDepth then
		shallowerDepth, deeperDepth = deeperDepth, shallowerDepth
		shallower, deeper = deeper, shallower
	end

	local parent = deeper

	for i = deeperDepth, shallowerDepth - 1 do
		parent = parent.parent or never()
	end
	if parent == shallower :: any then return shallower end

	parent = parent.parent or never()
	if parent ~= shallower.parent :: any then return end

	return if shallower.timestamp < deeper.timestamp then shallower else deeper
end
return whichIsParent
