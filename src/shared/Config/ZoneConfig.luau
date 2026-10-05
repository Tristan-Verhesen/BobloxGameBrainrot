--!strict
-- The hub (where the Capybara lives) is always safe. Each zone sits on one side
-- of the hub, has its own snacks, snack machines and rubber duck(s).
-- Zones are listed in unlock order.

export type DuckStats = {
	Name: string,
	Count: number,
	Scale: number,
	PatrolSpeed: number,
	ChaseSpeed: number,
	SightRange: number,
	FieldOfView: number, -- degrees
	CatchRadius: number,
	GiveUpTime: number, -- seconds without line of sight before it stops chasing
	Color: Color3,
}

export type Zone = {
	Id: string,
	Name: string,
	Emoji: string,
	Order: number,
	Cost: number,
	Direction: Vector3, -- which side of the hub it's on
	FloorColor: Color3,
	WallColor: Color3,
	PropColors: { Color3 },
	Foods: { { Id: string, Weight: number } },
	GoldenFood: string,
	MachineFood: string,
	MachineName: string,
	SpawnCap: number, -- max snacks lying around at once
	SpawnInterval: number, -- seconds between spawns while under the cap
	ObstacleCount: number,
	RewardScale: number, -- scales daily/playtime cash rewards once unlocked
	Duck: DuckStats,
}

local ZoneConfig = {}

ZoneConfig.List = {
	{
		Id = "Meadow",
		Name = "Rizz Meadow",
		Emoji = "🌿",
		Order = 1,
		Cost = 0,
		Direction = Vector3.new(1, 0, 0),
		FloorColor = Color3.fromRGB(110, 190, 90),
		WallColor = Color3.fromRGB(70, 140, 60),
		PropColors = { Color3.fromRGB(255, 120, 120), Color3.fromRGB(255, 220, 90), Color3.fromRGB(120, 180, 255) },
		Foods = {
			{ Id = "SigmaSandwich", Weight = 70 },
			{ Id = "MewingMelon", Weight = 25 },
			{ Id = "OhioOnionRing", Weight = 5 },
		},
		GoldenFood = "GoldenSandwich",
		MachineFood = "SigmaSandwich",
		MachineName = "SANDWICH-O-MATIC",
		SpawnCap = 24,
		SpawnInterval = 1.2,
		ObstacleCount = 10,
		RewardScale = 1,
		Duck = {
			Name = "Quackzilla",
			Count = 1,
			Scale = 1,
			PatrolSpeed = 9,
			ChaseSpeed = 17,
			SightRange = 50,
			FieldOfView = 120,
			CatchRadius = 6,
			GiveUpTime = 3,
			Color = Color3.fromRGB(255, 220, 40),
		},
	},
	{
		Id = "Canyon",
		Name = "Cringe Canyon",
		Emoji = "🏜️",
		Order = 2,
		Cost = 500,
		Direction = Vector3.new(0, 0, 1),
		FloorColor = Color3.fromRGB(225, 170, 110),
		WallColor = Color3.fromRGB(180, 110, 70),
		PropColors = { Color3.fromRGB(200, 90, 60), Color3.fromRGB(240, 200, 140), Color3.fromRGB(120, 200, 200) },
		Foods = {
			{ Id = "AuraApple", Weight = 70 },
			{ Id = "NPCNoodles", Weight = 25 },
			{ Id = "DeluluDonut", Weight = 5 },
		},
		GoldenFood = "GoldenDonut",
		MachineFood = "AuraApple",
		MachineName = "APPLE ANNIHILATOR",
		SpawnCap = 24,
		SpawnInterval = 1.3,
		ObstacleCount = 12,
		RewardScale = 15,
		Duck = {
			Name = "Sir Squeaks-A-Lot",
			Count = 1,
			Scale = 1.15,
			PatrolSpeed = 10,
			ChaseSpeed = 19,
			SightRange = 55,
			FieldOfView = 130,
			CatchRadius = 6.5,
			GiveUpTime = 3.5,
			Color = Color3.fromRGB(255, 160, 40),
		},
	},
	{
		Id = "Ohio",
		Name = "Ohio Outskirts",
		Emoji = "🌽",
		Order = 3,
		Cost = 25000,
		Direction = Vector3.new(-1, 0, 0),
		FloorColor = Color3.fromRGB(150, 140, 160),
		WallColor = Color3.fromRGB(90, 80, 110),
		PropColors = { Color3.fromRGB(255, 230, 80), Color3.fromRGB(110, 230, 140), Color3.fromRGB(255, 110, 200) },
		Foods = {
			{ Id = "BussinBurrito", Weight = 70 },
			{ Id = "GoofyGummy", Weight = 25 },
			{ Id = "SusSushi", Weight = 5 },
		},
		GoldenFood = "GoldenSushi",
		MachineFood = "BussinBurrito",
		MachineName = "BURRITO BLASTER",
		SpawnCap = 26,
		SpawnInterval = 1.3,
		ObstacleCount = 14,
		RewardScale = 300,
		Duck = {
			Name = "The Quackening",
			Count = 2,
			Scale = 1.3,
			PatrolSpeed = 11,
			ChaseSpeed = 21,
			SightRange = 60,
			FieldOfView = 140,
			CatchRadius = 7,
			GiveUpTime = 4,
			Color = Color3.fromRGB(240, 240, 255),
		},
	},
	{
		Id = "Backrooms",
		Name = "Brainrot Backrooms",
		Emoji = "🌀",
		Order = 4,
		Cost = 1000000,
		Direction = Vector3.new(0, 0, -1),
		FloorColor = Color3.fromRGB(215, 200, 120),
		WallColor = Color3.fromRGB(190, 175, 95),
		PropColors = { Color3.fromRGB(230, 215, 140), Color3.fromRGB(80, 60, 120), Color3.fromRGB(255, 80, 80) },
		Foods = {
			{ Id = "ChaosCroissant", Weight = 70 },
			{ Id = "VoidTaco", Weight = 25 },
			{ Id = "MegaMeatball", Weight = 5 },
		},
		GoldenFood = "GoldenMeatball",
		MachineFood = "ChaosCroissant",
		MachineName = "CROISSANT CANNON",
		SpawnCap = 28,
		SpawnInterval = 1.4,
		ObstacleCount = 16,
		RewardScale = 6000,
		Duck = {
			Name = "Duckinator 9000",
			Count = 2,
			Scale = 1.5,
			PatrolSpeed = 12,
			ChaseSpeed = 23,
			SightRange = 65,
			FieldOfView = 150,
			CatchRadius = 7.5,
			GiveUpTime = 4.5,
			Color = Color3.fromRGB(60, 60, 60),
		},
	},
} :: { Zone }

ZoneConfig.ById = {} :: { [string]: Zone }
for _, zone in ZoneConfig.List do
	ZoneConfig.ById[zone.Id] = zone
end

ZoneConfig.StarterZone = ZoneConfig.List[1].Id

return ZoneConfig
