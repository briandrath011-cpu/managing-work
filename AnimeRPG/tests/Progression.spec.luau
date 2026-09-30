local GameConfig = require(Modules.Config.GameConfig)
local Progression = require(Modules.Config.Progression)

describe("Progression", function()
	it("exp requirement grows with level", function()
		for level = 1, GameConfig.Progression.MaxLevel - 2 do
			expect(Progression.ExpToNext(level + 1)).toBeGreaterThan(Progression.ExpToNext(level))
		end
	end)

	it("max level needs no more exp", function()
		expect(Progression.ExpToNext(GameConfig.Progression.MaxLevel)).toBe(math.huge)
	end)

	it("applies several level ups from one big exp gain", function()
		local need = Progression.ExpToNext(1) + Progression.ExpToNext(2) + 5
		local level, exp, gained = Progression.ApplyExp(1, 0, need)
		expect(level).toBe(3)
		expect(exp).toBe(5)
		expect(gained).toBe(2)
	end)

	it("clamps at max level and resets exp", function()
		local level, exp = Progression.ApplyExp(GameConfig.Progression.MaxLevel - 1, 0, 1e15)
		expect(level).toBe(GameConfig.Progression.MaxLevel)
		expect(exp).toBe(0)
	end)

	it("ignores negative exp", function()
		local level, exp = Progression.ApplyExp(5, 10, -500)
		expect(level).toBe(5)
		expect(exp).toBe(10)
	end)

	it("mastery caps at 100", function()
		local mastery, exp = Progression.ApplyMasteryExp(0, 0, 1e9)
		expect(mastery).toBe(Progression.MaxMastery)
		expect(exp).toBe(0)
	end)

	it("total stat points match points per level", function()
		expect(Progression.TotalStatPoints(1)).toBe(GameConfig.Progression.StartingStatPoints)
		expect(Progression.TotalStatPoints(11)).toBe(
			GameConfig.Progression.StartingStatPoints + 10 * GameConfig.Progression.StatPointsPerLevel
		)
	end)

	it("defense raises max health, energy stat raises max energy", function()
		expect(Progression.MaxHealth(10, 50)).toBeGreaterThan(Progression.MaxHealth(10, 0))
		expect(Progression.MaxEnergy(100)).toBeGreaterThan(Progression.MaxEnergy(0))
	end)

	it("dash cooldown never drops below the minimum", function()
		expect(Progression.DashCooldown(100000)).toBe(GameConfig.Movement.MinDashCooldown)
	end)
end)
