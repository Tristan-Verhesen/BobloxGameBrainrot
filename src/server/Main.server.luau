-- Server entry point. Builds the map, then starts every service in order.
-- Services only depend on services started before them.

local Services = script.Parent.Services

local MapBuilder = require(Services.MapBuilder)
MapBuilder.Build()

local order = {
	"DataService",
	"RagdollService",
	"FoodService",
	"EventService",
	"CapybaraService",
	"DuckService",
	"UpgradeService",
	"ZoneService",
	"PetService",
	"RebirthService",
	"RewardService",
	"LeaderboardService",
	"CharacterService", -- last: starts loading players and spawning characters
}

for _, name in order do
	local service = require(Services[name])
	local ok, err = pcall(service.Start)
	if not ok then
		warn(string.format("[Main] %s failed to start: %s", name, tostring(err)))
	end
end

print("[Main] Feed the Giant Capy server ready")
