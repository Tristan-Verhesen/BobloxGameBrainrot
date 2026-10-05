-- Rewards window [G]: 7-day login streak and this session's playtime gifts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RewardConfig = require(Shared.Config.RewardConfig)
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

local RewardsWindow = {}

local player = Players.LocalPlayer

-- Short text for a reward, with cash scaled for this player.
local function describe(reward: RewardConfig.Reward, data: any): string
	local parts = {}
	if reward.Amount then
		table.insert(parts, "💵 " .. Format.Cash(Formulas.RewardCash(data, reward.Amount)))
	end
	local cashMinutes = if reward.Type == "CashBoost" then reward.Minutes else reward.CashBoostMinutes
	if cashMinutes then
		table.insert(parts, "💸 2x Cash " .. cashMinutes .. "m")
	end
	local luckMinutes = if reward.Type == "LuckBoost" then reward.Minutes else reward.LuckBoostMinutes
	if luckMinutes then
		table.insert(parts, "🍀 2x Luck " .. luckMinutes .. "m")
	end
	return table.concat(parts, "\n")
end

local function claim(remote: string, ...: any)
	local ok, message = Net.Invoke(remote, ...)
	if ok then
		SoundController.Play("RewardClaim")
		EffectsController.Flash(Theme.Accent, 0.35, 0.4)
		EffectsController.BigText(message or "🎁 Claimed!", Theme.Accent, 2)
	else
		SoundController.Play("UIError")
		if message then
			HUDController.Toast(message, "Bad")
		end
	end
end

function RewardsWindow.Start()
	local window = Components.Window("Rewards", "🎁 REWARDS", Vector2.new(820, 600), Color3.fromRGB(255, 170, 50))
	local body = window.Body

	-- Daily streak
	local streakLabel = Components.Label({
		Size = UDim2.new(1, 0, 0, 34),
		Text = "",
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = body,
	})
	local dayRow = Make.Instance("Frame", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		Make.Instance("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local dayTiles = {}
	for index in RewardConfig.Daily do
		local tile = Make.Instance("Frame", {
			Size = UDim2.fromOffset(102, 120),
			BackgroundColor3 = Theme.Panel,
			LayoutOrder = index,
			Parent = dayRow,
		}, { Components.Corner(12), Components.Stroke(3) })
		Components.Label({ Size = UDim2.new(1, 0, 0, 28), Text = "Day " .. index, TextSize = 20, Parent = tile })
		local text = Components.Label({
			Position = UDim2.fromOffset(4, 30),
			Size = UDim2.new(1, -8, 1, -34),
			Text = "",
			TextSize = 15,
			TextWrapped = true,
			Parent = tile,
		})
		dayTiles[index] = { Tile = tile, Text = text }
	end
	local dailyButton = Components.Button({
		Text = "",
		Size = UDim2.fromOffset(320, 54),
		Position = UDim2.fromOffset(0, 170),
		TextSize = 24,
		Parent = body,
		OnClick = function()
			claim("ClaimDaily")
		end,
	})

	-- Playtime gifts
	Components.Label({
		Position = UDim2.fromOffset(0, 236),
		Size = UDim2.new(1, 0, 0, 32),
		Text = "⏱️ Playtime gifts (reset every session)",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = body,
	})
	local giftList = Components.ScrollList({
		Position = UDim2.fromOffset(0, 272),
		Size = UDim2.new(1, 0, 1, -272),
		Gap = 6,
		Parent = body,
	})
	local giftRows = {}
	for index, gift in RewardConfig.Playtime do
		local row = Components.Row(56, index, giftList)
		local label = Components.Label({
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -220, 1, 0),
			Text = "",
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local button = Components.Button({
			Text = "",
			Size = UDim2.fromOffset(180, 44),
			Position = UDim2.new(1, -192, 0.5, -22),
			Parent = row,
			OnClick = function()
				claim("ClaimPlaytime", index)
			end,
		})
		giftRows[index] = { Label = label, Button = button, Gift = gift }
	end

	local function refresh()
		local data = ClientData.Data
		local canClaim, streak, rewardIndex = Formulas.DailyStatus(data, HUDController.Now())
		streakLabel.Text =
			string.format("🔥 Login streak: %d day%s", data.Daily.Streak, if data.Daily.Streak == 1 then "" else "s")
		for index, tile in dayTiles do
			tile.Text.Text = describe(RewardConfig.Daily[index], data)
			local stroke = tile.Tile:FindFirstChildOfClass("UIStroke") :: UIStroke
			if index == rewardIndex then
				tile.Tile.BackgroundColor3 = if canClaim then Theme.Good else Theme.PanelLight
				stroke.Color = Theme.Accent
			else
				tile.Tile.BackgroundColor3 = Theme.Panel
				stroke.Color = Theme.Stroke
			end
		end
		if canClaim then
			Components.SetButton(dailyButton, "🎁 Claim Day " .. streak .. "!", Theme.Good)
		else
			local nextDay = (Formulas.DayNumber(HUDController.Now()) + 1) * 86400
			Components.SetButton(dailyButton, "Next in " .. Format.Time(nextDay - HUDController.Now()), Theme.Disabled)
		end

		local start = player:GetAttribute("SessionStart") or workspace:GetServerTimeNow()
		local elapsed = workspace:GetServerTimeNow() - start
		for index, row in giftRows do
			row.Label.Text = string.format(
				"%d min · %s",
				row.Gift.Minutes,
				(string.gsub(describe(row.Gift.Reward, data), "\n", " + "))
			)
			if player:GetAttribute("GiftClaimed_" .. index) then
				Components.SetButton(row.Button, "Claimed ✅", Theme.Disabled)
			elseif elapsed >= row.Gift.Minutes * 60 then
				Components.SetButton(row.Button, "🎁 CLAIM!", Theme.Good)
			else
				Components.SetButton(row.Button, Format.Time(row.Gift.Minutes * 60 - elapsed), Theme.Disabled)
			end
		end
	end

	window.Opened:Connect(function()
		refresh()
		task.spawn(function()
			while window.IsOpen() do
				task.wait(0.5)
				refresh()
			end
		end)
	end)
end

return RewardsWindow
