--!strict
-- Every snack in the game. Zones decide where each one spawns (ZoneConfig).
-- Shape: "Ball" | "Block" | "Cylinder". Size is the pickup's size in studs.

export type Food = {
	Id: string,
	Name: string,
	Emoji: string,
	Value: number, -- cash per snack before multipliers
	Rarity: string,
	Color: Color3,
	Shape: string,
	Size: number,
	Golden: boolean?,
}

local FoodConfig: { [string]: Food } = {}

local function add(food: Food)
	assert(FoodConfig[food.Id] == nil, "Duplicate food id " .. food.Id)
	FoodConfig[food.Id] = food
end

-- Zone 1: Rizz Meadow
add({ Id = "SigmaSandwich", Name = "Soggy Sigma Sandwich", Emoji = "🥪", Value = 1, Rarity = "Common", Color = Color3.fromRGB(235, 200, 120), Shape = "Block", Size = 2.2 })
add({ Id = "MewingMelon", Name = "Mewing Melon", Emoji = "🍉", Value = 3, Rarity = "Uncommon", Color = Color3.fromRGB(90, 200, 90), Shape = "Ball", Size = 2.6 })
add({ Id = "OhioOnionRing", Name = "Ohio Onion Ring", Emoji = "🧅", Value = 8, Rarity = "Rare", Color = Color3.fromRGB(230, 170, 70), Shape = "Cylinder", Size = 2.4 })
add({ Id = "GoldenSandwich", Name = "GOLDEN Sigma Sandwich", Emoji = "🥪", Value = 40, Rarity = "Legendary", Color = Color3.fromRGB(255, 205, 40), Shape = "Block", Size = 2.8, Golden = true })

-- Zone 2: Cringe Canyon
add({ Id = "AuraApple", Name = "Aura Apple", Emoji = "🍎", Value = 15, Rarity = "Common", Color = Color3.fromRGB(220, 50, 50), Shape = "Ball", Size = 2.2 })
add({ Id = "NPCNoodles", Name = "NPC Noodles", Emoji = "🍜", Value = 40, Rarity = "Uncommon", Color = Color3.fromRGB(245, 225, 160), Shape = "Cylinder", Size = 2.6 })
add({ Id = "DeluluDonut", Name = "Delulu Donut", Emoji = "🍩", Value = 100, Rarity = "Rare", Color = Color3.fromRGB(255, 120, 190), Shape = "Cylinder", Size = 2.6 })
add({ Id = "GoldenDonut", Name = "GOLDEN Delulu Donut", Emoji = "🍩", Value = 500, Rarity = "Legendary", Color = Color3.fromRGB(255, 205, 40), Shape = "Cylinder", Size = 3, Golden = true })

-- Zone 3: Ohio Outskirts
add({ Id = "BussinBurrito", Name = "Bussin Burrito", Emoji = "🌯", Value = 250, Rarity = "Common", Color = Color3.fromRGB(210, 160, 90), Shape = "Cylinder", Size = 2.6 })
add({ Id = "GoofyGummy", Name = "Goofy Gummy", Emoji = "🍬", Value = 600, Rarity = "Uncommon", Color = Color3.fromRGB(120, 220, 255), Shape = "Ball", Size = 2.2 })
add({ Id = "SusSushi", Name = "Sus Sushi", Emoji = "🍣", Value = 1500, Rarity = "Rare", Color = Color3.fromRGB(255, 130, 90), Shape = "Block", Size = 2.4 })
add({ Id = "GoldenSushi", Name = "GOLDEN Sus Sushi", Emoji = "🍣", Value = 7500, Rarity = "Legendary", Color = Color3.fromRGB(255, 205, 40), Shape = "Block", Size = 3, Golden = true })

-- Zone 4: Brainrot Backrooms
add({ Id = "ChaosCroissant", Name = "Chaos Croissant", Emoji = "🥐", Value = 4000, Rarity = "Common", Color = Color3.fromRGB(225, 165, 80), Shape = "Ball", Size = 2.6 })
add({ Id = "VoidTaco", Name = "Void Taco", Emoji = "🌮", Value = 10000, Rarity = "Uncommon", Color = Color3.fromRGB(60, 30, 90), Shape = "Block", Size = 2.6 })
add({ Id = "MegaMeatball", Name = "Mythic Mega Meatball", Emoji = "🧆", Value = 25000, Rarity = "Rare", Color = Color3.fromRGB(140, 70, 40), Shape = "Ball", Size = 3 })
add({ Id = "GoldenMeatball", Name = "GOLDEN Mega Meatball", Emoji = "🧆", Value = 125000, Rarity = "Legendary", Color = Color3.fromRGB(255, 205, 40), Shape = "Ball", Size = 3.4, Golden = true })

return FoodConfig
