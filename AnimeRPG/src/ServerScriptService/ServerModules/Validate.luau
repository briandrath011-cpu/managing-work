--[[
	Validate (ModuleScript)
	Location: ServerScriptService.ServerModules.Validate
	Type/shape checks for data coming from clients. Anything that fails is ignored.
]]
local Validate = {}

function Validate.String(value: any, maxLength: number?): boolean
	return type(value) == "string" and #value > 0 and #value <= (maxLength or 64)
end

function Validate.Number(value: any, min: number?, max: number?): boolean
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return false
	end
	if min and value < min then
		return false
	end
	if max and value > max then
		return false
	end
	return true
end

function Validate.Integer(value: any, min: number?, max: number?): boolean
	return Validate.Number(value, min, max) and math.floor(value) == value
end

function Validate.Vector3(value: any, maxMagnitude: number?): boolean
	if typeof(value) ~= "Vector3" then
		return false
	end
	if value.X ~= value.X or value.Y ~= value.Y or value.Z ~= value.Z then
		return false
	end
	return value.Magnitude <= (maxMagnitude or 100000)
end

function Validate.OneOf(value: any, options: { any }): boolean
	return table.find(options, value) ~= nil
end

function Validate.Table(value: any): boolean
	return type(value) == "table"
end

function Validate.Boolean(value: any): boolean
	return type(value) == "boolean"
end

return Validate
