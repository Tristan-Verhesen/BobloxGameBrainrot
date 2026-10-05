--!strict
-- Pure game math shared by server (authoritative) and client (UI previews).
-- `data` is a player's saved profile (see server/Services/DataService).

local Config = script.Parent.Config
local PetConfig = require(Config.PetConfig)
local RebirthConfig = require(Config.RebirthConfig)
local RewardConfig = require(Config.RewardConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local ZoneConfig = require(Config.ZoneConfig)

local Formulas = {}

function Formulas.UpgradeLevel(data: any, upgradeId: string): number
	return (data.Upgrades and data.Upgrades[upgradeId]) or 0
end

function Formulas.UpgradeStat(upgradeId: string, level: number): number
	local upgrade = UpgradeConfig.ById[upgradeId]
	return upgrade.Base + upgrade.PerLevel * level
end

-- Cost to go from `level` to `level + 1`.
function Formulas.UpgradeCost(upgradeId: string, level: number): number
	local upgrade = UpgradeConfig.ById[upgradeId]
	return math.floor(upgrade.BaseCost * upgrade.CostGrowth ^ level)
end

function Formulas.Stat(data: any, upgradeId: string): number
	return Formulas.UpgradeStat(upgradeId, Formulas.UpgradeLevel(data, upgradeId))
end

function Formulas.CarryCapacity(data: any): number
	return math.floor(Formulas.Stat(data, "Capacity"))
end

function Formulas.WalkSpeed(data: any): number
	return Formulas.Stat(data, "Speed")
end

function Formulas.PickupRange(data: any): number
	return Formulas.Stat(data, "Magnet")
end

function Formulas.ClickPower(data: any): number
	return math.floor(Formulas.Stat(data, "ClickPower"))
end

function Formulas.ValueMultiplier(data: any): number
	return Formulas.Stat(data, "Value")
end

function Formulas.RebirthMultiplier(rebirths: number): number
	return 1 + rebirths * RebirthConfig.MultiplierPerRebirth
end

function Formulas.RebirthCost(rebirths: number): number
	return math.floor(RebirthConfig.BaseCost * RebirthConfig.CostGrowth ^ rebirths)
end

function Formulas.PetMultiplier(data: any): number
	local total = 1
	for _, uid in data.EquippedPets or {} do
		local petId = data.Pets[uid]
		local pet = petId and PetConfig.Pets[petId]
		if pet then
			total += pet.Multiplier - 1
		end
	end
	return total
end

function Formulas.IsBoostActive(data: any, boostName: string, now: number): boolean
	return (data.Boosts and (data.Boosts[boostName] or 0) or 0) > now
end

-- The player's personal cash multiplier. Server events (Double Cash etc.)
-- are applied on top of this by the server.
function Formulas.CashMultiplier(data: any, now: number): number
	local multiplier = Formulas.ValueMultiplier(data)
		* Formulas.RebirthMultiplier(data.Rebirths or 0)
		* Formulas.PetMultiplier(data)
	if Formulas.IsBoostActive(data, "Cash", now) then
		multiplier *= RewardConfig.CashBoostMultiplier
	end
	return multiplier
end

function Formulas.HighestZone(data: any): ZoneConfig.Zone
	local best = ZoneConfig.List[1]
	for _, zone in ZoneConfig.List do
		if data.Zones and data.Zones[zone.Id] and zone.Order > best.Order then
			best = zone
		end
	end
	return best
end

function Formulas.RewardCash(data: any, amount: number): number
	local scale = Formulas.HighestZone(data).RewardScale * Formulas.RebirthMultiplier(data.Rebirths or 0)
	return math.floor(amount * scale)
end

-- UTC day number, used for the daily streak.
function Formulas.DayNumber(unixTime: number): number
	return unixTime // 86400
end

-- Returns whether today's daily reward can be claimed, the streak the player
-- would have after claiming, and which reward (1-7) that is.
function Formulas.DailyStatus(data: any, unixTime: number): (boolean, number, number)
	local today = Formulas.DayNumber(unixTime)
	local daily = data.Daily or { LastClaimDay = 0, Streak = 0 }
	local canClaim = daily.LastClaimDay < today
	local streak
	if not canClaim then
		streak = daily.Streak
	elseif daily.LastClaimDay == today - 1 then
		streak = daily.Streak + 1
	else
		streak = 1
	end
	local rewardIndex = ((math.max(streak, 1) - 1) % #RewardConfig.Daily) + 1
	return canClaim, streak, rewardIndex
end

return Formulas
