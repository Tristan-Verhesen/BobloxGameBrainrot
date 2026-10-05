--!strict
-- Upgrade shop. Stat = Base + PerLevel * level. Cost = BaseCost * CostGrowth^level.
-- Upgrades reset on rebirth.

export type Upgrade = {
	Id: string,
	Name: string,
	Emoji: string,
	Description: string,
	Base: number,
	PerLevel: number,
	MaxLevel: number,
	BaseCost: number,
	CostGrowth: number,
	Unit: string, -- shown next to the stat in the shop
}

local UpgradeConfig = {}

UpgradeConfig.List = {
	{
		Id = "Capacity",
		Name = "Bigger Backpack",
		Emoji = "🎒",
		Description = "Carry more snacks per trip",
		Base = 5,
		PerLevel = 2,
		MaxLevel = 25,
		BaseCost = 25,
		CostGrowth = 1.55,
		Unit = " snacks",
	},
	{
		Id = "Speed",
		Name = "Zoomies",
		Emoji = "👟",
		Description = "Run faster (outrun the duck!)",
		Base = 16,
		PerLevel = 1,
		MaxLevel = 14,
		BaseCost = 40,
		CostGrowth = 1.65,
		Unit = " speed",
	},
	{
		Id = "Value",
		Name = "Snack Seasoning",
		Emoji = "🧂",
		Description = "Every snack is worth more",
		Base = 1,
		PerLevel = 0.2,
		MaxLevel = 50,
		BaseCost = 60,
		CostGrowth = 1.45,
		Unit = "x cash",
	},
	{
		Id = "Magnet",
		Name = "Snack Magnet",
		Emoji = "🧲",
		Description = "Grab snacks from further away",
		Base = 6,
		PerLevel = 1.5,
		MaxLevel = 12,
		BaseCost = 50,
		CostGrowth = 1.7,
		Unit = " studs",
	},
	{
		Id = "ClickPower",
		Name = "Turbo Fingers",
		Emoji = "👆",
		Description = "More snacks per snack-machine click",
		Base = 1,
		PerLevel = 1,
		MaxLevel = 9,
		BaseCost = 75,
		CostGrowth = 1.85,
		Unit = " per click",
	},
} :: { Upgrade }

UpgradeConfig.ById = {} :: { [string]: Upgrade }
for _, upgrade in UpgradeConfig.List do
	UpgradeConfig.ById[upgrade.Id] = upgrade
end

return UpgradeConfig
