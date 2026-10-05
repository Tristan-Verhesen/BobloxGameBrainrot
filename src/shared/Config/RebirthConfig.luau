--!strict
-- Rebirth resets Cash and Upgrades (zones and pets are kept) in exchange for a
-- permanent cash multiplier and one RNG roll on the title table below.
-- Legendary and Mythic titles also give your character an aura.

export type Title = {
	Id: string,
	Text: string,
	Rarity: string,
	Weight: number,
	Aura: boolean,
}

local RebirthConfig = {
	BaseCost = 100000,
	CostGrowth = 3,
	MultiplierPerRebirth = 0.5, -- x1 -> x1.5 -> x2 -> ...
}

RebirthConfig.Titles = {
	{ Id = "CertifiedSnacker", Text = "Certified Snacker", Rarity = "Common", Weight = 40, Aura = false },
	{ Id = "DuckDodger", Text = "Duck Dodger", Rarity = "Common", Weight = 30, Aura = false },
	{ Id = "CapyWhisperer", Text = "Capy Whisperer", Rarity = "Uncommon", Weight = 15, Aura = false },
	{ Id = "AuraFarmer", Text = "Aura Farmer", Rarity = "Uncommon", Weight = 8, Aura = false },
	{ Id = "SigmaFeeder", Text = "Sigma Feeder", Rarity = "Rare", Weight = 4, Aura = false },
	{ Id = "LordOfSnacks", Text = "Lord of Snacks", Rarity = "Epic", Weight = 2, Aura = false },
	{ Id = "BrainrotRoyalty", Text = "👑 Brainrot Royalty 👑", Rarity = "Legendary", Weight = 0.8, Aura = true },
	{ Id = "MainCharacter", Text = "✨ Main Character ✨", Rarity = "Mythic", Weight = 0.18, Aura = true },
	{ Id = "TheChosenCapy", Text = "🌌 THE CHOSEN CAPY 🌌", Rarity = "Mythic", Weight = 0.02, Aura = true },
} :: { Title }

RebirthConfig.TitlesById = {} :: { [string]: Title }
for _, title in RebirthConfig.Titles do
	RebirthConfig.TitlesById[title.Id] = title
end

return RebirthConfig
