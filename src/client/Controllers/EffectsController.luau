-- All the "brainrot juice": screen shake, FOV punches, color flashes, giant
-- meme text, floating world popups, particle bursts, the red chase vignette,
-- the bonk kill feed and server announcements. Also handles the "Effect"
-- remote from the server.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventConfig = require(Shared.Config.EventConfig)
local FoodConfig = require(Shared.Config.FoodConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local Format = require(Shared.Util.Format)
local Make = require(Shared.Util.Make)
local Net = require(Shared.Net)

local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)
local SoundController = require(script.Parent.SoundController)

local EffectsController = {}

local player = Players.LocalPlayer
local rng = Random.new()
local camera = workspace.CurrentCamera

local shakeIntensity = 0
local shakeDecay = 0
local fovOffset = 0
local flashFrame: Frame
local vignette: { Frame } = {}
local killFeed: Frame
local bannerHolder: Frame

local BRAINROT_WORDS = {
	"BUSSIN",
	"SHEESH",
	"+AURA",
	"W FEED",
	"CHONKY",
	"SIGMA",
	"NO CAP",
	"CRONCHY",
	"OHIO MOMENT",
	"MEWING",
	"RIZZ'D",
	"CAPY APPROVED",
	"YUMMERS",
	"SLAY",
}

-- Screen shake ----------------------------------------------------------------

function EffectsController.Shake(intensity: number, duration: number)
	shakeIntensity = math.max(shakeIntensity, intensity)
	shakeDecay = math.max(shakeDecay, intensity / math.max(duration, 0.05))
end

function EffectsController.FovPunch(amount: number)
	fovOffset = math.max(fovOffset, amount)
end

local function startCameraEffects()
	local baseFov = camera.FieldOfView
	RunService:BindToRenderStep("CapyCameraFx", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if shakeIntensity > 0 then
			local i = shakeIntensity
			camera.CFrame *= CFrame.new(rng:NextNumber(-i, i) * 0.3, rng:NextNumber(-i, i) * 0.3, 0) * CFrame.Angles(
				0,
				0,
				math.rad(rng:NextNumber(-i, i) * 1.5)
			)
			shakeIntensity = math.max(0, shakeIntensity - shakeDecay * dt)
		end
		fovOffset = math.max(0, fovOffset - dt * 40)
		camera.FieldOfView = baseFov + fovOffset
	end)
end

-- Screen overlays -------------------------------------------------------------

function EffectsController.Flash(color: Color3, alpha: number?, duration: number?)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = 1 - (alpha or 0.5)
	TweenService:Create(flashFrame, TweenInfo.new(duration or 0.4), { BackgroundTransparency = 1 }):Play()
end

-- Giant slammed-in text in the middle of the screen.
function EffectsController.BigText(text: string, color: Color3?, duration: number?, yPosition: number?)
	local label = Components.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, yPosition or 0.32),
		Size = UDim2.fromOffset(900, 90),
		Text = text,
		TextSize = 64,
		TextColor3 = color or Theme.Accent,
		Outline = 4,
		Rotation = rng:NextNumber(-4, 4),
		Parent = Components.Overlay(),
	})
	local scale = Make.Instance("UIScale", { Scale = 2.2, Parent = label })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(duration or 1.6, function()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(scale, TweenInfo.new(0.3), { Scale = 0.6 }):Play()
		Debris:AddItem(label, 0.35)
	end)
end

-- A random meme word flying out from a random spot (delivery dopamine).
function EffectsController.BrainrotWord(color: Color3?)
	local label = Components.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(rng:NextNumber(0.25, 0.75), rng:NextNumber(0.25, 0.6)),
		Size = UDim2.fromOffset(400, 60),
		Text = BRAINROT_WORDS[rng:NextInteger(1, #BRAINROT_WORDS)] .. "!",
		TextSize = 46,
		TextColor3 = color or Color3.fromHSV(rng:NextNumber(), 0.7, 1),
		Outline = 3,
		Rotation = rng:NextNumber(-18, 18),
		Parent = Components.Overlay(),
	})
	local scale = Make.Instance("UIScale", { Scale = 0.2, Parent = label })
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1.1 }):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {
		Position = label.Position - UDim2.fromScale(0, 0.08),
		Rotation = label.Rotation + rng:NextNumber(-10, 10),
	}):Play()
	task.delay(0.6, function()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
	end)
	Debris:AddItem(label, 1)
end

-- Floating text at a world position ("+3 🥪", "+$1.2K").
function EffectsController.WorldPopup(position: Vector3, text: string, color: Color3?, size: number?)
	local anchor = Make.Part({
		Name = "Popup",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Position = position,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = workspace,
	})
	local gui, label = Make.Billboard(anchor, Vector2.new(8, 2.2) * (size or 1), Vector3.new(0, 1, 0), text, {
		TextColor3 = color or Theme.Accent,
	})
	gui.AlwaysOnTop = true
	TweenService:Create(gui, TweenInfo.new(1, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, 6, 0) }):Play()
	task.delay(0.6, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	Debris:AddItem(anchor, 1.1)
end

-- Particle burst at a world position.
function EffectsController.Burst(position: Vector3, color: Color3, count: number?)
	local anchor = Make.Part({
		Size = Vector3.new(0.2, 0.2, 0.2),
		Position = position,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = workspace,
	})
	local emitter = Make.Instance("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(color),
		LightEmission = 0.8,
		Rate = 0,
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(15, 35),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -40, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) }),
		Parent = anchor,
	})
	emitter:Emit(count or 25)
	Debris:AddItem(anchor, 1.5)
end

-- Chase vignette ---------------------------------------------------------------

local function buildVignette()
	local overlay = Components.Overlay()
	local edges = {
		{ Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.22), Rotation = 90 },
		{ Position = UDim2.fromScale(0, 0.78), Size = UDim2.fromScale(1, 0.22), Rotation = -90 },
		{ Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(0.18, 1), Rotation = 0 },
		{ Position = UDim2.fromScale(0.82, 0), Size = UDim2.fromScale(0.18, 1), Rotation = 180 },
	}
	for _, edge in edges do
		local frame = Make.Instance("Frame", {
			Position = edge.Position,
			Size = edge.Size,
			BackgroundColor3 = Color3.fromRGB(255, 0, 30),
			BorderSizePixel = 0,
			Visible = false,
			Parent = overlay,
		}, {
			Make.Instance("UIGradient", {
				Rotation = edge.Rotation,
				Transparency = NumberSequence.new(0.25, 1),
			}),
		})
		table.insert(vignette, frame)
	end
	local chaseText = Components.Label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.82),
		Size = UDim2.fromOffset(600, 40),
		Text = "",
		TextSize = 32,
		TextColor3 = Color3.fromRGB(255, 80, 80),
		Visible = false,
		Parent = overlay,
	})
	RunService.RenderStepped:Connect(function()
		local chasedBy = player:GetAttribute("ChasedBy")
		local visible = chasedBy ~= nil
		local pulse = 0.25 + math.abs(math.sin(os.clock() * 6)) * 0.35
		for _, frame in vignette do
			frame.Visible = visible
			frame.BackgroundTransparency = 1 - pulse
		end
		chaseText.Visible = visible
		if visible then
			chaseText.Text = "🦆 " .. string.upper(chasedBy) .. " IS CHASING YOU! RUN TO THE HUB!"
		end
	end)
end

-- Kill feed + announcements -------------------------------------------------------

local feedCounter = 0

function EffectsController.KillFeed(text: string)
	feedCounter += 1
	local entry = Make.Instance("Frame", {
		LayoutOrder = feedCounter,
		Size = UDim2.fromOffset(340, 34),
		BackgroundColor3 = Color3.fromRGB(30, 15, 25),
		BackgroundTransparency = 0.25,
		Parent = killFeed,
	}, { Components.Corner(8) })
	Components.Label({
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Text = text,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = entry,
	})
	task.delay(6, function()
		entry:Destroy()
	end)
	local frames = {}
	for _, child in killFeed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end
	if #frames > 5 then
		table.sort(frames, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		frames[1]:Destroy()
	end
end

function EffectsController.Banner(text: string, color: Color3, duration: number?)
	local banner = Make.Instance("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(820, 64),
		BackgroundColor3 = color,
		Parent = bannerHolder,
	}, { Components.Corner(16), Components.Stroke(4) })
	Components.Label({
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		Text = text,
		Scaled = true,
		Outline = 3,
		Parent = banner,
	})
	local scale = Make.Instance("UIScale", { Scale = 0, Parent = banner })
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(duration or 4, function()
		TweenService:Create(scale, TweenInfo.new(0.25), { Scale = 0 }):Play()
		Debris:AddItem(banner, 0.3)
	end)
end

-- Server effect events ----------------------------------------------------------

local handlers: { [string]: (any) -> () } = {}

handlers.Pickup = function(payload)
	local food = FoodConfig[payload.FoodId]
	SoundController.Play("Pickup", 0.04)
	EffectsController.WorldPopup(
		payload.Position,
		"+" .. payload.Count .. " " .. food.Emoji,
		if food.Golden then Theme.Accent else Theme.Text
	)
	if food.Golden then
		EffectsController.Burst(payload.Position, food.Color, 30)
		EffectsController.Shake(0.4, 0.2)
	end
	if payload.Full then
		SoundController.Play("CarryFull", 0.5)
		EffectsController.BigText("🎒 BACKPACK FULL! FEED THE CAPY!", Theme.Accent, 1.2, 0.7)
	end
end

handlers.MachineClick = function(payload)
	if payload.Count <= 0 then
		if payload.Full then
			SoundController.Play("CarryFull", 0.5)
			EffectsController.BigText("🎒 BACKPACK FULL!", Theme.Accent, 0.8, 0.7)
		end
		return
	end
	local food = FoodConfig[payload.FoodId]
	SoundController.Play("MachineClick", 0.03)
	EffectsController.WorldPopup(
		payload.Position + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)),
		"+" .. payload.Count .. " " .. food.Emoji
	)
	EffectsController.Shake(0.15, 0.1)
	if payload.Full then
		SoundController.Play("CarryFull", 0.5)
		EffectsController.BigText("🎒 BACKPACK FULL! FEED THE CAPY!", Theme.Accent, 1.2, 0.7)
	end
end

handlers.Deliver = function(payload)
	SoundController.Play("Deliver")
	EffectsController.WorldPopup(
		payload.Position + Vector3.new(0, 6, 0),
		"+" .. Format.Cash(payload.Cash),
		Theme.Good,
		2
	)
	EffectsController.Burst(payload.Position, Color3.fromRGB(255, 200, 90), math.clamp(payload.Count * 3, 15, 60))
	EffectsController.Shake(math.clamp(payload.Count / 15, 0.3, 1.2), 0.35)
	EffectsController.FovPunch(math.clamp(payload.Count / 2, 3, 12))
	for _ = 1, math.clamp(math.floor(payload.Count / 8) + 1, 1, 4) do
		EffectsController.BrainrotWord()
	end
end

handlers.DuckSpotted = function(payload)
	SoundController.Play("DuckSpotted")
	EffectsController.Shake(0.8, 0.5)
	EffectsController.Flash(Color3.fromRGB(255, 0, 0), 0.35, 0.5)
	EffectsController.BigText("🦆❗ " .. string.upper(payload.Duck) .. " SPOTTED YOU! RUN!!", Theme.Bad, 1.4)
end

handlers.DuckLost = function(payload)
	SoundController.Play("DuckLost")
	EffectsController.BigText("😅 You escaped " .. payload.Duck .. "!", Theme.Good, 1.2, 0.7)
end

handlers.Caught = function(payload)
	SoundController.Play("Caught")
	EffectsController.Shake(2, 0.9)
	EffectsController.FovPunch(25)
	EffectsController.Flash(Color3.fromRGB(255, 30, 30), 0.65, 0.8)
	EffectsController.BigText("💀 BONKED BY " .. string.upper(payload.Duck) .. " 💀", Theme.Bad, 2.2)
	task.delay(0.4, function()
		EffectsController.BigText("your snacks went flying 😭", Theme.SubText, 1.6, 0.42)
	end)
end

handlers.Bonk = function(payload)
	EffectsController.KillFeed(string.format("💀 %s got bonked by %s", payload.Player, payload.Duck))
	if payload.UserId ~= player.UserId then
		EffectsController.Burst(payload.Position, Color3.fromRGB(255, 220, 60), 20)
	end
end

handlers.EventStart = function(payload)
	local event = EventConfig.Events[payload.Id]
	SoundController.Play("EventStart")
	EffectsController.Shake(0.7, 0.6)
	EffectsController.Flash(event.Color, 0.45, 0.8)
	EffectsController.Banner(event.Emoji .. " " .. event.Name .. " " .. event.Emoji, event.Color, 4)
	EffectsController.BigText(event.Description, Theme.Text, 3, 0.4)
end

handlers.EventEnd = function(payload)
	local event = EventConfig.Events[payload.Id]
	SoundController.Play("Notify")
	EffectsController.KillFeed(event.Emoji .. " " .. event.Name .. " is over")
end

handlers.ZoneUnlocked = function(payload)
	local zone = ZoneConfig.ById[payload.ZoneId]
	SoundController.Play("Purchase")
	SoundController.Play("EventStart")
	EffectsController.Flash(zone.FloorColor, 0.5, 0.6)
	EffectsController.Shake(0.8, 0.5)
	EffectsController.BigText("🔓 " .. string.upper(zone.Name) .. " UNLOCKED!", zone.FloorColor, 2)
end

-- Rebirth reveals are handled by HatchController (it owns the reveal overlay).
local externalHandlers: { [string]: (any) -> () } = {}

function EffectsController.On(effectName: string, handler: (any) -> ())
	externalHandlers[effectName] = handler
end

function EffectsController.Start()
	local overlay = Components.Overlay()
	flashFrame = Make.Instance("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 50,
		Parent = overlay,
	})
	killFeed = Make.Instance("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0.36, 0),
		Size = UDim2.fromOffset(340, 230),
		BackgroundTransparency = 1,
		Parent = Components.Screen(),
	}, {
		Make.Instance("UIListLayout", {
			Padding = UDim.new(0, 4),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	bannerHolder = Make.Instance("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 130),
		Size = UDim2.fromOffset(820, 220),
		BackgroundTransparency = 1,
		Parent = overlay,
	}, {
		Make.Instance("UIListLayout", {
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	buildVignette()
	startCameraEffects()

	Net.Event("Effect").OnClientEvent:Connect(function(effectName, payload)
		local handler = handlers[effectName] or externalHandlers[effectName]
		if handler then
			handler(payload)
		end
	end)
	Net.Event("Announce").OnClientEvent:Connect(function(text, color)
		SoundController.Play("HatchRare")
		EffectsController.Banner("📢 " .. text, color, 5)
	end)
end

return EffectsController
