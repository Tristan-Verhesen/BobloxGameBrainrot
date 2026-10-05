--!strict
-- Every sound cue in the game. Each cue is one or more layers played together,
-- which lets a few base sounds stack into louder, sillier "stings".
--
-- The defaults use sound files that ship inside the Roblox client
-- (rbxasset://sounds/...), so they always load, even in an unpublished place.
-- To use your own audio, replace an Id with "rbxassetid://<number>" from the
-- Creator Store or your own uploads. Set Id = "" to mute a layer.

export type Layer = {
	Id: string,
	Volume: number,
	Speed: number, -- PlaybackSpeed (also changes pitch)
	Variance: number?, -- random +/- added to Speed each play
	Delay: number?,
}

export type Cue = {
	Layers: { Layer },
}

local Sounds = {
	Oof = "rbxasset://sounds/oof.ogg",
	Ouch = "rbxasset://sounds/ouch.ogg",
	Explosion = "rbxasset://sounds/impact_explosion_03.mp3",
	Splash = "rbxasset://sounds/impact_water.mp3",
	Jump = "rbxasset://sounds/action_jump.mp3",
	Land = "rbxasset://sounds/action_jump_land.mp3",
	GetUp = "rbxasset://sounds/action_get_up.mp3",
	Falling = "rbxasset://sounds/action_falling.ogg",
	Swim = "rbxasset://sounds/action_swim.mp3",
	Footsteps = "rbxasset://sounds/action_footsteps_plastic.mp3",
	Tick = "rbxasset://sounds/volume_slider.ogg",
}

local SoundConfig = {
	Sounds = Sounds,
	-- Background music. None ships with the client; add an rbxassetid here.
	MusicId = "",
	MusicVolume = 0.25,
}

SoundConfig.Cues = {
	UIClick = { Layers = { { Id = Sounds.Tick, Volume = 0.6, Speed = 1.3, Variance = 0.05 } } },
	UIError = {
		Layers = { { Id = Sounds.Tick, Volume = 0.7, Speed = 0.5 }, { Id = Sounds.Oof, Volume = 0.25, Speed = 1.6 } },
	},
	Purchase = {
		Layers = {
			{ Id = Sounds.Tick, Volume = 0.7, Speed = 1.8 },
			{ Id = Sounds.Tick, Volume = 0.7, Speed = 2.4, Delay = 0.07 },
			{ Id = Sounds.Jump, Volume = 0.5, Speed = 1.4 },
		},
	},
	Pickup = { Layers = { { Id = Sounds.Tick, Volume = 0.55, Speed = 1.9, Variance = 0.25 } } },
	MachineClick = {
		Layers = {
			{ Id = Sounds.Tick, Volume = 0.5, Speed = 1.5, Variance = 0.2 },
			{ Id = Sounds.Land, Volume = 0.2, Speed = 1.8 },
		},
	},
	CarryFull = { Layers = { { Id = Sounds.Ouch, Volume = 0.35, Speed = 1.7 } } },
	Deliver = {
		Layers = {
			{ Id = Sounds.Splash, Volume = 0.6, Speed = 1.4, Variance = 0.1 },
			{ Id = Sounds.Land, Volume = 0.8, Speed = 0.6 },
			{ Id = Sounds.Tick, Volume = 0.6, Speed = 2.2, Delay = 0.1 },
			{ Id = Sounds.Tick, Volume = 0.6, Speed = 2.6, Delay = 0.18 },
		},
	},
	DuckSpotted = {
		Layers = {
			{ Id = Sounds.Ouch, Volume = 1, Speed = 2.3 },
			{ Id = Sounds.Ouch, Volume = 0.8, Speed = 2.6, Delay = 0.12 },
			{ Id = Sounds.Explosion, Volume = 0.35, Speed = 1.6 },
		},
	},
	DuckLost = { Layers = { { Id = Sounds.Swim, Volume = 0.5, Speed = 1.2 } } },
	Caught = {
		Layers = {
			{ Id = Sounds.Oof, Volume = 1, Speed = 1, Variance = 0.1 },
			{ Id = Sounds.Explosion, Volume = 0.6, Speed = 1.2 },
			{ Id = Sounds.Ouch, Volume = 0.9, Speed = 2.4, Delay = 0.05 },
			{ Id = Sounds.Falling, Volume = 0.4, Speed = 1.3 },
		},
	},
	GetUp = { Layers = { { Id = Sounds.GetUp, Volume = 0.8, Speed = 1 } } },
	EggShake = { Layers = { { Id = Sounds.Tick, Volume = 0.5, Speed = 0.9, Variance = 0.3 } } },
	Hatch = {
		Layers = {
			{ Id = Sounds.Explosion, Volume = 0.5, Speed = 1.5 },
			{ Id = Sounds.Jump, Volume = 0.6, Speed = 1.6 },
		},
	},
	HatchRare = {
		Layers = {
			{ Id = Sounds.Explosion, Volume = 0.9, Speed = 0.8 },
			{ Id = Sounds.Oof, Volume = 0.6, Speed = 0.5 },
			{ Id = Sounds.Jump, Volume = 0.7, Speed = 0.7, Delay = 0.15 },
		},
	},
	Rebirth = {
		Layers = {
			{ Id = Sounds.Explosion, Volume = 1, Speed = 0.55 },
			{ Id = Sounds.Jump, Volume = 0.8, Speed = 0.5 },
			{ Id = Sounds.Oof, Volume = 0.5, Speed = 0.4, Delay = 0.2 },
		},
	},
	EventStart = {
		Layers = {
			{ Id = Sounds.Explosion, Volume = 0.7, Speed = 0.7 },
			{ Id = Sounds.Ouch, Volume = 0.5, Speed = 2, Delay = 0.1 },
			{ Id = Sounds.Ouch, Volume = 0.5, Speed = 2.4, Delay = 0.25 },
		},
	},
	RewardClaim = {
		Layers = {
			{ Id = Sounds.Tick, Volume = 0.7, Speed = 1.6 },
			{ Id = Sounds.Tick, Volume = 0.7, Speed = 2, Delay = 0.08 },
			{ Id = Sounds.Tick, Volume = 0.7, Speed = 2.5, Delay = 0.16 },
			{ Id = Sounds.Jump, Volume = 0.5, Speed = 1.2 },
		},
	},
	Notify = { Layers = { { Id = Sounds.Tick, Volume = 0.5, Speed = 1.1 } } },
} :: { [string]: Cue }

-- 3D sounds attached to the ducks on the server (heard by everyone nearby).
SoundConfig.Duck = {
	Quack = { Id = Sounds.Oof, Volume = 1.6, Speed = 2.1 },
	Squeak = { Id = Sounds.Ouch, Volume = 2, Speed = 2.5 },
	Waddle = { Id = Sounds.Footsteps, Volume = 0.8, Speed = 0.55 },
	RollOffMaxDistance = 140,
}

-- 3D sounds on the Capybara.
SoundConfig.Capy = {
	Chomp = { Id = Sounds.Land, Volume = 2, Speed = 0.45 },
	Happy = { Id = Sounds.Jump, Volume = 1.5, Speed = 0.6 },
	RollOffMaxDistance = 200,
}

return SoundConfig
