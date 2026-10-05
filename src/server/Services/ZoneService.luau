-- Unlocking zones (gate prompts or the shop) and keeping players out of zones
-- they haven't unlocked. Gates are solid on the server; each client makes its
-- own unlocked gates walk-through (see client GateController).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneConfig = require(Shared.Config.ZoneConfig)
local Format = require(Shared.Util.Format)
local MapLayout = require(Shared.MapLayout)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local MapBuilder = require(script.Parent.MapBuilder)

local ZoneService = {}

local lastWarned: { [Player]: number } = {}

function ZoneService.Unlock(player: Player, zoneId: any): (boolean, string?)
	if type(zoneId) ~= "string" then
		return false, "Invalid zone"
	end
	local zone = ZoneConfig.ById[zoneId]
	local data = DataService.Get(player)
	if not zone or not data then
		return false, "Invalid zone"
	end
	if data.Zones[zoneId] then
		return false, "Already unlocked"
	end
	local previous = ZoneConfig.List[zone.Order - 1]
	if previous and not data.Zones[previous.Id] then
		return false, "Unlock " .. previous.Name .. " first!"
	end
	if not DataService.SpendCash(player, zone.Cost) then
		return false, "Need " .. Format.Cash(zone.Cost - data.Cash) .. " more"
	end
	data.Zones[zoneId] = true
	DataService.MarkChanged(player, "Zones")
	Net.Fire(player, "Effect", "ZoneUnlocked", { ZoneId = zoneId })
	return true, zone.Emoji .. " " .. zone.Name .. " unlocked!"
end

local function enforceTick()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not data or not root then
			continue
		end
		local zoneId = MapLayout.ZoneAt((root :: BasePart).Position)
		if zoneId and not data.Zones[zoneId] then
			local spawn = MapBuilder.Spawn
			if spawn then
				character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
			end
			if now - (lastWarned[player] or 0) > 3 then
				lastWarned[player] = now
				Net.Fire(player, "Notify", "🔒 That zone is locked! Unlock it at its gate.", "Bad")
			end
		end
	end
end

function ZoneService.Start()
	Net.Handle("UnlockZone", ZoneService.Unlock, 4)

	for _, gate in CollectionService:GetTagged("ZoneGate") do
		local prompt = gate:FindFirstChild("UnlockPrompt", true)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				local ok, message = ZoneService.Unlock(player, gate:GetAttribute("ZoneId"))
				Net.Fire(player, "Notify", message or "", if ok then "Good" else "Bad")
			end)
		end
	end

	task.spawn(function()
		while true do
			task.wait(1)
			enforceTick()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastWarned[player] = nil
	end)
end

return ZoneService
