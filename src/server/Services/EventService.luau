-- Random server-wide events plus the Capy Feast. Active events are published
-- as attributes on ReplicatedStorage.GameState ("Event_<Id>" = server time the
-- event ends, 0 when inactive) so every client can show banners and timers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventConfig = require(Shared.Config.EventConfig)
local Make = require(Shared.Util.Make)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local WeightedRandom = require(Shared.Util.WeightedRandom)

local FoodService = require(script.Parent.FoodService)

local EventService = {}
EventService.Started = Signal.new() -- (eventId)
EventService.Ended = Signal.new() -- (eventId)

local gameState: Folder = Make.Instance("Folder", { Name = "GameState", Parent = ReplicatedStorage })
local active: { [string]: { EndsAt: number, Token: number } } = {}
local defaultGravity = workspace.Gravity
local tokenCounter = 0
local rng = Random.new()

function EventService.GetGameState(): Folder
	return gameState
end

function EventService.IsActive(eventId: string): boolean
	return active[eventId] ~= nil
end

local function product(field: string): number
	local total = 1
	for eventId in active do
		local value = (EventConfig.Events[eventId] :: any)[field]
		if value then
			total *= value
		end
	end
	return total
end

function EventService.GetCashMultiplier(): number
	return product("CashMultiplier")
end

function EventService.GetDuckSpeedMultiplier(): number
	return product("DuckSpeedMultiplier")
end

function EventService.GetDuckSightMultiplier(): number
	return product("DuckSightMultiplier")
end

local function applyGravity()
	local gravity = defaultGravity
	for eventId in active do
		local eventGravity = EventConfig.Events[eventId].Gravity
		if eventGravity then
			gravity = math.min(gravity, eventGravity)
		end
	end
	workspace.Gravity = gravity
end

function EventService.End(eventId: string)
	if not active[eventId] then
		return
	end
	active[eventId] = nil
	gameState:SetAttribute("Event_" .. eventId, 0)
	applyGravity()
	Net.FireAll("Effect", "EventEnd", { Id = eventId })
	EventService.Ended:Fire(eventId)
end

-- Starts (or extends) an event.
function EventService.Trigger(eventId: string, durationOverride: number?)
	local event = EventConfig.Events[eventId]
	assert(event, "Unknown event " .. tostring(eventId))
	local duration = durationOverride or event.Duration
	local endsAt = workspace:GetServerTimeNow() + duration
	local wasActive = active[eventId] ~= nil

	tokenCounter += 1
	local token = tokenCounter
	active[eventId] = { EndsAt = endsAt, Token = token }
	gameState:SetAttribute("Event_" .. eventId, endsAt)
	applyGravity()

	if not wasActive then
		if event.GoldenFoodPerZone then
			FoodService.SpawnGolden(event.GoldenFoodPerZone, duration + 15)
		end
		Net.FireAll("Effect", "EventStart", { Id = eventId })
		EventService.Started:Fire(eventId)
	end

	task.delay(duration, function()
		local current = active[eventId]
		if current and current.Token == token then
			EventService.End(eventId)
		end
	end)
end

local function randomEventLoop()
	local candidates = {}
	for _, event in EventConfig.Events do
		if event.Weight > 0 then
			table.insert(candidates, event)
		end
	end
	if #candidates == 0 then
		return
	end
	task.wait(EventConfig.FirstEventDelay)
	while true do
		local event = WeightedRandom.Pick(candidates, rng)
		EventService.Trigger(event.Id)
		task.wait(event.Duration)
		task.wait(rng:NextNumber(EventConfig.IntervalMin, EventConfig.IntervalMax))
	end
end

function EventService.Start()
	for eventId in EventConfig.Events do
		gameState:SetAttribute("Event_" .. eventId, 0)
	end
	task.spawn(randomEventLoop)
end

return EventService
