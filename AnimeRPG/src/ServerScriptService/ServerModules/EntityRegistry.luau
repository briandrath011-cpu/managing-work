--[[
	EntityRegistry (ModuleScript)
	Location: ServerScriptService.ServerModules.EntityRegistry

	Every combat-capable model (player characters, enemies, bosses, summons) is registered here
	with a server-only state table. Combat logic only ever reads THIS state, never client values.
	A few fields are mirrored to Model attributes so clients can render them (Stunned, Blocking, Guard...).
]]
local Players = game:GetService("Players")

local EntityRegistry = {}

export type Entity = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Player: Player?,
	IsNPC: boolean,
	Team: string, -- "Players" | "Enemies" | "Allies"
	Level: number,
	Stats: { [string]: number },
	Defense: number,
	Modifiers: { [string]: number },
	Definition: any?, -- enemy/boss definition for NPCs
	State: {
		Blocking: boolean,
		BlockStart: number,
		Guard: number,
		StunnedUntil: number,
		IFramesUntil: number,
		ActionLockUntil: number,
		Combo: number,
		LastM1: number,
		LastHeavy: number,
		LastDash: number,
		LastCombatTime: number,
		CounterUntil: number,
		CounterCallback: ((attacker: any) -> ())?,
		FrozenUntil: number,
		SuperArmorUntil: number,
		Buffs: { [string]: { Modifiers: { [string]: number }, Expires: number } },
		Cooldowns: { [string]: number },
		Downed: boolean,
		Mark: Model?,
	},
	DamageContrib: { [Player]: number },
	Owner: Player?, -- summons belong to a player
}

local entities: { [Model]: Entity } = {}

local function newState()
	return {
		Blocking = false,
		BlockStart = 0,
		Guard = 100,
		StunnedUntil = 0,
		IFramesUntil = 0,
		ActionLockUntil = 0,
		Combo = 0,
		LastM1 = 0,
		LastHeavy = 0,
		LastDash = 0,
		LastCombatTime = 0,
		CounterUntil = 0,
		CounterCallback = nil,
		FrozenUntil = 0,
		SuperArmorUntil = 0,
		Buffs = {},
		Cooldowns = {},
		Downed = false,
		Mark = nil,
	}
end

function EntityRegistry.Register(model: Model, info: { [string]: any }): Entity?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return nil
	end
	local entity: Entity = {
		Model = model,
		Humanoid = humanoid,
		Root = root :: BasePart,
		Player = info.Player,
		IsNPC = info.Player == nil,
		Team = info.Team or (info.Player and "Players" or "Enemies"),
		Level = info.Level or 1,
		Stats = info.Stats or { Strength = 0, Defense = 0, Energy = 0, Weapon = 0, Agility = 0 },
		Defense = info.Defense or 0,
		Modifiers = info.Modifiers or {},
		Definition = info.Definition,
		State = newState(),
		DamageContrib = {},
		Owner = info.Owner,
	}
	entities[model] = entity
	model:SetAttribute("Entity", true)
	model:SetAttribute("Team", entity.Team)
	model:SetAttribute("Level", entity.Level)
	model:SetAttribute("Guard", 100)
	model:SetAttribute("Blocking", false)
	model:SetAttribute("Stunned", false)
	model.Destroying:Connect(function()
		entities[model] = nil
	end)
	return entity
end

function EntityRegistry.Unregister(model: Model)
	entities[model] = nil
end

function EntityRegistry.Get(model: Instance?): Entity?
	if not model then
		return nil
	end
	return entities[model :: Model]
end

-- Finds the entity that owns a part (for hitbox results).
function EntityRegistry.FromPart(part: BasePart): Entity?
	local current: Instance? = part
	while current and current ~= workspace do
		local entity = entities[current :: Model]
		if entity then
			return entity
		end
		current = current.Parent
	end
	return nil
end

function EntityRegistry.GetForPlayer(player: Player): Entity?
	local character = player.Character
	return character and entities[character] or nil
end

function EntityRegistry.All(): { [Model]: Entity }
	return entities
end

function EntityRegistry.IsAlive(entity: Entity?): boolean
	return entity ~= nil and entity.Model.Parent ~= nil and entity.Humanoid.Health > 0 and not entity.State.Downed
end

function EntityRegistry.AreEnemies(a: Entity, b: Entity): boolean
	if a == b then
		return false
	end
	local ta, tb = a.Team, b.Team
	if ta == "Allies" then
		ta = "Players"
	end
	if tb == "Allies" then
		tb = "Players"
	end
	if ta == "Players" and tb == "Players" then
		-- PvP: only when enabled and both are real players in a PvP zone.
		return a.Player ~= nil and b.Player ~= nil and a.Model:GetAttribute("PvP") == true and b.Model:GetAttribute("PvP") == true
	end
	return ta ~= tb
end

function EntityRegistry.IsStunned(entity: Entity): boolean
	local now = os.clock()
	return now < entity.State.StunnedUntil or now < entity.State.FrozenUntil
end

function EntityRegistry.CanAct(entity: Entity): boolean
	local now = os.clock()
	return EntityRegistry.IsAlive(entity)
		and now >= entity.State.StunnedUntil
		and now >= entity.State.FrozenUntil
		and now >= entity.State.ActionLockUntil
end

-- Returns the aggregated buff modifiers still active and prunes expired buffs.
function EntityRegistry.BuffModifiers(entity: Entity): { { [string]: number } }
	local list = {}
	local now = os.clock()
	for name, buff in pairs(entity.State.Buffs) do
		if now >= buff.Expires then
			entity.State.Buffs[name] = nil
		else
			table.insert(list, buff.Modifiers)
		end
	end
	return list
end

function EntityRegistry.PlayerFromModel(model: Model): Player?
	return Players:GetPlayerFromCharacter(model)
end

return EntityRegistry
