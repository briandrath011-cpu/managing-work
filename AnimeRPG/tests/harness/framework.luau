--!nocheck
-- Tiny test framework: describe / it / expect
local __passed, __failed = 0, 0
local __current = ""

function describe(name, fn)
	__current = name
	fn()
end

function it(name, fn)
	local ok, err = pcall(fn)
	if ok then
		__passed += 1
	else
		__failed += 1
		print(string.format("FAIL  %s > %s\n      %s", __current, name, tostring(err)))
	end
end

function expect(value)
	local api = {}
	function api.toBe(expected)
		if value ~= expected then
			error(string.format("expected %s to be %s", tostring(value), tostring(expected)), 2)
		end
	end
	function api.toBeCloseTo(expected, epsilon)
		if math.abs(value - expected) > (epsilon or 1e-6) then
			error(string.format("expected %s to be close to %s", tostring(value), tostring(expected)), 2)
		end
	end
	function api.toBeTruthy()
		if not value then
			error("expected value to be truthy, got " .. tostring(value), 2)
		end
	end
	function api.toBeFalsy()
		if value then
			error("expected value to be falsy, got " .. tostring(value), 2)
		end
	end
	function api.toBeGreaterThan(expected)
		if not (value > expected) then
			error(string.format("expected %s > %s", tostring(value), tostring(expected)), 2)
		end
	end
	function api.toBeLessThan(expected)
		if not (value < expected) then
			error(string.format("expected %s < %s", tostring(value), tostring(expected)), 2)
		end
	end
	function api.toBeBetween(min, max)
		if value < min or value > max then
			error(string.format("expected %s to be between %s and %s", tostring(value), tostring(min), tostring(max)), 2)
		end
	end
	return api
end

function __finish()
	print(string.format("\n%d passed, %d failed", __passed, __failed))
	if __failed > 0 then
		error("tests failed")
	end
end

Modules = __root
