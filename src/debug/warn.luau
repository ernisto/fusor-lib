--!nocheck
--!nolint
local function map<IK, IV, OV>(arr: { IV }, mapper: (IK, IV) -> OV): { OV }
	local out = {}
	for i, v in arr do
		table.insert(out, mapper(v))
	end
	return out
end
return warn or function(...: any) print(`[WARN]: {table.concat(map({ ... }, tostring), ' ')}`) end :: (...any) -> ()
