local RarityConfig = require(Modules.Config.RarityConfig)
local SpinLogic = require(Modules.Powers.SpinLogic)
local PowerRegistry = require(Modules.Powers.PowerRegistry)

describe("Spin chances", function()
	it("spin chances add up to 100%", function()
		local total = 0
		for _, rarity in ipairs(RarityConfig.Order) do
			total += RarityConfig.SpinChances[rarity]
		end
		expect(total).toBeCloseTo(100)
	end)

	it("trait chances add up to 100%", function()
		local total = 0
		for _, rarity in ipairs(RarityConfig.Order) do
			total += RarityConfig.TraitChances[rarity]
		end
		expect(total).toBeCloseTo(100)
	end)

	it("roll distribution matches the configured chances (no pity)", function()
		local rng = Random.new(42)
		local counts = {}
		local rolls = 100000
		local noPity = {}
		for _ = 1, rolls do
			local rarity = SpinLogic.RollRarity(rng, {}, nil, noPity)
			counts[rarity] = (counts[rarity] or 0) + 1
		end
		for _, rarity in ipairs(RarityConfig.Order) do
			local observed = (counts[rarity] or 0) / rolls * 100
			expect(observed).toBeBetween(RarityConfig.SpinChances[rarity] - 1, RarityConfig.SpinChances[rarity] + 1)
		end
	end)
end)

describe("Pity", function()
	it("guarantees the pity rarity on the threshold spin", function()
		local rng = Random.new(7)
		for _, rule in ipairs(RarityConfig.Pity) do
			for _ = 1, 200 do
				local pity = { [rule.Rarity] = rule.Threshold - 1 }
				local rarity, hit = SpinLogic.RollRarity(rng, pity)
				expect(RarityConfig.IsAtLeast(rarity, rule.Rarity)).toBeTruthy()
				local _ = hit
			end
		end
	end)

	it("counts up without the rarity and resets when it is reached", function()
		local pity = { Legendary = 5, Mythic = 5, Secret = 5 }
		local after = SpinLogic.UpdatePity(pity, "Common")
		expect(after.Legendary).toBe(6)
		expect(after.Mythic).toBe(6)
		local afterLegendary = SpinLogic.UpdatePity(after, "Legendary")
		expect(afterLegendary.Legendary).toBe(0)
		expect(afterLegendary.Mythic).toBe(7)
		local afterSecret = SpinLogic.UpdatePity(afterLegendary, "Secret")
		expect(afterSecret.Legendary).toBe(0)
		expect(afterSecret.Mythic).toBe(0)
		expect(afterSecret.Secret).toBe(0)
	end)

	it("never needs more than the threshold spins for a legendary", function()
		local rng = Random.new(99)
		local pity = {}
		local sinceLegendary = 0
		local worst = 0
		for _ = 1, 20000 do
			local rarity = SpinLogic.RollRarity(rng, pity)
			pity = SpinLogic.UpdatePity(pity, rarity)
			sinceLegendary += 1
			if RarityConfig.IsAtLeast(rarity, "Legendary") then
				worst = math.max(worst, sinceLegendary)
				sinceLegendary = 0
			end
		end
		expect(worst).toBeBetween(1, RarityConfig.Pity[1].Threshold)
	end)

	it("picks a power of the rolled rarity", function()
		local rng = Random.new(3)
		for _, rarity in ipairs(RarityConfig.Order) do
			local power, actual = SpinLogic.PickPower(rng, rarity, PowerRegistry.ByRarity)
			expect(power ~= nil).toBeTruthy()
			expect(actual).toBe(rarity)
			expect(power.Rarity).toBe(rarity)
		end
	end)

	it("falls back to a lower rarity when a rarity has no powers", function()
		local rng = Random.new(3)
		local power, actual = SpinLogic.PickPower(rng, "Secret", function(r)
			if r == "Secret" then
				return {}
			end
			return PowerRegistry.ByRarity(r)
		end)
		expect(actual).toBe("Mythic")
		expect(power.Rarity).toBe("Mythic")
	end)
end)
