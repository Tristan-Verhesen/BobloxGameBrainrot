-- Egg hatching, pet inventory and equipping. Equipped pets are published as
-- a player attribute ("EquippedPets" = "SmolCapy,AuraAxolotl") and drawn by
-- every client (see client PetFollowController), which keeps the server cheap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local PetConfig = require(Shared.Config.PetConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local WeightedRandom = require(Shared.Util.WeightedRandom)

local DataService = require(script.Parent.DataService)
local MapBuilder = require(script.Parent.MapBuilder)

local PetService = {}

local HATCH_COOLDOWN = 1.2
local rng = Random.new()
local lastHatch: { [Player]: number } = {}

local function countPets(data: any): number
	local count = 0
	for _ in data.Pets do
		count += 1
	end
	return count
end

local function publishEquipped(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local ids = {}
	for _, uid in data.EquippedPets do
		local petId = data.Pets[uid]
		if petId then
			table.insert(ids, petId)
		end
	end
	player:SetAttribute("EquippedPets", table.concat(ids, ","))
end

-- Rolls a pet from an egg. Luck boosts multiply the weight of Rare+ pets.
function PetService.Roll(eggId: string, lucky: boolean): string
	local egg = PetConfig.EggsById[eggId]
	local entry = WeightedRandom.Pick(egg.Pets, rng, function(e)
		local pet = PetConfig.Pets[e.Id]
		if lucky and RarityConfig[pet.Rarity].Lucky then
			return e.Weight * PetConfig.LuckBoostMultiplier
		end
		return e.Weight
	end)
	return entry.Id
end

function PetService.Hatch(player: Player, eggId: any): (boolean, string?)
	if type(eggId) ~= "string" then
		return false, "Invalid egg"
	end
	local egg = PetConfig.EggsById[eggId]
	local data = DataService.Get(player)
	if not egg or not data then
		return false, "Invalid egg"
	end
	local now = os.clock()
	if now - (lastHatch[player] or 0) < HATCH_COOLDOWN then
		return false, nil -- still animating the last hatch; ignore quietly
	end
	if not data.Zones[egg.RequiredZone] then
		return false, "🔒 Unlock " .. ZoneConfig.ById[egg.RequiredZone].Name .. " to hatch this egg"
	end
	if countPets(data) >= GameConfig.MaxPetInventory then
		return false, "Pet inventory full! Delete some pets first."
	end
	if not DataService.SpendCash(player, egg.Cost) then
		return false, "Need " .. Format.Cash(egg.Cost - data.Cash) .. " more"
	end
	lastHatch[player] = now

	local petId = PetService.Roll(eggId, Formulas.IsBoostActive(data, "Luck", os.time()))
	local uid = "P" .. data.NextPetUid
	data.NextPetUid += 1
	data.Pets[uid] = petId
	DataService.AddStat(player, "PetsHatched", 1)
	DataService.MarkChanged(player, "Pets")
	DataService.MarkChanged(player, "NextPetUid")

	if #data.EquippedPets < GameConfig.MaxEquippedPets then
		table.insert(data.EquippedPets, uid)
		DataService.MarkChanged(player, "EquippedPets")
		publishEquipped(player)
	end

	Net.Fire(player, "HatchResult", eggId, petId, uid)
	local pet = PetConfig.Pets[petId]
	local rarity = RarityConfig[pet.Rarity]
	if GameConfig.AnnounceRareHatchesInServer and rarity.Announce then
		Net.FireAll(
			"Announce",
			string.format("%s hatched a %s %s %s!", player.DisplayName, rarity.Name, pet.Emoji, pet.Name),
			rarity.Color
		)
	end
	return true, nil
end

local function equip(player: Player, uid: any): (boolean, string?)
	local data = DataService.Get(player)
	if not data or type(uid) ~= "string" or not data.Pets[uid] then
		return false, "Invalid pet"
	end
	if table.find(data.EquippedPets, uid) then
		return false, "Already equipped"
	end
	if #data.EquippedPets >= GameConfig.MaxEquippedPets then
		return false, "All " .. GameConfig.MaxEquippedPets .. " pet slots are full"
	end
	table.insert(data.EquippedPets, uid)
	DataService.MarkChanged(player, "EquippedPets")
	publishEquipped(player)
	return true, nil
end

local function unequip(player: Player, uid: any): (boolean, string?)
	local data = DataService.Get(player)
	if not data or type(uid) ~= "string" then
		return false, "Invalid pet"
	end
	local index = table.find(data.EquippedPets, uid)
	if not index then
		return false, "Not equipped"
	end
	table.remove(data.EquippedPets, index)
	DataService.MarkChanged(player, "EquippedPets")
	publishEquipped(player)
	return true, nil
end

local function equipBest(player: Player): (boolean, string?)
	local data = DataService.Get(player)
	if not data then
		return false, nil
	end
	local owned = {}
	for uid, petId in data.Pets do
		table.insert(owned, { Uid = uid, Multiplier = PetConfig.Pets[petId].Multiplier })
	end
	table.sort(owned, function(a, b)
		return a.Multiplier > b.Multiplier
	end)
	local equipped = {}
	for index = 1, math.min(GameConfig.MaxEquippedPets, #owned) do
		equipped[index] = owned[index].Uid
	end
	data.EquippedPets = equipped
	DataService.MarkChanged(player, "EquippedPets")
	publishEquipped(player)
	return true, "Equipped your best pets!"
end

local function delete(player: Player, uid: any): (boolean, string?)
	local data = DataService.Get(player)
	if not data or type(uid) ~= "string" or not data.Pets[uid] then
		return false, "Invalid pet"
	end
	local index = table.find(data.EquippedPets, uid)
	if index then
		table.remove(data.EquippedPets, index)
		DataService.MarkChanged(player, "EquippedPets")
	end
	data.Pets[uid] = nil
	DataService.MarkChanged(player, "Pets")
	publishEquipped(player)
	return true, nil
end

function PetService.Start()
	Net.Handle("HatchEgg", PetService.Hatch, 3)
	Net.Handle("EquipPet", equip, 8)
	Net.Handle("UnequipPet", unequip, 8)
	Net.Handle("EquipBest", equipBest, 2)
	Net.Handle("DeletePet", delete, 8)

	for _, stand in MapBuilder.EggStands do
		stand.Prompt.Triggered:Connect(function(player)
			local ok, message = PetService.Hatch(player, stand.EggId)
			if not ok and message then
				Net.Fire(player, "Notify", message, "Bad")
			end
		end)
	end

	DataService.Loaded:Connect(function(player, data)
		-- Drop equipped uids that no longer exist (e.g. edited saves).
		local valid = {}
		for _, uid in data.EquippedPets do
			if data.Pets[uid] and PetConfig.Pets[data.Pets[uid]] and not table.find(valid, uid) then
				table.insert(valid, uid)
			end
		end
		data.EquippedPets = valid
		for uid, petId in data.Pets do
			if not PetConfig.Pets[petId] then
				data.Pets[uid] = nil -- pet removed from config
			end
		end
		publishEquipped(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastHatch[player] = nil
	end)
end

return PetService
