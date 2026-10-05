-- Upgrade shop purchases, and applying upgrade stats to the character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)

local UpgradeService = {}

function UpgradeService.ApplyStats(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	player:SetAttribute("PickupRange", Formulas.PickupRange(data))
	player:SetAttribute("ClickPower", Formulas.ClickPower(data))
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Formulas.WalkSpeed(data)
	end
end

local function buy(player: Player, upgradeId: any): (boolean, string?)
	if type(upgradeId) ~= "string" then
		return false, "Invalid upgrade"
	end
	local upgrade = UpgradeConfig.ById[upgradeId]
	local data = DataService.Get(player)
	if not upgrade or not data then
		return false, "Invalid upgrade"
	end
	local level = Formulas.UpgradeLevel(data, upgradeId)
	if level >= upgrade.MaxLevel then
		return false, "Already maxed!"
	end
	local cost = Formulas.UpgradeCost(upgradeId, level)
	if not DataService.SpendCash(player, cost) then
		return false, "Need " .. Format.Cash(cost - data.Cash) .. " more"
	end
	data.Upgrades[upgradeId] = level + 1
	DataService.MarkChanged(player, "Upgrades")
	return true, string.format("%s %s Lv.%d!", upgrade.Emoji, upgrade.Name, level + 1)
end

function UpgradeService.Start()
	Net.Handle("BuyUpgrade", buy, 10)

	DataService.Changed:Connect(function(player, key)
		if key == "Upgrades" then
			UpgradeService.ApplyStats(player)
		end
	end)
	DataService.Loaded:Connect(UpgradeService.ApplyStats)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			UpgradeService.ApplyStats(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return UpgradeService
