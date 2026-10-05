-- Player save data. One DataStore key per player, guarded by a session lock so
-- two servers can never write the same player's data at once (prevents
-- duplication and rollback when players hop servers quickly).
--
-- In an unpublished Studio place (or with "Studio Access to API Services"
-- disabled) it falls back to temporary in-memory data and tells the player.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local LOCK_EXPIRY = 300 -- seconds; a lock older than this belongs to a dead server
local LOAD_ATTEMPTS = 6

local TEMPLATE = {
	Version = 1,
	Cash = 0,
	TotalCashEarned = 0,
	TotalFed = 0,
	Rebirths = 0,
	Upgrades = {}, -- [upgradeId] = level
	Zones = { [ZoneConfig.StarterZone] = true },
	Pets = {}, -- [uid] = petId
	EquippedPets = {}, -- { uid }
	NextPetUid = 1,
	Titles = {}, -- [titleId] = true
	EquippedTitle = "",
	Daily = { LastClaimDay = 0, Streak = 0 },
	Boosts = { Cash = 0, Luck = 0 }, -- unix time each boost ends
	Stats = { TimesCaught = 0, PetsHatched = 0, SnacksCollected = 0, PlaySeconds = 0 },
}

type Profile = {
	Data: any,
	Offline: boolean,
	Releasing: boolean,
}

local DataService = {}
DataService.Loaded = Signal.new() -- (player, data)
DataService.Changed = Signal.new() -- (player, key, value)
DataService.Releasing = Signal.new() -- (player, data) just before the final save

local profiles: { [Player]: Profile } = {}
local loadingThreads: { [Player]: { thread } } = {}
local store: DataStore? = nil
local offline = false

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = deepCopy(inner)
	end
	return copy
end

-- Adds any keys from the template that an older save is missing.
local function reconcile(target: { [any]: any }, template: { [any]: any })
	for key, value in template do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil then
			reconcile(target[key], value)
		end
	end
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function initStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end)
	if not ok then
		offline = true
		warn("[DataService] DataStores unavailable, using temporary data: " .. tostring(result))
		return
	end
	store = result
	if RunService:IsStudio() then
		local probeOk, probeError = pcall(function()
			return (store :: DataStore):GetAsync("__probe")
		end)
		if not probeOk then
			offline = true
			warn(
				"[DataService] DataStores unavailable in Studio, using temporary data. Publish the place and enable "
					.. "Game Settings > Security > 'Enable Studio Access to API Services' to test saving. ("
					.. tostring(probeError)
					.. ")"
			)
		end
	end
end

-- Returns the saved data, or nil + reason ("locked" | "error").
local function loadFromStore(player: Player): (any?, string?)
	local key = keyFor(player)
	local lastReason = "error"
	for attempt = 1, LOAD_ATTEMPTS do
		local lockedElsewhere = false
		local loaded = nil
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key, function(saved)
				saved = if type(saved) == "table" then saved else {}
				local lock = saved.Lock
				if
					type(lock) == "table"
					and lock.JobId ~= game.JobId
					and os.time() - (tonumber(lock.Time) or 0) < LOCK_EXPIRY
				then
					lockedElsewhere = true
					return nil -- cancel the write, someone else owns this session
				end
				lockedElsewhere = false
				saved.Lock = { JobId = game.JobId, Time = os.time() }
				loaded = saved.Data
				return saved
			end)
		end)
		if ok and not lockedElsewhere then
			return loaded or deepCopy(TEMPLATE), nil
		end
		lastReason = if lockedElsewhere then "locked" else "error"
		if not ok then
			warn(string.format("[DataService] Load attempt %d for %s failed: %s", attempt, player.Name, tostring(err)))
		end
		if player.Parent == nil then
			return nil, "left"
		end
		task.wait(math.min(2 ^ attempt, 10))
	end
	return nil, lastReason
end

local function saveToStore(player: Player, profile: Profile, release: boolean): boolean
	if profile.Offline or not store then
		return true
	end
	local lostLock = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(saved)
			saved = if type(saved) == "table" then saved else {}
			local lock = saved.Lock
			if type(lock) == "table" and lock.JobId ~= game.JobId then
				lostLock = true
				return nil -- another server took over; never overwrite its data
			end
			saved.Data = profile.Data
			saved.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
			return saved
		end)
	end)
	if not ok then
		warn(string.format("[DataService] Save failed for %s: %s", player.Name, tostring(err)))
		return false
	end
	if lostLock then
		warn(string.format("[DataService] %s's session lock was taken by another server; skipped save", player.Name))
	end
	return true
end

function DataService.IsOffline(): boolean
	return offline
end

function DataService.Get(player: Player): any?
	local profile = profiles[player]
	return profile and profile.Data
end

-- Yields until the player's data is loaded. Returns nil if they leave first.
function DataService.WaitFor(player: Player): any?
	local data = DataService.Get(player)
	if data then
		return data
	end
	if player.Parent == nil then
		return nil
	end
	local waiting = loadingThreads[player]
	if not waiting then
		waiting = {}
		loadingThreads[player] = waiting
	end
	table.insert(waiting, coroutine.running())
	return coroutine.yield()
end

local function resumeWaiting(player: Player, data: any?)
	local waiting = loadingThreads[player]
	loadingThreads[player] = nil
	if waiting then
		for _, thread in waiting do
			task.spawn(thread, data)
		end
	end
end

function DataService.Load(player: Player): any?
	local data, reason
	if offline then
		data = deepCopy(TEMPLATE)
	else
		data, reason = loadFromStore(player)
	end

	if player.Parent == nil then
		resumeWaiting(player, nil)
		return nil
	end
	if not data then
		resumeWaiting(player, nil)
		if reason == "locked" then
			player:Kick("Your data is still saving on another server. Please rejoin in a minute!")
		else
			player:Kick("Roblox couldn't load your data right now (your progress is safe). Please rejoin!")
		end
		return nil
	end

	reconcile(data, TEMPLATE)
	profiles[player] = { Data = data, Offline = offline, Releasing = false }
	resumeWaiting(player, data)
	DataService.Loaded:Fire(player, data)
	if offline then
		Net.Fire(player, "Notify", "Studio test mode: progress will NOT save.", "Info")
	end
	return data
end

-- Sends a top-level key to the client and fires Changed on the server.
function DataService.MarkChanged(player: Player, key: string)
	local data = DataService.Get(player)
	if not data then
		return
	end
	Net.Fire(player, "DataChanged", key, data[key])
	DataService.Changed:Fire(player, key, data[key])
end

function DataService.Set(player: Player, key: string, value: any)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data[key] = value
	DataService.MarkChanged(player, key)
end

function DataService.Increment(player: Player, key: string, amount: number)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data[key] = (data[key] or 0) + amount
	DataService.MarkChanged(player, key)
end

function DataService.AddCash(player: Player, amount: number)
	local data = DataService.Get(player)
	if not data or amount <= 0 then
		return
	end
	data.Cash += amount
	data.TotalCashEarned += amount
	DataService.MarkChanged(player, "Cash")
end

-- Returns true and deducts the cash if the player can afford it.
function DataService.SpendCash(player: Player, amount: number): boolean
	local data = DataService.Get(player)
	if not data or amount < 0 or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	DataService.MarkChanged(player, "Cash")
	return true
end

-- Adds to a counter inside data.Stats without replicating (stats are only
-- read when saving / by leaderboards).
function DataService.AddStat(player: Player, statName: string, amount: number)
	local data = DataService.Get(player)
	if data then
		data.Stats[statName] = (data.Stats[statName] or 0) + amount
	end
end

local function release(player: Player)
	local profile = profiles[player]
	if not profile or profile.Releasing then
		return
	end
	profile.Releasing = true
	DataService.Releasing:Fire(player, profile.Data)
	for attempt = 1, 3 do
		if saveToStore(player, profile, true) then
			break
		end
		task.wait(attempt)
	end
	profiles[player] = nil
end

function DataService.Start()
	initStore()

	Net.Handle("GetData", function(player)
		local data = DataService.WaitFor(player)
		return data ~= nil, if offline then "offline" else nil, data
	end, 2)

	Players.PlayerRemoving:Connect(function(player)
		resumeWaiting(player, nil)
		release(player)
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.AutoSaveInterval)
			for player, profile in profiles do
				if not profile.Releasing then
					task.spawn(saveToStore, player, profile, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		if offline then
			return
		end
		for player in profiles do
			task.spawn(release, player)
		end
		local deadline = os.clock() + 25
		while next(profiles) ~= nil and os.clock() < deadline do
			task.wait(0.25)
		end
	end)
end

return DataService
