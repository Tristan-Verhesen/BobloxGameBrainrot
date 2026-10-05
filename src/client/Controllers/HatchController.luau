-- Full-screen reveals: egg hatches (shake, flash, pet pops out) and the
-- rebirth title roulette. Reveals queue up so fast hatches don't overlap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetConfig = require(Shared.Config.PetConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local RebirthConfig = require(Shared.Config.RebirthConfig)
local Format = require(Shared.Util.Format)
local Make = require(Shared.Util.Make)
local Net = require(Shared.Net)

local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)
local EffectsController = require(script.Parent.EffectsController)
local SoundController = require(script.Parent.SoundController)

local HatchController = {}

local queue: { () -> () } = {}
local running = false
local overlay: Frame
local rays: Frame
local bigLabel: TextLabel
local titleLabel: TextLabel
local subLabel: TextLabel
local skip = false

local function runQueue()
	if running then
		return
	end
	running = true
	while #queue > 0 do
		local reveal = table.remove(queue, 1)
		skip = false
		reveal()
	end
	running = false
end

local function enqueue(reveal: () -> ())
	table.insert(queue, reveal)
	task.spawn(runQueue)
end

-- Waits up to `seconds`, returning early if the player clicks to skip.
local function waitOrSkip(seconds: number)
	local deadline = os.clock() + seconds
	while os.clock() < deadline and not skip do
		task.wait()
	end
end

local function show()
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.35 }):Play()
	bigLabel.Rotation = 0
	titleLabel.Text = ""
	subLabel.Text = ""
	rays.Visible = false
end

local function hide()
	TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	task.wait(0.2)
	overlay.Visible = false
end

local function popIn(label: GuiObject)
	local scale = label:FindFirstChildOfClass("UIScale") or Make.Instance("UIScale", { Parent = label })
	scale.Scale = 0
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function hatchReveal(eggId: string, petId: string)
	local egg = PetConfig.EggsById[eggId]
	local pet = PetConfig.Pets[petId]
	local rarity = RarityConfig[pet.Rarity]
	local isBig = rarity.Order >= RarityConfig.Legendary.Order

	show()
	bigLabel.Text = egg.Emoji
	bigLabel.TextColor3 = egg.Color
	subLabel.Text = egg.Name
	popIn(bigLabel)

	-- Shake the egg harder and faster before it cracks.
	local shakes = if isBig then 9 else 6
	for index = 1, shakes do
		if skip then
			break
		end
		SoundController.Play("EggShake")
		local angle = (if index % 2 == 0 then 1 else -1) * (8 + index * 3)
		TweenService:Create(bigLabel, TweenInfo.new(0.09), { Rotation = angle }):Play()
		task.wait(math.max(0.07, 0.2 - index * 0.015))
	end
	bigLabel.Rotation = 0

	EffectsController.Flash(Color3.new(1, 1, 1), 0.9, 0.5)
	SoundController.Play(if isBig then "HatchRare" else "Hatch")
	EffectsController.Shake(if isBig then 1.5 else 0.5, 0.5)
	bigLabel.Text = pet.Emoji
	bigLabel.TextColor3 = Color3.new(1, 1, 1)
	popIn(bigLabel)
	rays.Visible = true
	rays.BackgroundColor3 = rarity.Color
	titleLabel.Text = pet.Name
	titleLabel.TextColor3 = rarity.Color
	popIn(titleLabel)
	subLabel.Text = Make.Colored(rarity.Name, rarity.Color) .. "  ·  " .. Format.Multiplier(pet.Multiplier) .. " cash"
	if isBig then
		EffectsController.BigText("🚨 " .. rarity.Name .. " PULL 🚨", rarity.Color, 2.5, 0.15)
	end
	waitOrSkip(if isBig then 3.2 else 2.2)
	hide()
end

local function rebirthReveal(payload: any)
	local title = RebirthConfig.TitlesById[payload.TitleId]
	local rarity = RarityConfig[title.Rarity]
	local isBig = rarity.Order >= RarityConfig.Legendary.Order

	show()
	SoundController.Play("Rebirth")
	EffectsController.Flash(Theme.Pink, 0.8, 0.8)
	EffectsController.Shake(1.6, 0.8)
	bigLabel.Text = "🔁"
	bigLabel.TextColor3 = Theme.Pink
	popIn(bigLabel)
	titleLabel.Text = "REBIRTH #" .. payload.Rebirths
	titleLabel.TextColor3 = Theme.Accent
	popIn(titleLabel)
	subLabel.Text = "Now earning " .. Make.Colored(Format.Multiplier(payload.Multiplier) .. " cash", Theme.Good)
	waitOrSkip(1.6)

	-- Title roulette: spin through random titles, slowing down, then land.
	local titles = RebirthConfig.Titles
	local delay = 0.04
	while delay < 0.32 and not skip do
		local random = titles[math.random(1, #titles)]
		titleLabel.Text = random.Text
		titleLabel.TextColor3 = RarityConfig[random.Rarity].Color
		SoundController.Play("EggShake")
		task.wait(delay)
		delay *= 1.18
	end
	SoundController.Play(if isBig then "HatchRare" else "Hatch")
	EffectsController.Flash(rarity.Color, 0.7, 0.5)
	rays.Visible = true
	rays.BackgroundColor3 = rarity.Color
	titleLabel.Text = title.Text
	titleLabel.TextColor3 = rarity.Color
	popIn(titleLabel)
	subLabel.Text = Make.Colored(rarity.Name .. " title", rarity.Color)
		.. (if payload.New then "  ·  NEW!" else "  ·  (duplicate)")
	waitOrSkip(if isBig then 3 else 2.2)
	hide()
end

function HatchController.Start()
	overlay = Make.Instance("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = Components.Overlay(),
	})
	rays = Make.Instance("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(520, 520),
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 0.2,
		Visible = false,
		ZIndex = 20,
		Parent = overlay,
	}, {
		Components.Corner(260),
		Make.Instance("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	task.spawn(function()
		while true do
			if rays.Visible then
				rays.Rotation = (rays.Rotation + 2) % 360
			end
			task.wait(1 / 30)
		end
	end)
	bigLabel = Components.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(300, 260),
		Text = "",
		TextSize = 200,
		Outline = false,
		ZIndex = 21,
		Parent = overlay,
	})
	titleLabel = Components.Label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.fromOffset(900, 70),
		Text = "",
		TextSize = 58,
		Outline = 4,
		ZIndex = 21,
		Parent = overlay,
	})
	subLabel = Components.Label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.73),
		Size = UDim2.fromOffset(900, 40),
		Text = "",
		TextSize = 30,
		ZIndex = 21,
		Parent = overlay,
	})
	Components.Label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(600, 30),
		Text = "click to skip",
		TextSize = 20,
		TextColor3 = Theme.SubText,
		ZIndex = 21,
		Parent = overlay,
	})

	UserInputService.InputBegan:Connect(function(input)
		if overlay.Visible and input.UserInputType == Enum.UserInputType.MouseButton1 then
			skip = true
		end
	end)

	Net.Event("HatchResult").OnClientEvent:Connect(function(eggId, petId)
		enqueue(function()
			hatchReveal(eggId, petId)
		end)
	end)
	EffectsController.On("Rebirth", function(payload)
		enqueue(function()
			rebirthReveal(payload)
		end)
	end)
end

return HatchController
