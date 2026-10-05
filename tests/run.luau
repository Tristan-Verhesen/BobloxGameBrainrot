-- Offline test suite, run with Lune (https://lune-org.github.io/docs):
--   lune run tests/run.luau
--
-- Loads the real shared modules from src/shared (configs, Formulas, Format,
-- MapLayout, WeightedRandom) with Roblox datatypes from @lune/roblox, then
-- checks config integrity, game math, map geometry, and that every name used
-- across scripts (sound cues, remotes, effects, windows) actually exists.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

-- Minimal module loader that mimics `script.Parent.X` + `require(...)` ------------

local moduleCache = {}

-- fs calls yield, which isn't allowed inside metamethods, so index the source
-- tree up front.
local knownPaths: { [string]: "file" | "dir" } = {}
local function indexTree(dir: string)
	knownPaths[dir] = "dir"
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			indexTree(path)
		elseif string.match(name, "%.luau$") then
			knownPaths[string.gsub(path, "%.luau$", "")] = "file"
		end
	end
end
indexTree("src")

local function pathProxy(path: string): any
	return setmetatable({ __path = path }, {
		__index = function(self, key)
			if key == "Parent" then
				return pathProxy((string.match(path, "^(.*)/[^/]+$")) or path)
			end
			local childPath = path .. "/" .. key
			if knownPaths[childPath] then
				return pathProxy(childPath)
			end
			error("No child '" .. tostring(key) .. "' under " .. path, 2)
		end,
	})
end

local Random = {}
Random.__index = Random
function Random.new(seed: number?)
	local state = seed or 1
	return setmetatable({ state = state }, Random)
end
function Random:NextNumber(min: number?, max: number?): number
	-- xorshift-ish LCG; deterministic is all we need
	self.state = (self.state * 1103515245 + 12345) % 2147483648
	local unit = self.state / 2147483648
	if min and max then
		return min + (max - min) * unit
	end
	return unit
end
function Random:NextInteger(min: number, max: number): number
	return math.floor(self:NextNumber(min, max + 1 - 1e-9))
end

local environment

local function requireModule(proxy: any): any
	local path = proxy.__path
	if moduleCache[path] ~= nil then
		return moduleCache[path]
	end
	local source = fs.readFile(path .. ".luau")
	-- Lune injects the standard globals into this table; metatables on it are
	-- ignored, so copy the Roblox datatypes in directly.
	local env = { script = proxy, require = requireModule }
	for key, value in environment do
		env[key] = value
	end
	local chunk = luau.load(source, { debugName = path, environment = env, injectGlobals = true })
	local result = chunk()
	moduleCache[path] = result
	return result
end

environment = {
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	Color3 = roblox.Color3,
	CFrame = roblox.CFrame,
	UDim2 = roblox.UDim2,
	UDim = roblox.UDim,
	Enum = roblox.Enum,
	Random = Random,
}

local shared = pathProxy("src/shared")
local function load(...: string): any
	local proxy = shared
	for _, part in { ... } do
		proxy = proxy[part]
	end
	return requireModule(proxy)
end

-- Tiny test framework -----------------------------------------------------------

local passed, failed = 0, 0
local currentGroup = ""

local function group(name: string)
	currentGroup = name
	print("\n== " .. name)
end

local function check(condition: any, message: string)
	if condition then
		passed += 1
	else
		failed += 1
		print("  FAIL [" .. currentGroup .. "] " .. message)
	end
end

local function eq(actual: any, expected: any, message: string)
	check(actual == expected, string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)))
end

local function near(actual: number, expected: number, tolerance: number, message: string)
	check(
		math.abs(actual - expected) <= tolerance,
		string.format("%s (expected ~%s, got %s)", message, tostring(expected), tostring(actual))
	)
end

-- Load modules -------------------------------------------------------------------

local EventConfig = load("Config", "EventConfig")
local FoodConfig = load("Config", "FoodConfig")
local GameConfig = load("Config", "GameConfig")
local PetConfig = load("Config", "PetConfig")
local RarityConfig = load("Config", "RarityConfig")
local RebirthConfig = load("Config", "RebirthConfig")
local RewardConfig = load("Config", "RewardConfig")
local SoundConfig = load("Config", "SoundConfig")
local UpgradeConfig = load("Config", "UpgradeConfig")
local ZoneConfig = load("Config", "ZoneConfig")
local Format = load("Util", "Format")
local WeightedRandom = load("Util", "WeightedRandom")
local Formulas = load("Formulas")
local MapLayout = load("MapLayout")

-- Format ---------------------------------------------------------------------------

group("Format")
eq(Format.Abbreviate(0), "0", "zero")
eq(Format.Abbreviate(999), "999", "below 1K")
eq(Format.Abbreviate(1000), "1K", "exactly 1K")
eq(Format.Abbreviate(1234), "1.23K", "1.23K")
eq(Format.Abbreviate(15600000), "15.6M", "15.6M")
eq(Format.Abbreviate(100000), "100K", "100K keeps its zeros")
eq(Format.Abbreviate(2500000000), "2.5B", "2.5B")
eq(Format.Abbreviate(-1500), "-1.5K", "negative")
eq(Format.Abbreviate(1.5), "1.5", "small decimal")
eq(Format.Cash(1999.9), "$1.99K", "cash floors")
eq(Format.Time(125), "2:05", "minutes")
eq(Format.Time(3725), "1:02:05", "hours")
eq(Format.Time(-5), "0:00", "negative time clamps")
eq(Format.Multiplier(1.5), "x1.5", "multiplier")
eq(Format.Multiplier(2), "x2", "whole multiplier")
eq(Format.Multiplier(1.234), "x1.23", "multiplier rounding")
eq(Format.Percent(0.5), "50%", "50%")
eq(Format.Percent(0.025), "2.5%", "2.5%")
eq(Format.Percent(0.0002), "0.02%", "tiny percent")
eq(Format.Percent(0), "0%", "zero percent")

-- WeightedRandom ----------------------------------------------------------------------

group("WeightedRandom")
do
	local entries = { { Id = "a", Weight = 75 }, { Id = "b", Weight = 25 }, { Id = "c", Weight = 0 } }
	local chances = WeightedRandom.Chances(entries)
	near(chances[1], 0.75, 1e-9, "chance a")
	near(chances[2], 0.25, 1e-9, "chance b")
	eq(chances[3], 0, "zero weight has zero chance")
	local counts = { a = 0, b = 0, c = 0 }
	local rng = Random.new(42)
	for _ = 1, 20000 do
		local pick = WeightedRandom.Pick(entries, rng)
		counts[pick.Id] += 1
	end
	near(counts.a / 20000, 0.75, 0.02, "pick distribution a")
	eq(counts.c, 0, "zero weight never picked")
	local boosted = WeightedRandom.Chances(entries, function(e)
		return if e.Id == "b" then e.Weight * 3 else e.Weight
	end)
	near(boosted[2], 0.5, 1e-9, "custom weight function")
end

-- Config integrity --------------------------------------------------------------------

group("Config: rarities")
local function validRarity(rarity: string, where: string)
	check(RarityConfig[rarity] ~= nil, where .. " uses unknown rarity " .. tostring(rarity))
end
for id, food in FoodConfig do
	eq(food.Id, id, "food key matches Id")
	validRarity(food.Rarity, "food " .. id)
	check(food.Value > 0, "food " .. id .. " has a positive value")
	check(food.Shape == "Ball" or food.Shape == "Block" or food.Shape == "Cylinder", "food " .. id .. " shape")
end
for id, pet in PetConfig.Pets do
	eq(pet.Id, id, "pet key matches Id")
	validRarity(pet.Rarity, "pet " .. id)
	check(pet.Multiplier >= 1, "pet " .. id .. " multiplier >= 1")
end
for _, title in RebirthConfig.Titles do
	validRarity(title.Rarity, "title " .. title.Id)
	check(title.Weight > 0, "title " .. title.Id .. " weight > 0")
	eq(RebirthConfig.TitlesById[title.Id], title, "title lookup " .. title.Id)
end

group("Config: zones")
do
	local directions = {}
	for index, zone in ZoneConfig.List do
		eq(zone.Order, index, "zone " .. zone.Id .. " order matches list position")
		eq(ZoneConfig.ById[zone.Id], zone, "zone lookup " .. zone.Id)
		if index > 1 then
			check(
				zone.Cost > ZoneConfig.List[index - 1].Cost,
				"zone " .. zone.Id .. " costs more than the previous one"
			)
		else
			eq(zone.Cost, 0, "starter zone is free")
		end
		local d = zone.Direction
		check(
			math.abs(d.Magnitude - 1) < 1e-6 and (d.X == 0 or d.Z == 0) and d.Y == 0,
			"zone " .. zone.Id .. " direction is a flat axis"
		)
		local key = tostring(d.X) .. "," .. tostring(d.Z)
		check(not directions[key], "zone " .. zone.Id .. " has its own side of the hub")
		directions[key] = true
		for _, entry in zone.Foods do
			local food = FoodConfig[entry.Id]
			check(food ~= nil, "zone " .. zone.Id .. " food " .. entry.Id .. " exists")
			check(food and not food.Golden, "zone " .. zone.Id .. " natural food isn't golden")
			check(entry.Weight > 0, "zone " .. zone.Id .. " food weight > 0")
		end
		check(
			FoodConfig[zone.GoldenFood] and FoodConfig[zone.GoldenFood].Golden,
			"zone " .. zone.Id .. " golden food exists and is golden"
		)
		check(FoodConfig[zone.MachineFood] ~= nil, "zone " .. zone.Id .. " machine food exists")
		local duck = zone.Duck
		check(duck.Count >= 1 and duck.ChaseSpeed > duck.PatrolSpeed, "zone " .. zone.Id .. " duck speeds")
		check(duck.FieldOfView > 0 and duck.FieldOfView <= 360, "zone " .. zone.Id .. " duck FOV")
		check(#zone.PropColors > 0, "zone " .. zone.Id .. " prop colors")
	end
	check(#ZoneConfig.List == 4, "map layout supports exactly 4 zones (one per hub side)")
end

group("Config: eggs")
for _, egg in PetConfig.Eggs do
	eq(PetConfig.EggsById[egg.Id], egg, "egg lookup " .. egg.Id)
	check(ZoneConfig.ById[egg.RequiredZone] ~= nil, "egg " .. egg.Id .. " required zone exists")
	check(egg.Cost > 0, "egg " .. egg.Id .. " cost")
	for _, entry in egg.Pets do
		check(PetConfig.Pets[entry.Id] ~= nil, "egg " .. egg.Id .. " pet " .. entry.Id .. " exists")
		check(entry.Weight > 0, "egg " .. egg.Id .. " pet weight > 0")
	end
end

group("Config: upgrades")
for _, upgrade in UpgradeConfig.List do
	eq(UpgradeConfig.ById[upgrade.Id], upgrade, "upgrade lookup " .. upgrade.Id)
	check(upgrade.MaxLevel > 0 and upgrade.CostGrowth > 1, "upgrade " .. upgrade.Id .. " growth")
	local last = 0
	for level = 0, upgrade.MaxLevel - 1 do
		local cost = Formulas.UpgradeCost(upgrade.Id, level)
		check(cost >= last and cost < 1e15, "upgrade " .. upgrade.Id .. " cost at level " .. level .. " is sane")
		last = cost
	end
end
for _, id in { "Capacity", "Speed", "Value", "Magnet", "ClickPower" } do
	check(UpgradeConfig.ById[id] ~= nil, "Formulas needs upgrade " .. id)
end
check(GameConfig.BaseWalkSpeed == UpgradeConfig.ById.Speed.Base, "base walk speed matches the Speed upgrade base")

group("Config: events & rewards")
for id, event in EventConfig.Events do
	eq(event.Id, id, "event key matches Id")
	check(event.Duration > 0, "event " .. id .. " duration")
end
check(
	EventConfig.Events.CapyFeast ~= nil and EventConfig.Events.CapyFeast.Weight == 0,
	"Capy Feast exists and isn't random"
)
check(EventConfig.IntervalMin <= EventConfig.IntervalMax, "event interval range")
local rewardTypes = { Cash = true, CashBoost = true, LuckBoost = true, Bundle = true }
for index, reward in RewardConfig.Daily do
	check(rewardTypes[reward.Type], "daily reward " .. index .. " type")
end
local lastMinutes = 0
for index, gift in RewardConfig.Playtime do
	check(rewardTypes[gift.Reward.Type], "playtime gift " .. index .. " type")
	check(gift.Minutes > lastMinutes, "playtime gifts are in increasing order")
	lastMinutes = gift.Minutes
end

group("Config: sounds")
for name, cue in SoundConfig.Cues do
	check(#cue.Layers > 0, "cue " .. name .. " has layers")
	for _, layer in cue.Layers do
		local ok = layer.Id == ""
			or string.match(layer.Id, "^rbxasset://sounds/") ~= nil
			or string.match(layer.Id, "^rbxassetid://%d+$") ~= nil
		check(ok, "cue " .. name .. " sound id format: " .. tostring(layer.Id))
		check(layer.Speed > 0 and layer.Volume >= 0, "cue " .. name .. " speed/volume")
	end
end
-- The built-in client sounds the defaults rely on (from the client manifest).
local builtIn = {
	"oof.ogg",
	"ouch.ogg",
	"impact_explosion_03.mp3",
	"impact_water.mp3",
	"action_jump.mp3",
	"action_jump_land.mp3",
	"action_get_up.mp3",
	"action_falling.ogg",
	"action_swim.mp3",
	"action_footsteps_plastic.mp3",
	"volume_slider.ogg",
}
for name, id in SoundConfig.Sounds do
	local file = string.match(id, "^rbxasset://sounds/(.+)$")
	if file then
		check(table.find(builtIn, file) ~= nil, "sound " .. name .. " is a known built-in client file")
	end
end

-- Formulas --------------------------------------------------------------------------------

group("Formulas")
do
	local data = {
		Cash = 0,
		Rebirths = 0,
		Upgrades = {},
		Zones = { Meadow = true },
		Pets = {},
		EquippedPets = {},
		Boosts = { Cash = 0, Luck = 0 },
		Daily = { LastClaimDay = 0, Streak = 0 },
	}
	eq(Formulas.CarryCapacity(data), 5, "base capacity")
	eq(Formulas.WalkSpeed(data), 16, "base speed")
	eq(Formulas.UpgradeCost("Capacity", 0), 25, "first capacity upgrade cost")
	data.Upgrades.Capacity = 3
	eq(Formulas.CarryCapacity(data), 11, "capacity after 3 levels")
	near(Formulas.CashMultiplier(data, 0), 1, 1e-9, "base cash multiplier")

	data.Pets = { P1 = "SmolCapy", P2 = "AuraAxolotl", P3 = "RemovedPet" }
	data.EquippedPets = { "P1", "P2", "P3", "P404" }
	near(Formulas.PetMultiplier(data), 1 + 0.1 + 0.6, 1e-9, "pet multiplier ignores missing pets")

	data.Rebirths = 2
	data.Upgrades.Value = 5
	local expected = (1 + 0.2 * 5) * (1 + 2 * 0.5) * 1.7
	near(Formulas.CashMultiplier(data, 0), expected, 1e-9, "stacked multiplier")
	data.Boosts.Cash = 1000
	near(Formulas.CashMultiplier(data, 999), expected * 2, 1e-9, "cash boost doubles")
	near(Formulas.CashMultiplier(data, 1000), expected, 1e-9, "cash boost expired at its end time")

	eq(Formulas.RebirthCost(0), RebirthConfig.BaseCost, "first rebirth cost")
	eq(Formulas.RebirthMultiplier(0), 1, "no-rebirth multiplier")

	-- Reward scaling uses the best unlocked zone and rebirths.
	data.Rebirths = 0
	data.Zones = { Meadow = true, Canyon = true }
	eq(Formulas.HighestZone(data).Id, "Canyon", "highest zone")
	eq(Formulas.RewardCash(data, 100), 100 * ZoneConfig.ById.Canyon.RewardScale, "reward cash scaling")

	-- Daily streak scenarios
	local day = 20000
	local t = day * 86400 + 3600
	data.Daily = { LastClaimDay = 0, Streak = 0 }
	local can, streak, index = Formulas.DailyStatus(data, t)
	check(can and streak == 1 and index == 1, "first ever claim is day 1")
	data.Daily = { LastClaimDay = day - 1, Streak = 3 }
	can, streak, index = Formulas.DailyStatus(data, t)
	check(can and streak == 4 and index == 4, "consecutive day continues the streak")
	data.Daily = { LastClaimDay = day - 2, Streak = 5 }
	can, streak = Formulas.DailyStatus(data, t)
	check(can and streak == 1, "missing a day resets the streak")
	data.Daily = { LastClaimDay = day, Streak = 2 }
	can, streak = Formulas.DailyStatus(data, t)
	check(not can and streak == 2, "can't claim twice in one day")
	data.Daily = { LastClaimDay = day - 1, Streak = 7 }
	can, streak, index = Formulas.DailyStatus(data, t)
	check(can and streak == 8 and index == 1, "streak wraps back to reward 1 after day 7")
end

-- Map geometry ------------------------------------------------------------------------------

group("MapLayout")
do
	local origin = roblox.Vector3.new(0, 0, 0)
	eq(MapLayout.ZoneAt(origin), nil, "hub center is not a zone")
	check(MapLayout.IsInHub(origin), "hub center is in the hub")
	check(MapLayout.IsInHub(MapLayout.SpawnPosition), "spawn is in the hub")
	check(MapLayout.IsInHub(MapLayout.EggArea) and MapLayout.IsInHub(MapLayout.ShopArea), "stalls are in the hub")
	local zoneBounds = {}
	for _, zone in ZoneConfig.List do
		local bounds = MapLayout.GetZoneBounds(zone.Id)
		table.insert(zoneBounds, bounds)
		eq(MapLayout.ZoneAt(bounds.Center), zone.Id, "zone center maps to " .. zone.Id)
		check(not MapLayout.IsInHub(bounds.Center), zone.Id .. " center is outside the hub")
		near(
			MapLayout.DepthInZone(zone.Id, MapLayout.GatePosition(zone.Id)),
			0,
			1e-6,
			zone.Id .. " gate sits on the hub edge"
		)
		near(MapLayout.DepthInZone(zone.Id, bounds.Center), MapLayout.ZoneDepth / 2, 1e-6, zone.Id .. " center depth")
		-- Snack machine spots (see MapBuilder) must be inside the zone.
		for _, spot in
			{
				{ MapLayout.ZoneDepth * 0.36, -MapLayout.ZoneHalfWidth + 14 },
				{ MapLayout.ZoneDepth * 0.74, MapLayout.ZoneHalfWidth - 14 },
			}
		do
			eq(
				MapLayout.ZoneAt(MapLayout.ZoneLocalToWorld(zone.Id, spot[1], spot[2])),
				zone.Id,
				zone.Id .. " machine spot inside zone"
			)
		end
		local clamped = MapLayout.ClampToZone(zone.Id, roblox.Vector3.new(9999, 0, -9999), 5)
		eq(MapLayout.ZoneAt(clamped), zone.Id, zone.Id .. " clamp stays inside")
		local rng = Random.new(7)
		for _ = 1, 50 do
			eq(
				MapLayout.ZoneAt(MapLayout.RandomPointInZone(zone.Id, rng, 8)),
				zone.Id,
				zone.Id .. " random point inside"
			)
		end
	end
	for i = 1, #zoneBounds do
		for j = i + 1, #zoneBounds do
			local a, b = zoneBounds[i], zoneBounds[j]
			local overlap = a.Min.X < b.Max.X and b.Min.X < a.Max.X and a.Min.Z < b.Max.Z and b.Min.Z < a.Max.Z
			check(not overlap, "zones " .. i .. " and " .. j .. " don't overlap")
		end
	end
	check(MapLayout.GateWidth < MapLayout.HubHalf, "gate fits in the hub wall")
end

-- Cross-file name checks ----------------------------------------------------------------------

local function readTree(dir: string, out: { [string]: string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			readTree(path, out)
		elseif string.match(name, "%.luau$") then
			out[path] = fs.readFile(path)
		end
	end
	return out
end
local sources = readTree("src", {})
local function allMatches(pattern: string, filter: string?): { [string]: string }
	local found = {}
	for path, source in sources do
		if not filter or string.find(path, filter, 1, true) then
			for capture in string.gmatch(source, pattern) do
				found[capture] = path
			end
		end
	end
	return found
end

group("Names: remotes")
do
	local netSource = fs.readFile("src/shared/Net.luau")
	local declared = {}
	for name in string.gmatch(netSource, '\n\t"(%w+)",') do
		declared[name] = true
	end
	check(declared.DataChanged and declared.GetData, "parsed the remote lists in Net.luau")
	for _, pattern in
		{
			'Net%.Fire%(%s*[%w%.]+,%s*"(%w+)"',
			'Net%.FireAll%(%s*"(%w+)"',
			'Net%.Event%(%s*"(%w+)"',
			'Net%.Function%(%s*"(%w+)"',
			'Net%.Handle%(%s*"(%w+)"',
			'Net%.Invoke%(%s*"(%w+)"',
			'invoke%(%s*"(%w+)"',
			'purchase%(%s*"(%w+)"',
			'claim%(%s*"(%w+)"',
		}
	do
		for name, path in allMatches(pattern) do
			check(declared[name], "remote '" .. name .. "' used in " .. path .. " is declared in Net.luau")
		end
	end
	check(next(allMatches('Net%.Invoke%(%s*"(%w+)"')) ~= nil, "found client remote calls")
	-- Every client->server function has a server handler.
	local handled = allMatches('Net%.Handle%(%s*"(%w+)"', "src/server")
	for name in string.gmatch(string.match(netSource, "local FUNCTIONS = (%b{})"), '"(%w+)"') do
		check(handled[name] ~= nil, "RemoteFunction '" .. name .. "' has a server handler")
	end
end

group("Names: effects")
do
	local fired = {}
	for name, path in allMatches('"Effect",%s*"(%w+)"', "src/server") do
		fired[name] = path
	end
	local effectsSource = fs.readFile("src/client/Controllers/EffectsController.luau")
	local handled = {}
	for name in string.gmatch(effectsSource, "handlers%.(%w+) = function") do
		handled[name] = true
	end
	for name in pairs(allMatches('EffectsController%.On%(%s*"(%w+)"', "src/client")) do
		handled[name] = true
	end
	check(fired.Caught and fired.Deliver and fired.Rebirth, "found the server's effect names")
	for name, path in fired do
		check(handled[name], "effect '" .. name .. "' fired in " .. path .. " has a client handler")
	end
end

group("Names: sound cues")
do
	local used = allMatches('SoundController%.Play%(%s*"(%w+)"')
	check(used.Deliver and used.Caught and used.UIClick, "found the sound cues used by the client")
end
for name, path in allMatches('SoundController%.Play%(%s*"(%w+)"') do
	check(SoundConfig.Cues[name] ~= nil, "sound cue '" .. name .. "' used in " .. path .. " exists")
end
for name, path in allMatches('Play%(if isBig then "(%w+)"') do
	check(SoundConfig.Cues[name] ~= nil, "sound cue '" .. name .. "' used in " .. path .. " exists")
end
for name, path in allMatches('else "(%w+)"%)') do
	if string.find(path, "HatchController", 1, true) then
		check(SoundConfig.Cues[name] ~= nil, "sound cue '" .. name .. "' used in " .. path .. " exists")
	end
end

group("Names: windows")
do
	local windows = allMatches('Components%.Window%(%s*"(%w+)"', "src/client")
	local hudSource = fs.readFile("src/client/Controllers/HUDController.luau")
	for name in string.gmatch(hudSource, 'Window = "(%w+)"') do
		check(windows[name] ~= nil, "menu button window '" .. name .. "' exists")
	end
	local mapSource = fs.readFile("src/server/Services/MapBuilder.luau")
	local stalls = 0
	for name in string.gmatch(mapSource, '\n\t\t"(%w+)",\n\t\tMapLayout%.') do
		stalls += 1
		check(windows[name] ~= nil, "stall window '" .. name .. "' exists")
	end
	eq(stalls, 2, "found both stall windows in MapBuilder")
end

group("Names: services")
do
	local main = fs.readFile("src/server/Main.server.luau")
	local listed = {}
	for name in string.gmatch(main, '\n\t"(%w+)",') do
		listed[name] = true
		check(fs.isFile("src/server/Services/" .. name .. ".luau"), "server service " .. name .. " exists")
	end
	for _, file in fs.readDir("src/server/Services") do
		local name = string.match(file, "^(%w+)%.luau$")
		if name and name ~= "MapBuilder" then
			check(listed[name], "server service " .. name .. " is started by Main")
		end
	end
	local clientMain = fs.readFile("src/client/Main.client.luau")
	local clientListed = { SoundController = true }
	for name in string.gmatch(clientMain, '\n\t"(%w+)",') do
		clientListed[name] = true
		check(fs.isFile("src/client/Controllers/" .. name .. ".luau"), "client controller " .. name .. " exists")
	end
	for _, file in fs.readDir("src/client/Controllers") do
		local name = string.match(file, "^(%w+)%.luau$")
		if name then
			check(clientListed[name], "client controller " .. name .. " is started by Main")
		end
	end
end

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
