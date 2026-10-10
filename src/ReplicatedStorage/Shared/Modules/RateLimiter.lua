--!strict
-- Shared/Modules/RateLimiter.lua  (docs/16_technical_architecture.md §5)
--
-- Token bucket per key (usually a Player). A bucket holds up to `burst` tokens and refills at `rate` per second.
--   RateLimiter.new(15, 20)   -- 15/s, burst 20
--   RateLimiter.new(0, 1)     -- once per session (never refills)
--   RateLimiter.new(1 / 5, 1) -- once per 5 s

export type RateLimiter = {
	try: (self: RateLimiter, key: any, cost: number?) -> boolean,
	reset: (self: RateLimiter, key: any) -> (),
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

-- clock is injectable for tests; it defaults to os.clock.
function RateLimiter.new(rate: number, burst: number, clock: (() -> number)?): RateLimiter
	assert(rate >= 0, "RateLimiter rate must be >= 0")
	assert(burst >= 1, "RateLimiter burst must be >= 1")
	local self = {
		_rate = rate,
		_burst = burst,
		_clock = clock or os.clock,
		-- Strong keys on purpose: in a weak table, an Instance key can be collected while the Instance is still
		-- in the game, which would hand out a fresh bucket. The owner calls reset(key) when a key goes away.
		_buckets = {},
	}
	return (setmetatable(self, RateLimiter) :: any) :: RateLimiter
end

-- Takes `cost` tokens (default 1). Returns false, taking nothing, when the bucket doesn't hold enough.
function RateLimiter.try(self: any, key: any, cost: number?): boolean
	local now = self._clock()
	local bucket = self._buckets[key]
	if not bucket then
		bucket = { tokens = self._burst, last = now }
		self._buckets[key] = bucket
	else
		bucket.tokens = math.min(self._burst, bucket.tokens + (now - bucket.last) * self._rate)
		bucket.last = now
	end
	local needed = cost or 1
	if bucket.tokens < needed then
		return false
	end
	bucket.tokens -= needed
	return true
end

function RateLimiter.reset(self: any, key: any)
	self._buckets[key] = nil
end

return RateLimiter
