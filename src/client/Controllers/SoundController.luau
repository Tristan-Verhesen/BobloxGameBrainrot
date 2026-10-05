-- Plays the layered sound cues from SoundConfig on the client.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundConfig = require(Shared.Config.SoundConfig)
local Make = require(Shared.Util.Make)

local SoundController = {}

local rng = Random.new()
local folder: Folder
local lastPlayed: { [string]: number } = {}

local function playLayer(layer: SoundConfig.Layer)
	if layer.Id == "" then
		return
	end
	local variance = layer.Variance or 0
	local sound = Make.Instance("Sound", {
		SoundId = layer.Id,
		Volume = layer.Volume,
		PlaybackSpeed = layer.Speed + rng:NextNumber(-variance, variance),
		Parent = folder,
	})
	sound:Play()
	Debris:AddItem(sound, 6)
end

-- Plays a cue. `minGap` stops spammy cues (pickups) from stacking up.
function SoundController.Play(cueName: string, minGap: number?)
	local cue = SoundConfig.Cues[cueName]
	if not cue then
		warn("[SoundController] Unknown cue " .. cueName)
		return
	end
	local now = os.clock()
	if minGap and now - (lastPlayed[cueName] or 0) < minGap then
		return
	end
	lastPlayed[cueName] = now
	for _, layer in cue.Layers do
		if layer.Delay and layer.Delay > 0 then
			task.delay(layer.Delay, playLayer, layer)
		else
			playLayer(layer)
		end
	end
end

function SoundController.Start()
	folder = Make.Instance("Folder", { Name = "CapySfx", Parent = SoundService })
	if SoundConfig.MusicId ~= "" then
		Make.Instance("Sound", {
			Name = "Music",
			SoundId = SoundConfig.MusicId,
			Volume = SoundConfig.MusicVolume,
			Looped = true,
			Parent = SoundService,
		}):Play()
	end
end

return SoundController
