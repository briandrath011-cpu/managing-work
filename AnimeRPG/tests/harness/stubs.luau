--!nocheck
-- Minimal Roblox API stubs for running pure game modules in the standalone luau VM.

-- Virtual instance tree -------------------------------------------------------------------------
local NodeMeta = {}
NodeMeta.__index = function(node, key)
	local method = rawget(NodeMeta, key)
	if method then
		return method
	end
	local child = rawget(node, "__children")[key]
	if child then
		return child
	end
	error("Virtual instance '" .. rawget(node, "Name") .. "' has no child '" .. tostring(key) .. "'", 2)
end

function NodeMeta.GetChildren(node)
	local list = {}
	for _, child in pairs(rawget(node, "__children")) do
		table.insert(list, child)
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

function NodeMeta.FindFirstChild(node, name)
	return rawget(node, "__children")[name]
end

function NodeMeta.IsA(node, className)
	return rawget(node, "ClassName") == className
end

function NodeMeta.GetFullName(node)
	local parent = rawget(node, "Parent")
	if parent then
		return parent:GetFullName() .. "." .. rawget(node, "Name")
	end
	return rawget(node, "Name")
end

function __makeNode(name, className, parent)
	local node = setmetatable({ Name = name, ClassName = className, Parent = parent, __children = {} }, NodeMeta)
	if parent then
		rawget(parent, "__children")[name] = node
	end
	return node
end

function __registerModule(root, segments, loader)
	local node = root
	for i = 1, #segments - 1 do
		local existing = rawget(node, "__children")[segments[i]]
		node = existing or __makeNode(segments[i], "Folder", node)
	end
	local moduleNode = __makeNode(segments[#segments], "ModuleScript", node)
	rawset(moduleNode, "__loader", loader)
	return moduleNode
end

local __cache = {}
local __loading = {}
function require(node)
	if __cache[node] ~= nil then
		return __cache[node]
	end
	assert(type(node) == "table" and rawget(node, "__loader"), "require() expects a virtual ModuleScript")
	assert(not __loading[node], "Circular require: " .. node:GetFullName())
	__loading[node] = true
	local result = rawget(node, "__loader")(node)
	__loading[node] = nil
	__cache[node] = result
	return result
end

-- Vector3 -----------------------------------------------------------------------------------------
local Vector3Meta = {}
Vector3 = {}
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3Meta)
end
Vector3.new = v3
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)
Vector3Meta.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3Meta.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3Meta.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
Vector3Meta.__mul = function(a, b)
	if type(a) == "number" then
		return v3(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3Meta.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
Vector3Meta.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
Vector3Meta.__index = function(v, key)
	if key == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif key == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return v3(v.X / m, v.Y / m, v.Z / m)
	elseif key == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	end
	return nil
end

-- Vector2 / UDim2 (only constructed, never used in logic) -------------------------------------------
Vector2 = {
	new = function(x, y)
		return { X = x, Y = y }
	end,
}

-- Color3 -------------------------------------------------------------------------------------------
local Color3Meta = {}
Color3Meta.__index = {
	Lerp = function(a, b, t)
		return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
	end,
}
Color3 = {}
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3Meta)
end
function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHSV(h, s, v)
	return Color3.new(v, v, v)
end

-- Random (deterministic xorshift-like LCG) ------------------------------------------------------------
Random = {}
local RandomMeta = {}
RandomMeta.__index = RandomMeta
function Random.new(seed)
	return setmetatable({ state = (seed or 12345) % 2147483647 + 1 }, RandomMeta)
end
function RandomMeta:_next()
	self.state = (self.state * 48271) % 2147483647
	return self.state
end
function RandomMeta:NextNumber(min, max)
	local x = (self:_next() - 1) / 2147483646
	if min then
		return min + (max - min) * x
	end
	return x
end
function RandomMeta:NextInteger(min, max)
	return min + (self:_next() % (max - min + 1))
end

-- Enum proxy: Enum.KeyCode.One -> { Name = "One", EnumType = "KeyCode" } --------------------------------
local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, enumType)
		if not enumCache[enumType] then
			enumCache[enumType] = setmetatable({}, {
				__index = function(t, item)
					local value = { Name = item, EnumType = enumType }
					rawset(t, item, value)
					return value
				end,
			})
		end
		return enumCache[enumType]
	end,
})

UDim2 = {
	new = function()
		return {}
	end,
	fromOffset = function()
		return {}
	end,
	fromScale = function()
		return {}
	end,
}
warn = function(...)
	print("WARN:", ...)
end
