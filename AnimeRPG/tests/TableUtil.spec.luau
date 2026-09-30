local TableUtil = require(Modules.Shared.TableUtil)
local WeightedRandom = require(Modules.Shared.WeightedRandom)
local DataTemplate = require(Modules.Config.DataTemplate)
local GameConfig = require(Modules.Config.GameConfig)
local Format = require(Modules.Shared.Format)

describe("TableUtil", function()
	it("deep copies without sharing references", function()
		local original = { A = { B = 1 } }
		local copy = TableUtil.DeepCopy(original)
		copy.A.B = 2
		expect(original.A.B).toBe(1)
	end)

	it("reconcile adds new template fields to old saves", function()
		local old = { Level = 5, Stats = { Strength = 3 }, Powers = { Owned = { abc = { Id = "Blaze" } } } }
		TableUtil.Reconcile(old, DataTemplate)
		expect(old.Level).toBe(5)
		expect(old.Stats.Strength).toBe(3)
		expect(old.Stats.Agility).toBe(0)
		expect(old.Gold).toBe(DataTemplate.Gold)
		expect(old.Powers.Owned.abc.Id).toBe("Blaze")
		expect(old.Powers.StorageSlots).toBe(DataTemplate.Powers.StorageSlots)
		expect(old.Discovered.LastWaypoint).toBe("GreenwoodVillage")
	end)

	it("reconcile does not inject into dynamic maps", function()
		local old = { Inventory = { x = { Id = "WolfFang", Amount = 1 } } }
		TableUtil.Reconcile(old, DataTemplate)
		expect(TableUtil.Count(old.Inventory)).toBe(1)
	end)

	it("template stats match the configured stats", function()
		for _, stat in ipairs(GameConfig.Stats) do
			expect(DataTemplate.Stats[stat]).toBe(0)
		end
		expect(TableUtil.Count(DataTemplate.Stats)).toBe(#GameConfig.Stats)
	end)
end)

describe("WeightedRandom", function()
	it("never picks zero-weight entries", function()
		local rng = Random.new(5)
		for _ = 1, 2000 do
			local pick = WeightedRandom.PickEntry({ { Id = "a", Weight = 0 }, { Id = "b", Weight = 1 } }, rng)
			expect(pick.Id).toBe("b")
		end
	end)

	it("returns nil when every weight is zero", function()
		expect(WeightedRandom.PickKey({ a = 0 }, Random.new(1))).toBe(nil)
	end)
end)

describe("Format", function()
	it("shortens big numbers", function()
		expect(Format.Short(999)).toBe("999")
		expect(Format.Short(1500)).toBe("1.5K")
		expect(Format.Short(2500000)).toBe("2.5M")
	end)

	it("formats time", function()
		expect(Format.Time(65)).toBe("1:05")
		expect(Format.Time(3725)).toBe("1:02:05")
	end)

	it("adds commas", function()
		expect(Format.Commas(1234567)).toBe("1,234,567")
	end)
end)
