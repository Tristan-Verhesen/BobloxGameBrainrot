-- Shop window [B]: upgrades and zone unlocks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FoodConfig = require(Shared.Config.FoodConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Util.Format)
local Make = require(Shared.Util.Make)
local Net = require(Shared.Net)

local ClientData = require(script.Parent.Parent.ClientData)
local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)
local EffectsController = require(script.Parent.EffectsController)
local HUDController = require(script.Parent.HUDController)
local SoundController = require(script.Parent.SoundController)

local ShopWindow = {}

local function statText(upgrade: UpgradeConfig.Upgrade, level: number): string
	local value = Formulas.UpgradeStat(upgrade.Id, level)
	if upgrade.Id == "Value" then
		return Format.Multiplier(value) .. " cash"
	end
	return (string.gsub(string.format("%.1f", value), "%.0$", "")) .. upgrade.Unit
end

local function purchase(remote: string, id: string, button: TextButton)
	local ok, message = Net.Invoke(remote, id)
	if ok then
		SoundController.Play("Purchase")
		EffectsController.Shake(0.25, 0.15)
		local scale = button:FindFirstChildOfClass("UIScale")
		if scale then
			scale.Scale = 1.25
			TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		if message then
			HUDController.Toast(message, "Good")
		end
	else
		SoundController.Play("UIError")
		if message then
			HUDController.Toast(message, "Bad")
		end
	end
end

local function buildUpgrades(parent: Frame): () -> ()
	local list = Components.ScrollList({ Parent = parent })
	local rows = {}
	for index, upgrade in UpgradeConfig.List do
		local row = Components.Row(84, index, list)
		Components.Label({
			Size = UDim2.fromOffset(70, 84),
			Text = upgrade.Emoji,
			TextSize = 44,
			Outline = false,
			Parent = row,
		})
		Components.Label({
			Position = UDim2.fromOffset(74, 8),
			Size = UDim2.new(1, -260, 0, 30),
			Text = upgrade.Name,
			TextSize = 26,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local detail = Components.Label({
			Position = UDim2.fromOffset(74, 40),
			Size = UDim2.new(1, -260, 0, 36),
			Text = "",
			TextSize = 18,
			TextWrapped = true,
			TextColor3 = Theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = row,
		})
		local button
		button = Components.Button({
			Text = "",
			Size = UDim2.fromOffset(170, 56),
			Position = UDim2.new(1, -182, 0.5, -28),
			Parent = row,
			OnClick = function()
				purchase("BuyUpgrade", upgrade.Id, button)
			end,
		})
		rows[upgrade.Id] = { Detail = detail, Button = button }
	end

	return function()
		local data = ClientData.Data
		for _, upgrade in UpgradeConfig.List do
			local row = rows[upgrade.Id]
			local level = Formulas.UpgradeLevel(data, upgrade.Id)
			if level >= upgrade.MaxLevel then
				row.Detail.Text = string.format(
					"%s\nLv %d/%d · %s",
					upgrade.Description,
					level,
					upgrade.MaxLevel,
					statText(upgrade, level)
				)
				Components.SetButton(row.Button, "MAXED ✨", Theme.Disabled)
			else
				local cost = Formulas.UpgradeCost(upgrade.Id, level)
				row.Detail.Text = string.format(
					"%s\nLv %d/%d · %s → %s",
					upgrade.Description,
					level,
					upgrade.MaxLevel,
					statText(upgrade, level),
					Make.Colored(statText(upgrade, level + 1), Theme.Good)
				)
				Components.SetButton(
					row.Button,
					Format.Cash(cost),
					if data.Cash >= cost then Theme.Good else Theme.Disabled
				)
			end
		end
	end
end

local function valueRange(zone: ZoneConfig.Zone): string
	local low, high = math.huge, 0
	for _, entry in zone.Foods do
		local value = FoodConfig[entry.Id].Value
		low = math.min(low, value)
		high = math.max(high, value)
	end
	return Format.Cash(low) .. "–" .. Format.Cash(high)
end

local function buildZones(parent: Frame): () -> ()
	local list = Components.ScrollList({ Parent = parent })
	local rows = {}
	for index, zone in ZoneConfig.List do
		local row = Components.Row(96, index, list)
		Make.Instance("Frame", {
			Size = UDim2.new(0, 10, 1, -16),
			Position = UDim2.fromOffset(8, 8),
			BackgroundColor3 = zone.FloorColor,
			Parent = row,
		}, { Components.Corner(5) })
		Components.Label({
			Position = UDim2.fromOffset(18, 0),
			Size = UDim2.fromOffset(64, 96),
			Text = zone.Emoji,
			TextSize = 44,
			Outline = false,
			Parent = row,
		})
		Components.Label({
			Position = UDim2.fromOffset(86, 8),
			Size = UDim2.new(1, -280, 0, 30),
			Text = zone.Name,
			TextSize = 26,
			TextColor3 = zone.FloorColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local duck = zone.Duck
		Components.Label({
			Position = UDim2.fromOffset(86, 40),
			Size = UDim2.new(1, -280, 0, 50),
			Text = string.format(
				"Snacks worth %s each\n🦆 %d× %s · speed %d",
				valueRange(zone),
				duck.Count,
				duck.Name,
				duck.ChaseSpeed
			),
			TextSize = 18,
			TextWrapped = true,
			TextColor3 = Theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = row,
		})
		local button
		button = Components.Button({
			Text = "",
			Size = UDim2.fromOffset(180, 56),
			Position = UDim2.new(1, -192, 0.5, -28),
			Parent = row,
			OnClick = function()
				purchase("UnlockZone", zone.Id, button)
			end,
		})
		rows[zone.Id] = button
	end

	return function()
		local data = ClientData.Data
		for _, zone in ZoneConfig.List do
			local button = rows[zone.Id]
			local previous = ZoneConfig.List[zone.Order - 1]
			if data.Zones[zone.Id] then
				Components.SetButton(button, "UNLOCKED ✅", Theme.Disabled)
			elseif previous and not data.Zones[previous.Id] then
				Components.SetButton(button, "🔒 " .. previous.Name .. " first", Theme.Disabled)
			else
				Components.SetButton(
					button,
					"Unlock " .. Format.Cash(zone.Cost),
					if data.Cash >= zone.Cost then Theme.Good else Theme.Disabled
				)
			end
		end
	end
end

function ShopWindow.Start()
	local window = Components.Window("Shop", "🛒 SHOP", Vector2.new(760, 560), Color3.fromRGB(70, 160, 255))
	local tabsBar = Make.Instance("Frame", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Parent = window.Body,
	}, {
		Make.Instance("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local pages = {}
	local function page(name: string): Frame
		local frame = Make.Instance("Frame", {
			Name = name,
			Position = UDim2.fromOffset(0, 60),
			Size = UDim2.new(1, 0, 1, -60),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = window.Body,
		})
		pages[name] = frame
		return frame
	end
	local function show(name: string)
		for pageName, frame in pages do
			frame.Visible = pageName == name
		end
	end

	local refreshUpgrades = buildUpgrades(page("Upgrades"))
	local refreshZones = buildZones(page("Zones"))
	Components.Button({
		Text = "⚡ Upgrades",
		Color = Theme.Info,
		Size = UDim2.fromOffset(180, 46),
		LayoutOrder = 1,
		Parent = tabsBar,
		OnClick = function()
			show("Upgrades")
		end,
	})
	Components.Button({
		Text = "🗺️ Zones",
		Color = Theme.Pink,
		Size = UDim2.fromOffset(180, 46),
		LayoutOrder = 2,
		Parent = tabsBar,
		OnClick = function()
			show("Zones")
		end,
	})
	show("Upgrades")

	ClientData.Observe({ "Cash", "Upgrades", "Zones" }, function()
		if window.IsOpen() then
			refreshUpgrades()
			refreshZones()
		end
	end)
	window.Opened:Connect(function()
		refreshUpgrades()
		refreshZones()
	end)
end

return ShopWindow
