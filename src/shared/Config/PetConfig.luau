--!strict
-- Pets hatch from eggs in the hub. Each equipped pet adds (Multiplier - 1)
-- to your cash multiplier, so three x1.5 pets = x2.5 total.
-- Pets are drawn on each client as a colored blob with an emoji face.

export type Pet = {
	Id: string,
	Name: string,
	Emoji: string,
	Rarity: string,
	Multiplier: number,
	Color: Color3,
	Size: number,
}

export type Egg = {
	Id: string,
	Name: string,
	Emoji: string,
	Cost: number,
	RequiredZone: string,
	Color: Color3,
	Pets: { { Id: string, Weight: number } },
}

local PetConfig = {}

PetConfig.Pets = {} :: { [string]: Pet }

local function pet(definition: Pet)
	assert(PetConfig.Pets[definition.Id] == nil, "Duplicate pet id " .. definition.Id)
	PetConfig.Pets[definition.Id] = definition
end

-- Basic egg
pet({ Id = "SmolCapy", Name = "Smol Capy", Emoji = "🦫", Rarity = "Common", Multiplier = 1.1, Color = Color3.fromRGB(160, 110, 70), Size = 2 })
pet({ Id = "SigmaSnail", Name = "Sigma Snail", Emoji = "🐌", Rarity = "Common", Multiplier = 1.15, Color = Color3.fromRGB(200, 170, 120), Size = 2 })
pet({ Id = "MewingHamster", Name = "Mewing Hamster", Emoji = "🐹", Rarity = "Uncommon", Multiplier = 1.3, Color = Color3.fromRGB(240, 190, 130), Size = 2 })
pet({ Id = "AuraAxolotl", Name = "Aura Axolotl", Emoji = "🦎", Rarity = "Rare", Multiplier = 1.6, Color = Color3.fromRGB(255, 160, 200), Size = 2.2 })
pet({ Id = "GoofyGoose", Name = "Goofy Goose", Emoji = "🦢", Rarity = "Epic", Multiplier = 2.2, Color = Color3.fromRGB(245, 245, 245), Size = 2.4 })
pet({ Id = "RizzRaccoon", Name = "Rizz Raccoon", Emoji = "🦝", Rarity = "Legendary", Multiplier = 3.5, Color = Color3.fromRGB(120, 120, 130), Size = 2.6 })

-- Cursed egg
pet({ Id = "NPCPigeon", Name = "NPC Pigeon", Emoji = "🐦", Rarity = "Common", Multiplier = 1.5, Color = Color3.fromRGB(150, 150, 170), Size = 2 })
pet({ Id = "DeluluDog", Name = "Delulu Dog", Emoji = "🐶", Rarity = "Uncommon", Multiplier = 2, Color = Color3.fromRGB(220, 170, 100), Size = 2.2 })
pet({ Id = "OhioOpossum", Name = "Ohio Opossum", Emoji = "🐀", Rarity = "Rare", Multiplier = 3, Color = Color3.fromRGB(200, 200, 210), Size = 2.2 })
pet({ Id = "SusSeal", Name = "Sus Seal", Emoji = "🦭", Rarity = "Epic", Multiplier = 4.5, Color = Color3.fromRGB(110, 120, 140), Size = 2.4 })
pet({ Id = "BrainrotBunny", Name = "Brainrot Bunny", Emoji = "🐰", Rarity = "Legendary", Multiplier = 7, Color = Color3.fromRGB(255, 200, 230), Size = 2.6 })
pet({ Id = "QuackzillaJr", Name = "Quackzilla Jr.", Emoji = "🦆", Rarity = "Mythic", Multiplier = 15, Color = Color3.fromRGB(255, 220, 40), Size = 3 })

-- Mythic meme egg
pet({ Id = "DuckyDefector", Name = "Ducky Defector", Emoji = "🐤", Rarity = "Uncommon", Multiplier = 6, Color = Color3.fromRGB(255, 230, 90), Size = 2.2 })
pet({ Id = "GigachadGecko", Name = "Gigachad Gecko", Emoji = "🦖", Rarity = "Rare", Multiplier = 10, Color = Color3.fromRGB(90, 200, 110), Size = 2.6 })
pet({ Id = "ChaosChinchilla", Name = "Chaos Chinchilla", Emoji = "🐭", Rarity = "Epic", Multiplier = 18, Color = Color3.fromRGB(170, 170, 190), Size = 2.6 })
pet({ Id = "CapyOverlord", Name = "Capy Overlord", Emoji = "👑", Rarity = "Legendary", Multiplier = 35, Color = Color3.fromRGB(255, 190, 60), Size = 3 })
pet({ Id = "TheFinalBrainrot", Name = "The Final Brainrot", Emoji = "🧠", Rarity = "Mythic", Multiplier = 100, Color = Color3.fromRGB(255, 120, 180), Size = 3.4 })

PetConfig.Eggs = {
	{
		Id = "BasicEgg",
		Name = "Basic Brainrot Egg",
		Emoji = "🥚",
		Cost = 250,
		RequiredZone = "Meadow",
		Color = Color3.fromRGB(240, 235, 210),
		Pets = {
			{ Id = "SmolCapy", Weight = 45 },
			{ Id = "SigmaSnail", Weight = 30 },
			{ Id = "MewingHamster", Weight = 15 },
			{ Id = "AuraAxolotl", Weight = 7 },
			{ Id = "GoofyGoose", Weight = 2.5 },
			{ Id = "RizzRaccoon", Weight = 0.5 },
		},
	},
	{
		Id = "CursedEgg",
		Name = "Cursed Egg",
		Emoji = "🥚",
		Cost = 20000,
		RequiredZone = "Canyon",
		Color = Color3.fromRGB(120, 60, 160),
		Pets = {
			{ Id = "NPCPigeon", Weight = 45 },
			{ Id = "DeluluDog", Weight = 30 },
			{ Id = "OhioOpossum", Weight = 15 },
			{ Id = "SusSeal", Weight = 7 },
			{ Id = "BrainrotBunny", Weight = 2.7 },
			{ Id = "QuackzillaJr", Weight = 0.3 },
		},
	},
	{
		Id = "MythicEgg",
		Name = "Mythic Meme Egg",
		Emoji = "🥚",
		Cost = 1500000,
		RequiredZone = "Backrooms",
		Color = Color3.fromRGB(255, 80, 150),
		Pets = {
			{ Id = "DuckyDefector", Weight = 50 },
			{ Id = "GigachadGecko", Weight = 30 },
			{ Id = "ChaosChinchilla", Weight = 15 },
			{ Id = "CapyOverlord", Weight = 4.5 },
			{ Id = "TheFinalBrainrot", Weight = 0.5 },
		},
	},
} :: { Egg }

PetConfig.EggsById = {} :: { [string]: Egg }
for _, egg in PetConfig.Eggs do
	PetConfig.EggsById[egg.Id] = egg
end

-- Weight multiplier for Rare+ rarities while a Luck Boost is active.
PetConfig.LuckBoostMultiplier = 2

return PetConfig
