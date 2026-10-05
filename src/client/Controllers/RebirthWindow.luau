-- Rebirth window [R] and Titles window [T].

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetConfig = require(Shared.Config.PetConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local RebirthConfig = require(Shared.Config.RebirthConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Util.Format)
local Make = require(Shared.Util.Make)
local Net = require(Shared.Net)
local WeightedRandom = require(Shared.Util.WeightedRandom)

local ClientData = require(script.Parent.Parent.ClientData)
local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)
local HUDController = require(script.Parent.HUDController)
local SoundController = require(script.Parent.SoundController)

local RebirthWindow = {}

-- Title odds, with the luck boost applied when it's active.
local function titleChances(lucky: boolean): { number }
	return WeightedRandom.Chances(RebirthConfig.Titles, function(title)
		if lucky and RarityConfig[title.Rarity].Lucky then
			return title.Weight * PetConfig.LuckBoostMultiplier
		end
		return title.Weight
	end)
end

local function buildRebirth()
	local window = Components.Window("Rebirth", "🔁 REBIRTH", Vector2.new(680, 560), Theme.Pink)
	local body = window.Body

	local header = Components.Label({
		Size = UDim2.new(1, 0, 0, 44),
		Text = "",
		TextSize = 32,
		TextColor3 = Theme.Accent,
		Parent = body,
	})
	local _, setProgress, progressText = Components.ProgressBar({
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 36),
		Color = Theme.Good,
		TextSize = 20,
		Parent = body,
	})
	Components.Label({
		Position = UDim2.fromOffset(0, 96),
		Size = UDim2.new(1, 0, 0, 52),
		Text = "Resets: " .. Make.Colored("Cash & Upgrades", Theme.Bad) .. "\nKeeps: " .. Make.Colored(
			"Zones, Pets & Titles",
			Theme.Good
		),
		TextSize = 20,
		TextColor3 = Theme.SubText,
		Parent = body,
	})
	Components.Label({
		Position = UDim2.fromOffset(0, 152),
		Size = UDim2.new(1, 0, 0, 28),
		Text = "🎲 Every rebirth rolls a random TITLE:",
		TextSize = 22,
		Parent = body,
	})
	local oddsList = Components.ScrollList({
		Position = UDim2.fromOffset(0, 184),
		Size = UDim2.new(1, 0, 1, -184 - 76),
		Gap = 2,
		Parent = body,
	})
	local oddsRows = {}
	for index in RebirthConfig.Titles do
		oddsRows[index] = Components.Label({
			Size = UDim2.new(1, 0, 0, 26),
			Text = "",
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = index,
			Parent = oddsList,
		})
	end

	local rebirthButton = Components.Button({
		Text = "REBIRTH",
		Color = Theme.Pink,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(360, 64),
		TextSize = 30,
		Parent = body,
		OnClick = function()
			local ok, message = Net.Invoke("Rebirth")
			if ok then
				window.Close()
			else
				SoundController.Play("UIError")
				if message then
					HUDController.Toast(message, "Bad")
				end
			end
		end,
	})

	local function refresh()
		local data = ClientData.Data
		local cost = Formulas.RebirthCost(data.Rebirths)
		local now = Formulas.RebirthMultiplier(data.Rebirths)
		local nextMultiplier = Formulas.RebirthMultiplier(data.Rebirths + 1)
		header.Text = string.format(
			"Rebirth #%d · %s → %s cash",
			data.Rebirths + 1,
			Format.Multiplier(now),
			Make.Colored(Format.Multiplier(nextMultiplier), Theme.Good)
		)
		setProgress(data.Cash / cost)
		progressText.Text = Format.Cash(data.Cash) .. " / " .. Format.Cash(cost)
		Components.SetButton(
			rebirthButton,
			if data.Cash >= cost then "🔁 REBIRTH NOW!" else "Need " .. Format.Cash(cost - data.Cash) .. " more",
			if data.Cash >= cost then Theme.Pink else Theme.Disabled
		)
		local lucky = Formulas.IsBoostActive(data, "Luck", HUDController.Now())
		local chances = titleChances(lucky)
		for index, title in RebirthConfig.Titles do
			local rarity = RarityConfig[title.Rarity]
			local owned = data.Titles[title.Id]
			oddsRows[index].Text = string.format(
				"%s %s  %s  %s",
				if owned then "✅" else "▫️",
				Make.Colored(if owned then title.Text else "???", rarity.Color),
				Make.Colored("(" .. rarity.Name .. ")", Theme.SubText),
				Make.Colored(
					Format.Percent(chances[index]) .. (if lucky and rarity.Lucky then " 🍀" else ""),
					Theme.Accent
				)
			)
		end
	end

	ClientData.Observe({ "Cash", "Rebirths", "Titles", "Boosts" }, function()
		if window.IsOpen() then
			refresh()
		end
	end)
	window.Opened:Connect(refresh)
end

local function buildTitles()
	local window = Components.Window("Titles", "🏷️ TITLES", Vector2.new(620, 540), Color3.fromRGB(170, 110, 255))
	local list = Components.ScrollList({ Size = UDim2.new(1, 0, 1, -70), Parent = window.Body })
	Components.Button({
		Text = "Hide title",
		Color = Theme.Disabled,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(220, 52),
		Parent = window.Body,
		OnClick = function()
			Net.Invoke("EquipTitle", "")
		end,
	})
	local rows = {}
	for index, title in RebirthConfig.Titles do
		local row = Components.Row(64, index, list)
		local label = Components.Label({
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -200, 1, 0),
			Text = "",
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local button = Components.Button({
			Text = "",
			Size = UDim2.fromOffset(160, 46),
			Position = UDim2.new(1, -172, 0.5, -23),
			Parent = row,
			OnClick = function()
				if ClientData.Data.Titles[title.Id] then
					Net.Invoke("EquipTitle", title.Id)
				end
			end,
		})
		rows[title.Id] = { Label = label, Button = button }
	end

	local function refresh()
		local data = ClientData.Data
		for _, title in RebirthConfig.Titles do
			local row = rows[title.Id]
			local rarity = RarityConfig[title.Rarity]
			local owned = data.Titles[title.Id]
			row.Label.Text = Make.Colored(if owned then title.Text else "🔒 ???", rarity.Color)
				.. "\n"
				.. Make.Colored(rarity.Name .. (if title.Aura then " · ✨ aura" else ""), Theme.SubText)
			if not owned then
				Components.SetButton(row.Button, "Not owned", Theme.Disabled)
			elseif data.EquippedTitle == title.Id then
				Components.SetButton(row.Button, "Equipped ✅", Theme.Info)
			else
				Components.SetButton(row.Button, "Equip", Theme.Good)
			end
		end
	end

	ClientData.Observe({ "Titles", "EquippedTitle" }, function()
		if window.IsOpen() then
			refresh()
		end
	end)
	window.Opened:Connect(refresh)
end

function RebirthWindow.Start()
	buildRebirth()
	buildTitles()
end

return RebirthWindow
