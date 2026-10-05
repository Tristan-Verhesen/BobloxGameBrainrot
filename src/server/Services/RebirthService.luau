-- Rebirths (reset Cash + Upgrades for a permanent multiplier and an RNG title
-- roll) and the title tag / aura shown above each player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local PetConfig = require(Shared.Config.PetConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local RebirthConfig = require(Shared.Config.RebirthConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Util.Format)
local Make = require(Shared.Util.Make)
local Net = require(Shared.Net)
local WeightedRandom = require(Shared.Util.WeightedRandom)

local DataService = require(script.Parent.DataService)

local RebirthService = {}

local rng = Random.new()

local function rollTitle(lucky: boolean): RebirthConfig.Title
	return WeightedRandom.Pick(RebirthConfig.Titles, rng, function(title)
		if lucky and RarityConfig[title.Rarity].Lucky then
			return title.Weight * PetConfig.LuckBoostMultiplier
		end
		return title.Weight
	end)
end

local function rarityOrder(titleId: string): number
	local title = RebirthConfig.TitlesById[titleId]
	return if title then RarityConfig[title.Rarity].Order else 0
end

-- Rebuilds the floating title tag and aura on the player's character.
function RebirthService.ApplyTitle(player: Player)
	local data = DataService.Get(player)
	local character = player.Character
	if not data or not character then
		return
	end
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	for _, name in { "TitleTag", "TitleAura" } do
		local existing = character:FindFirstChild(name, true)
		if existing then
			existing:Destroy()
		end
	end
	if not head then
		return
	end

	local title = RebirthConfig.TitlesById[data.EquippedTitle]
	local lines = {}
	if title then
		table.insert(lines, Make.Colored(title.Text, RarityConfig[title.Rarity].Color))
	end
	if data.Rebirths > 0 then
		table.insert(lines, Make.Colored("🔁 Rebirth " .. data.Rebirths, Color3.fromRGB(200, 200, 255)))
	end
	if #lines > 0 then
		local gui =
			Make.Billboard(head, Vector2.new(10, 1.2 * #lines), Vector3.new(0, 2.6, 0), table.concat(lines, "\n"), {
				Name = "TitleLabel",
			})
		gui.Name = "TitleTag"
		gui.MaxDistance = 80
	end
	if title and title.Aura and root then
		Make.Instance("ParticleEmitter", {
			Name = "TitleAura",
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(RarityConfig[title.Rarity].Color),
			LightEmission = 1,
			Rate = 14,
			Lifetime = NumberRange.new(0.8, 1.4),
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Parent = root,
		})
	end
end

local function rebirth(player: Player): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, nil
	end
	local cost = Formulas.RebirthCost(data.Rebirths)
	if data.Cash < cost then
		return false, "Need " .. Format.Cash(cost - data.Cash) .. " more to rebirth"
	end

	data.Cash = 0
	data.Upgrades = {}
	data.Rebirths += 1
	local title = rollTitle(Formulas.IsBoostActive(data, "Luck", os.time()))
	local isNew = not data.Titles[title.Id]
	data.Titles[title.Id] = true
	if rarityOrder(title.Id) > rarityOrder(data.EquippedTitle) then
		data.EquippedTitle = title.Id
	end
	for _, key in { "Cash", "Upgrades", "Rebirths", "Titles", "EquippedTitle" } do
		DataService.MarkChanged(player, key)
	end
	RebirthService.ApplyTitle(player)

	Net.Fire(player, "Effect", "Rebirth", {
		Rebirths = data.Rebirths,
		TitleId = title.Id,
		New = isNew,
		Multiplier = Formulas.RebirthMultiplier(data.Rebirths),
	})
	local rarity = RarityConfig[title.Rarity]
	if rarity.Announce and GameConfig.AnnounceRareHatchesInServer then
		Net.FireAll(
			"Announce",
			string.format('%s rolled the %s title "%s"!', player.DisplayName, rarity.Name, title.Text),
			rarity.Color
		)
	end
	return true, nil
end

local function equipTitle(player: Player, titleId: any): (boolean, string?)
	local data = DataService.Get(player)
	if not data or type(titleId) ~= "string" then
		return false, nil
	end
	if titleId ~= "" and not data.Titles[titleId] then
		return false, "You don't own that title"
	end
	data.EquippedTitle = titleId
	DataService.MarkChanged(player, "EquippedTitle")
	RebirthService.ApplyTitle(player)
	return true, nil
end

function RebirthService.Start()
	Net.Handle("Rebirth", rebirth, 1)
	Net.Handle("EquipTitle", equipTitle, 4)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			RebirthService.ApplyTitle(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return RebirthService
