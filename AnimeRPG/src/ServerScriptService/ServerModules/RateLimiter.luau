--[[
	RateLimiter (ModuleScript)
	Location: ServerScriptService.ServerModules.RateLimiter
	Token bucket per player per key. Protects every RemoteEvent/RemoteFunction from spam.
]]
local Players = game:GetService("Players")

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(maxTokens: number, refillPerSecond: number)
	local self = setmetatable({
		_max = maxTokens,
		_refill = refillPerSecond,
		_buckets = {},
	}, RateLimiter)
	Players.PlayerRemoving:Connect(function(player)
		self._buckets[player] = nil
	end)
	return self
end

function RateLimiter:Check(player: Player, cost: number?): boolean
	local now = os.clock()
	local bucket = self._buckets[player]
	if not bucket then
		bucket = { Tokens = self._max, Last = now }
		self._buckets[player] = bucket
	end
	bucket.Tokens = math.min(self._max, bucket.Tokens + (now - bucket.Last) * self._refill)
	bucket.Last = now
	local price = cost or 1
	if bucket.Tokens < price then
		return false
	end
	bucket.Tokens -= price
	return true
end

return RateLimiter
