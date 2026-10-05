-- Spawning. Players.CharacterAutoLoads is off (see default.project.json) so a
-- character only spawns once the map is built and the player's data has
-- loaded; this service also handles respawning after deaths.

local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)

local CharacterService = {}

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end
		humanoid.Died:Connect(function()
			task.wait(Players.RespawnTime)
			if player.Parent then
				player:LoadCharacterAsync()
			end
		end)
	end)

	local data = DataService.Load(player)
	if data and player.Parent then
		player:LoadCharacterAsync()
	end
end

function CharacterService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return CharacterService
