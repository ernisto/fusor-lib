local package = script.Parent.Parent

--// Consts
local TRACEBACK_LIMIT = 255
local ALIAS = {
	['^Server%w+.Packages.Index'] = 'server-packages',
	['^%w+.Packages.Index'] = 'packages',
	['^ServerScriptService'] = 'server',
	['^%w+.Shared'] = 'shared',
	['^StarterPlayer.StarterCharacterScripts'] = 'character',
	['^StarterPlayer.StarterPlayerScripts'] = 'client',
	['^Players.(%w+)'] = 'client(%1)',
	['^%w+.Client'] = 'client',
	['cloud_%d+.(%w+)'] = 'plugin.%1',
	['^%[C%]'] = 'roblox',
	-- ["^game.(%w+)"] = "%1",
}
ALIAS['^%[string (%b"")%]'] = function(qPath)
	local path = string.sub(qPath, 2, -2)
	for regex, alias in pairs(ALIAS) do
		local r = string.gsub(path, regex, alias)
		if r ~= path then return r end
	end
	return path
end

--// Functions
export type stackframe = {
	path: string,
	line: number,
	name: string,
	target: () -> (),
	paramCount: number,
	isVariadic: boolean,
}
local function shortPath(stackframe: stackframe): string
	local path = stackframe.path
	for regex, alias in pairs(ALIAS) do
		local r = string.gsub(path, regex, alias)
		if r ~= path then return r end
	end
	return path
end
local function displayStackFrame(stackframe: stackframe): string
	return `{shortPath(stackframe)}:{stackframe.line} - function {stackframe.name}`
end
local function stackframe(func: thread | number | () -> ()?, level: number?): stackframe?
	local path, line, name, target, paramCount, isVariadic
	if typeof(func) == 'function' then
		path, line, name, target, paramCount, isVariadic = debug.info(func, 'slnfa')
	elseif typeof(level) == 'number' and type(func) == 'thread' then
		path, line, name, target, paramCount, isVariadic = debug.info(func, level, 'slnfa')
	else
		path, line, name, target, paramCount, isVariadic = debug.info(func or 1, 'slnfa')
	end
	if not line then return end
	return table.freeze(setmetatable({
		path = path,
		line = line,
		name = name,
		target = target,
		paramCount = paramCount,
		isVariadic = isVariadic,
	}, {
		__tostring = displayStackFrame,
	})) :: any
end

local function displayStacktrace(stacktrace: { stackframe }, message: string?): string
	local r = message or ''
	for _, frame in stacktrace do
		r ..= '\n' .. displayStackFrame(frame)
	end
	return r
end
return function(thread: thread?, limit: number?): { stackframe }
	local backtrace = {}
	local level = 0
	repeat
		level += 1
		local frame = if thread then stackframe(thread, level) else stackframe(level)
		if not frame then break end

		if frame.path:match(package:GetFullName()) then continue end
		table.insert(backtrace, frame)
	until level > (limit or TRACEBACK_LIMIT)

	return table.freeze(setmetatable(backtrace, { __tostring = displayStacktrace })) :: any
end
