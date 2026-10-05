-- In-server leaderstats plus global leaderboards (OrderedDataStores) on the
-- boards in the hub. Global boards need a published place with API access.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)
local Make = require(Shared.Util.Make)

local DataService = require(script.Parent.DataService)
local MapBuilder = require(script.Parent.MapBuilder)

local LeaderboardService = {}

local BOARDS = {
	{ Id = "TotalFed", Key = "TotalFed", Suffix = " 🍔" },
	{ Id = "Rebirths", Key = "Rebirths", Suffix = " 🔁" },
}

local stores: { [string]: OrderedDataStore } = {}
local nameCache: { [number]: string } = {}

local function setupLeaderstats(player: Player, data: any)
	local stats = Make.Instance("Folder", { Name = "leaderstats" })
	Make.Instance("StringValue", { Name = "Cash", Value = Format.Cash(data.Cash), Parent = stats })
	Make.Instance("IntValue", { Name = "Rebirths", Value = data.Rebirths, Parent = stats })
	stats.Parent = player
end

local function updateLeaderstat(player: Player, key: string, value: any)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	if key == "Cash" then
		(stats:FindFirstChild("Cash") :: StringValue).Value = Format.Cash(value)
	elseif key == "Rebirths" then
		(stats:FindFirstChild("Rebirths") :: IntValue).Value = value
	end
end

local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and name then name else "Player " .. userId
	nameCache[userId] = result
	return result
end

local function writeScores(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	for _, board in BOARDS do
		local store = stores[board.Id]
		if store then
			local value = math.floor(tonumber(data[board.Key]) or 0)
			if value > 0 then
				pcall(function()
					store:SetAsync(tostring(player.UserId), value)
				end)
			end
		end
	end
end

local function refreshBoards()
	for _, board in BOARDS do
		local gui = MapBuilder.Boards[board.Id]
		local store = stores[board.Id]
		if not gui then
			continue
		end
		if not store then
			gui.Status.Text = "Publish the game to enable global boards"
			continue
		end
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, GameConfig.LeaderboardSize)
		end)
		if not ok then
			gui.Status.Text = "Couldn't load (retrying soon)"
			continue
		end
		local entries = pages:GetCurrentPage()
		for index, row in gui.Rows do
			local entry = entries[index]
			if entry then
				local medal = if index == 1 then "🥇" elseif index == 2 then "🥈" elseif index == 3 then "🥉" else "#" .. index
				row.Text = string.format(
					"%s %s  %s",
					medal,
					nameOf(tonumber(entry.key) or 0),
					Make.Colored(Format.Abbreviate(entry.value) .. board.Suffix, Color3.fromRGB(255, 220, 90))
				)
			else
				row.Text = ""
			end
		end
		gui.Status.Text = "Global top " .. GameConfig.LeaderboardSize .. " · updates every " .. GameConfig.LeaderboardRefresh .. "s"
	end
end

function LeaderboardService.Start()
	if not DataService.IsOffline() then
		for _, board in BOARDS do
			local ok, store = pcall(function()
				return DataStoreService:GetOrderedDataStore("FeedTheGiantCapy_" .. board.Id .. "_v1")
			end)
			if ok then
				stores[board.Id] = store
			end
		end
	end

	DataService.Loaded:Connect(setupLeaderstats)
	DataService.Changed:Connect(updateLeaderstat)
	DataService.Releasing:Connect(function(player)
		writeScores(player)
	end)

	task.spawn(function()
		while true do
			refreshBoards()
			task.wait(GameConfig.LeaderboardRefresh)
			for _, player in Players:GetPlayers() do
				task.spawn(writeScores, player)
			end
		end
	end)
end

return LeaderboardService
