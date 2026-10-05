--!strict
-- Rarity tiers shared by food, pets and titles. `Lucky` tiers get boosted
-- weights while a Luck Boost is active.

export type Rarity = {
	Id: string,
	Name: string,
	Order: number,
	Color: Color3,
	Lucky: boolean,
	Announce: boolean, -- shout to the whole server when hatched
}

local RarityConfig: { [string]: Rarity } = {
	Common = {
		Id = "Common",
		Name = "Common",
		Order = 1,
		Color = Color3.fromRGB(190, 190, 190),
		Lucky = false,
		Announce = false,
	},
	Uncommon = {
		Id = "Uncommon",
		Name = "Uncommon",
		Order = 2,
		Color = Color3.fromRGB(85, 220, 95),
		Lucky = false,
		Announce = false,
	},
	Rare = {
		Id = "Rare",
		Name = "Rare",
		Order = 3,
		Color = Color3.fromRGB(70, 150, 255),
		Lucky = true,
		Announce = false,
	},
	Epic = {
		Id = "Epic",
		Name = "Epic",
		Order = 4,
		Color = Color3.fromRGB(180, 80, 255),
		Lucky = true,
		Announce = false,
	},
	Legendary = {
		Id = "Legendary",
		Name = "Legendary",
		Order = 5,
		Color = Color3.fromRGB(255, 185, 30),
		Lucky = true,
		Announce = true,
	},
	Mythic = {
		Id = "Mythic",
		Name = "BRAINROT MYTHIC",
		Order = 6,
		Color = Color3.fromRGB(255, 60, 140),
		Lucky = true,
		Announce = true,
	},
}

return RarityConfig
