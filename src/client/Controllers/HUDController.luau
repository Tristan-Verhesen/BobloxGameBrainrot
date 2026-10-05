-- The always-on HUD: cash, multiplier, carry bar, menu buttons (with PC
-- keybind hints), active events, the Capy Feast meter, current zone, boost
-- timers and toast notifications.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventConfig = require(Shared.Config.EventConfig)
local RewardConfig = require(Shared.Config.RewardConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Util.Format)
local MapLayout = require(Shared.MapLayout)
local Make = require(Shared.Util.Make)
local Net = require(Shared.Net)

local ClientData = require(script.Parent.Parent.ClientData)
local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)
local SoundController = require(script.Parent.SoundController)

local HUDController = {}

local player = Players.LocalPlayer

-- Menu buttons, in order. Keys are bound in InputController.
HUDController.Menu = {
	{ Window = "Shop", Emoji = "🛒", Label = "Shop", Key = Enum.KeyCode.B, Color = Color3.fromRGB(70, 180, 255) },
	{ Window = "Pets", Emoji = "🐾", Label = "Pets", Key = Enum.KeyCode.P, Color = Color3.fromRGB(120, 220, 120) },
	{
		Window = "Rebirth",
		Emoji = "🔁",
		Label = "Rebirth",
		Key = Enum.KeyCode.R,
		Color = Color3.fromRGB(255, 90, 160),
	},
	{
		Window = "Titles",
		Emoji = "🏷️",
		Label = "Titles",
		Key = Enum.KeyCode.T,
		Color = Color3.fromRGB(180, 120, 255),
	},
	{
		Window = "Rewards",
		Emoji = "🎁",
		Label = "Rewards",
		Key = Enum.KeyCode.G,
		Color = Color3.fromRGB(255, 190, 60),
	},
}

local cashLabel: TextLabel
local cashPanel: Frame
local multiplierLabel: TextLabel
local setCarry: (number) -> ()
local carryLabel: TextLabel
local carryFill: Frame
local zoneLabel: TextLabel
local boostsLabel: TextLabel
local eventsLabel: TextLabel
local setFeast: (number) -> ()
local feastLabel: TextLabel
local toastHolder: Frame
local rewardBadge: Frame
local displayedCash = 0
local toastCounter = 0

function HUDController.Toast(text: string, kind: string?)
	if text == "" then
		return
	end
	local color = if kind == "Good" then Theme.Good elseif kind == "Bad" then Theme.Bad else Theme.Info
	if kind == "Bad" then
		SoundController.Play("UIError", 0.2)
	else
		SoundController.Play("Notify", 0.1)
	end
	toastCounter += 1
	local toast = Make.Instance("Frame", {
		LayoutOrder = toastCounter,
		Size = UDim2.fromOffset(380, 46),
		BackgroundColor3 = Theme.Background,
		Parent = toastHolder,
	}, { Components.Corner(12), Components.Stroke(3, color) })
	Components.Label({
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Text = text,
		TextSize = 20,
		TextWrapped = true,
		TextColor3 = color,
		Parent = toast,
	})
	local scale = Make.Instance("UIScale", { Scale = 0.5, Parent = toast })
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(3.5, function()
		toast:Destroy()
	end)
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > 4 then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
end

-- Unix time synced with the server (the local clock can be wrong).
function HUDController.Now(): number
	return math.floor(workspace:GetServerTimeNow())
end

-- Whether anything on the Rewards window can be claimed right now.
function HUDController.RewardsClaimable(): boolean
	local data = ClientData.Data
	if not data then
		return false
	end
	if Formulas.DailyStatus(data, HUDController.Now()) then
		return true
	end
	local start = player:GetAttribute("SessionStart")
	if start then
		local elapsed = workspace:GetServerTimeNow() - start
		for index, gift in RewardConfig.Playtime do
			if not player:GetAttribute("GiftClaimed_" .. index) and elapsed >= gift.Minutes * 60 then
				return true
			end
		end
	end
	return false
end

-- Bottom-left, so it never sits under Roblox's chat window (top-left).
local function buildStats(screen: ScreenGui)
	local holder = Make.Instance("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(320, 200),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		Make.Instance("UIListLayout", {
			Padding = UDim.new(0, 6),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	cashPanel = Make.Instance("Frame", {
		Size = UDim2.fromOffset(320, 64),
		BackgroundColor3 = Theme.Background,
		LayoutOrder = 1,
		Parent = holder,
	}, { Components.Corner(16), Components.Stroke(4) })
	Make.Instance("UIScale", { Parent = cashPanel })
	Components.Label({ Size = UDim2.fromOffset(60, 64), Text = "💵", TextSize = 38, Parent = cashPanel })
	cashLabel = Components.Label({
		Position = UDim2.fromOffset(60, 0),
		Size = UDim2.new(1, -70, 1, 0),
		Text = "$0",
		TextSize = 40,
		TextColor3 = Theme.Good,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = cashPanel,
	})

	multiplierLabel = Components.Label({
		Size = UDim2.fromOffset(320, 26),
		Text = "",
		TextSize = 20,
		TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Parent = holder,
	})

	local bar, set, label = Components.ProgressBar({
		Size = UDim2.fromOffset(320, 38),
		Color = Theme.Accent,
		TextSize = 22,
		LayoutOrder = 3,
		Parent = holder,
	})
	setCarry = set
	carryLabel = label
	carryFill = bar:FindFirstChild("Fill") :: Frame

	if ClientData.Offline then
		Components.Label({
			Size = UDim2.fromOffset(320, 22),
			Text = "⚠ Studio test mode: progress is not saved",
			TextSize = 16,
			TextColor3 = Theme.Bad,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 4,
			Parent = holder,
		})
	end
end

local function buildMenu(screen: ScreenGui)
	local holder = Make.Instance("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(76, 400),
		BackgroundTransparency = 1,
		Parent = screen,
	}, { Make.Instance("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	for index, item in HUDController.Menu do
		local button = Components.Button({
			Text = "",
			Color = item.Color,
			Size = UDim2.fromOffset(72, 72),
			LayoutOrder = index,
			Parent = holder,
			OnClick = function()
				Components.ToggleWindow(item.Window)
			end,
		})
		Components.Label({
			Size = UDim2.new(1, 0, 0, 44),
			Position = UDim2.fromOffset(0, 3),
			Text = item.Emoji,
			TextSize = 34,
			Outline = false,
			Parent = button,
		})
		Components.Label({
			Size = UDim2.new(1, -4, 0, 20),
			Position = UDim2.new(0, 2, 1, -23),
			Text = item.Label .. " [" .. item.Key.Name .. "]",
			TextSize = 13,
			Parent = button,
		})
		if item.Window == "Rewards" then
			rewardBadge = Make.Instance("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -4, 0, 4),
				Size = UDim2.fromOffset(26, 26),
				BackgroundColor3 = Theme.Bad,
				Visible = false,
				Parent = button,
			}, { Components.Corner(13), Components.Stroke(2) })
			Components.Label({ Size = UDim2.fromScale(1, 1), Text = "!", TextSize = 20, Parent = rewardBadge })
		end
	end
end

local function buildTopCenter(screen: ScreenGui)
	local holder = Make.Instance("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(460, 110),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		Make.Instance("UIListLayout", {
			Padding = UDim.new(0, 4),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local _, set, label = Components.ProgressBar({
		Size = UDim2.fromOffset(420, 30),
		Color = Color3.fromRGB(255, 150, 40),
		TextSize = 18,
		LayoutOrder = 1,
		Parent = holder,
	})
	setFeast = set
	feastLabel = label
	eventsLabel = Components.Label({
		Size = UDim2.fromOffset(460, 60),
		Text = "",
		TextSize = 22,
		TextWrapped = true,
		LayoutOrder = 2,
		Parent = holder,
	})
end

local function buildBottom(screen: ScreenGui)
	zoneLabel = Components.Label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -46),
		Size = UDim2.fromOffset(600, 40),
		Text = "",
		TextSize = 32,
		Parent = screen,
	})
	boostsLabel = Components.Label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(600, 28),
		Text = "",
		TextSize = 20,
		TextColor3 = Theme.Accent,
		Parent = screen,
	})
	toastHolder = Make.Instance("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(380, 260),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		Make.Instance("UIListLayout", {
			Padding = UDim.new(0, 6),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local function refreshMultiplier()
	local data = ClientData.Data
	local multiplier = Formulas.CashMultiplier(data, HUDController.Now())
	local text = Format.Multiplier(multiplier) .. " cash"
	if data.Rebirths > 0 then
		text ..= "  ·  🔁 " .. data.Rebirths
	end
	multiplierLabel.Text = text
end

local function refreshCarry()
	local carry = player:GetAttribute("Carry") or 0
	local capacity = player:GetAttribute("CarryCapacity") or Formulas.CarryCapacity(ClientData.Data)
	setCarry(carry / math.max(capacity, 1))
	if carry >= capacity then
		carryLabel.Text = "🎒 FULL! " .. carry .. "/" .. capacity .. " · feed the capy!"
		carryFill.BackgroundColor3 = Theme.Bad
	else
		carryLabel.Text = "🎒 " .. carry .. " / " .. capacity
		carryFill.BackgroundColor3 = Theme.Accent
	end
end

local function pulseCash()
	local scale = cashPanel:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 1.12
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Things that tick: cash count-up, timers, zone label.
local function startTicking()
	local gameState = ReplicatedStorage:WaitForChild("GameState")
	RunService.RenderStepped:Connect(function(dt)
		local target = ClientData.Data.Cash
		if math.abs(target - displayedCash) < 1 then
			displayedCash = target
		else
			displayedCash += (target - displayedCash) * math.min(1, dt * 10)
		end
		cashLabel.Text = Format.Cash(displayedCash)
	end)

	task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()
			-- Active events
			local lines = {}
			for eventId, event in EventConfig.Events do
				local endsAt = gameState:GetAttribute("Event_" .. eventId) or 0
				if endsAt > now then
					table.insert(
						lines,
						Make.Colored(
							string.format("%s %s %s", event.Emoji, event.Name, Format.Time(endsAt - now)),
							event.Color
						)
					)
				end
			end
			eventsLabel.Text = table.concat(lines, "\n")

			-- Feast meter
			local fullness = gameState:GetAttribute("CapyFullness") or 0
			local fullnessMax = gameState:GetAttribute("CapyFullnessMax") or 1
			local feastEnds = gameState:GetAttribute("Event_CapyFeast") or 0
			if feastEnds > now then
				setFeast(1)
				feastLabel.Text = "🎉 CAPY FEAST · 2x CASH · " .. Format.Time(feastEnds - now)
			else
				setFeast(fullness / math.max(fullnessMax, 1))
				feastLabel.Text = string.format("🦫 Feast meter %d / %d", fullness, fullnessMax)
			end

			-- Boost timers
			local data = ClientData.Data
			local unix = HUDController.Now()
			local boosts = {}
			if Formulas.IsBoostActive(data, "Cash", unix) then
				table.insert(boosts, "💸 2x Cash " .. Format.Time(data.Boosts.Cash - unix))
			end
			if Formulas.IsBoostActive(data, "Luck", unix) then
				table.insert(boosts, "🍀 2x Luck " .. Format.Time(data.Boosts.Luck - unix))
			end
			boostsLabel.Text = table.concat(boosts, "    ")
			refreshMultiplier()

			rewardBadge.Visible = HUDController.RewardsClaimable()
			task.wait(0.5)
		end
	end)

	task.spawn(function()
		while true do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local zoneId = MapLayout.ZoneAt((root :: BasePart).Position)
				if zoneId then
					local zone = ZoneConfig.ById[zoneId]
					zoneLabel.Text = zone.Emoji .. " " .. zone.Name .. "  ·  🦆 DANGER"
					zoneLabel.TextColor3 = zone.FloorColor
				elseif MapLayout.IsInHub((root :: BasePart).Position) then
					zoneLabel.Text = "🏠 Capy Hub  ·  SAFE"
					zoneLabel.TextColor3 = Theme.Good
				end
			end
			task.wait(0.25)
		end
	end)
end

function HUDController.Start()
	local screen = Components.Screen()
	buildStats(screen)
	buildMenu(screen)
	buildTopCenter(screen)
	buildBottom(screen)

	ClientData.Observe({ "Upgrades", "Rebirths", "EquippedPets", "Pets", "Boosts" }, refreshMultiplier)
	displayedCash = ClientData.Data.Cash
	ClientData.Changed:Connect(function(key, value)
		if key == "Cash" and value > displayedCash then
			pulseCash()
		end
	end)
	refreshCarry()
	player:GetAttributeChangedSignal("Carry"):Connect(refreshCarry)
	player:GetAttributeChangedSignal("CarryCapacity"):Connect(refreshCarry)

	Net.Event("Notify").OnClientEvent:Connect(HUDController.Toast)
	startTicking()
end

return HUDController
