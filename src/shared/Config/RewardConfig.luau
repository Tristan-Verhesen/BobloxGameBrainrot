--!strict
-- Daily login streak (7-day cycle, resets if you miss a day) and playtime gifts
-- (reset every session). Cash amounts are multiplied by your reward scale:
-- the RewardScale of your best unlocked zone times your rebirth multiplier.
--
-- Reward types:
--   { Type = "Cash", Amount = n }
--   { Type = "CashBoost", Minutes = n }  -- 2x cash
--   { Type = "LuckBoost", Minutes = n }  -- 2x odds for Rare+ pets and titles
--   { Type = "Bundle", Amount = n, CashBoostMinutes = n, LuckBoostMinutes = n }

export type Reward = {
	Type: string,
	Amount: number?,
	Minutes: number?,
	CashBoostMinutes: number?,
	LuckBoostMinutes: number?,
}

local RewardConfig = {}

RewardConfig.Daily = {
	{ Type = "Cash", Amount = 250 },
	{ Type = "Cash", Amount = 500 },
	{ Type = "CashBoost", Minutes = 10 },
	{ Type = "Cash", Amount = 1500 },
	{ Type = "LuckBoost", Minutes = 15 },
	{ Type = "Cash", Amount = 4000 },
	{ Type = "Bundle", Amount = 10000, CashBoostMinutes = 20, LuckBoostMinutes = 20 },
} :: { Reward }

RewardConfig.Playtime = {
	{ Minutes = 5, Reward = { Type = "Cash", Amount = 200 } :: Reward },
	{ Minutes = 10, Reward = { Type = "CashBoost", Minutes = 5 } :: Reward },
	{ Minutes = 20, Reward = { Type = "Cash", Amount = 1500 } :: Reward },
	{ Minutes = 40, Reward = { Type = "LuckBoost", Minutes = 10 } :: Reward },
	{
		Minutes = 60,
		Reward = { Type = "Bundle", Amount = 8000, CashBoostMinutes = 15, LuckBoostMinutes = 15 } :: Reward,
	},
}

RewardConfig.CashBoostMultiplier = 2

return RewardConfig
