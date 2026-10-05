--!strict
-- Random server-wide events. One random event runs at a time; the Capy Feast
-- is separate and starts whenever the server fills the Capybara's meter.

export type GameEvent = {
	Id: string,
	Name: string,
	Emoji: string,
	Description: string,
	Duration: number,
	Weight: number, -- chance of being picked by the random event timer (0 = never)
	Color: Color3,
	CashMultiplier: number?,
	DuckSpeedMultiplier: number?,
	DuckSightMultiplier: number?,
	Gravity: number?,
	GoldenFoodPerZone: number?,
}

local EventConfig = {
	FirstEventDelay = 90, -- seconds after the server starts
	IntervalMin = 150, -- seconds between the end of one event and the start of the next
	IntervalMax = 240,
}

EventConfig.Events = {
	GoldenRain = {
		Id = "GoldenRain",
		Name = "GOLDEN SNACK RAIN",
		Emoji = "✨",
		Description = "Golden snacks worth 5x are falling from the sky!",
		Duration = 30,
		Weight = 30,
		Color = Color3.fromRGB(255, 205, 40),
		GoldenFoodPerZone = 8,
	},
	DuckFrenzy = {
		Id = "DuckFrenzy",
		Name = "DUCK FRENZY",
		Emoji = "🦆",
		Description = "The ducks are FAST and ANGRY... but every snack pays 2x!",
		Duration = 40,
		Weight = 25,
		Color = Color3.fromRGB(255, 70, 70),
		CashMultiplier = 2,
		DuckSpeedMultiplier = 1.3,
		DuckSightMultiplier = 1.4,
	},
	DoubleCash = {
		Id = "DoubleCash",
		Name = "DOUBLE CASH",
		Emoji = "💸",
		Description = "Every delivery pays 2x!",
		Duration = 60,
		Weight = 25,
		Color = Color3.fromRGB(80, 230, 110),
		CashMultiplier = 2,
	},
	MoonMode = {
		Id = "MoonMode",
		Name = "MOON GRAVITY",
		Emoji = "🌙",
		Description = "Gravity is broken. Getting bonked sends you FLYING.",
		Duration = 40,
		Weight = 20,
		Color = Color3.fromRGB(150, 160, 255),
		Gravity = 55,
	},
	CapyFeast = {
		Id = "CapyFeast",
		Name = "CAPY FEAST",
		Emoji = "🦫",
		Description = "The Capybara is HAPPY! Everyone gets 2x cash!",
		Duration = 45,
		Weight = 0,
		Color = Color3.fromRGB(255, 150, 60),
		CashMultiplier = 2,
	},
} :: { [string]: GameEvent }

return EventConfig
