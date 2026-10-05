-- Daily login streak and per-session playtime gifts.
-- Playtime is measured from when the player's data loaded; the client reads
-- the "SessionStart" attribute (server time) to show countdowns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RewardConfig = require(Shared.Config.RewardConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)

local RewardService = {}

local sessionStart: { [Player]: number } = {}
local claimedGifts: { [Player]: { [number]: boolean } } = {}

local function extendBoost(data: any, boost: string, minutes: number)
	local now = os.time()
	data.Boosts[boost] = math.max(now, data.Boosts[boost] or 0) + minutes * 60
end

-- Grants a reward and returns a short description of it.
function RewardService.Grant(player: Player, reward: RewardConfig.Reward): string
	local data = DataService.Get(player)
	if not data then
		return ""
	end
	local parts = {}
	if (reward.Type == "Cash" or reward.Type == "Bundle") and reward.Amount then
		local cash = Formulas.RewardCash(data, reward.Amount)
		DataService.AddCash(player, cash)
		table.insert(parts, "💵 " .. Format.Cash(cash))
	end
	local cashMinutes = if reward.Type == "CashBoost" then reward.Minutes else reward.CashBoostMinutes
	if cashMinutes then
		extendBoost(data, "Cash", cashMinutes)
		table.insert(parts, string.format("💸 2x Cash (%d min)", cashMinutes))
	end
	local luckMinutes = if reward.Type == "LuckBoost" then reward.Minutes else reward.LuckBoostMinutes
	if luckMinutes then
		extendBoost(data, "Luck", luckMinutes)
		table.insert(parts, string.format("🍀 2x Luck (%d min)", luckMinutes))
	end
	if cashMinutes or luckMinutes then
		DataService.MarkChanged(player, "Boosts")
	end
	return table.concat(parts, " + ")
end

local function claimDaily(player: Player): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, nil
	end
	local now = os.time()
	local canClaim, streak, rewardIndex = Formulas.DailyStatus(data, now)
	if not canClaim then
		return false, "Already claimed today, come back tomorrow!"
	end
	data.Daily = { LastClaimDay = Formulas.DayNumber(now), Streak = streak }
	DataService.MarkChanged(player, "Daily")
	local description = RewardService.Grant(player, RewardConfig.Daily[rewardIndex])
	return true, string.format("🔥 Day %d streak! %s", streak, description)
end

local function claimPlaytime(player: Player, index: any): (boolean, string?)
	if type(index) ~= "number" then
		return false, nil
	end
	local gift = RewardConfig.Playtime[index]
	local start = sessionStart[player]
	if not gift or not start then
		return false, nil
	end
	local claimed = claimedGifts[player]
	if claimed[index] then
		return false, "Already claimed"
	end
	local elapsed = workspace:GetServerTimeNow() - start
	if elapsed < gift.Minutes * 60 then
		return false, "Not ready yet: " .. Format.Time(gift.Minutes * 60 - elapsed)
	end
	claimed[index] = true
	player:SetAttribute("GiftClaimed_" .. index, true)
	return true, "🎁 " .. RewardService.Grant(player, gift.Reward)
end

function RewardService.Start()
	Net.Handle("ClaimDaily", claimDaily, 2)
	Net.Handle("ClaimPlaytime", claimPlaytime, 4)

	DataService.Loaded:Connect(function(player)
		local now = workspace:GetServerTimeNow()
		sessionStart[player] = now
		claimedGifts[player] = {}
		player:SetAttribute("SessionStart", now)
	end)

	-- Track total play time for stats.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				DataService.AddStat(player, "PlaySeconds", 60)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		sessionStart[player] = nil
		claimedGifts[player] = nil
	end)
end

return RewardService
