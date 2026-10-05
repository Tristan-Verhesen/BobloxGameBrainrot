--!strict
-- General tuning. Most balance numbers live here or in the other Config files,
-- so you can rebalance without touching any system code.

local GameConfig = {
	GameTitle = "FEED THE GIANT CAPY",

	-- Movement / carrying base stats (upgrades add on top, see UpgradeConfig)
	BaseWalkSpeed = 16,

	-- Food
	ClickCooldown = 0.12, -- seconds between counted clicks on a snack machine
	MachineClickRange = 24, -- studs
	DroppedFoodLifetime = 25, -- seconds a dropped snack stays on the floor
	MaxDroppedPieces = 12, -- dropped loot is merged into at most this many pickups
	MaxCarryVisual = 10, -- snacks shown stacked on your back

	-- Getting caught
	RagdollDuration = 3,
	PostRagdollImmunity = 4, -- seconds the duck ignores you after getting up
	CatchFlingSpeed = 70,
	CatchFlingUp = 55,

	-- Capybara
	DeliveryRadius = 30, -- studs from the capy's center that count as "feeding"
	CapyFeastFoodBase = 200, -- snacks the server must feed to fill the meter...
	CapyFeastFoodPerPlayer = 60, -- ...plus this much per player in the server

	-- Pets
	MaxEquippedPets = 3,
	MaxPetInventory = 60,
	AnnounceRareHatchesInServer = true,

	-- Data
	AutoSaveInterval = 60,
	DataStoreName = "FeedTheGiantCapy_PlayerData_v1",
	LeaderboardRefresh = 90,
	LeaderboardSize = 10,
}

return GameConfig
