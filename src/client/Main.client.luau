-- Client entry point. Waits for the player's data, then starts every
-- controller in order.

local ClientData = require(script.Parent.ClientData)
local Controllers = script.Parent.Controllers

local SoundController = require(Controllers.SoundController)
SoundController.Start()

ClientData.Load()

local order = {
	"EffectsController",
	"HUDController",
	"ShopWindow",
	"PetsWindow",
	"RebirthWindow",
	"RewardsWindow",
	"HatchController",
	"PetFollowController",
	"RagdollController",
	"WorldController",
	"InputController",
}

for _, name in order do
	local controller = require(Controllers[name])
	local ok, err = pcall(controller.Start)
	if not ok then
		warn(string.format("[Client] %s failed to start: %s", name, tostring(err)))
	end
end
