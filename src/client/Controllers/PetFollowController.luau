-- Draws every player's equipped pets locally and makes them bob along
-- behind their owner. Reads each player's "EquippedPets" attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetConfig = require(Shared.Config.PetConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local Make = require(Shared.Util.Make)

local PetFollowController = {}

type PetVisual = { Part: BasePart, Size: number }

local visuals: { [Player]: { PetVisual } } = {}
local folder: Folder

-- Slots behind the owner (right, left, back).
local SLOTS = {
	Vector3.new(4, 0, 4),
	Vector3.new(-4, 0, 4),
	Vector3.new(0, 0, 7),
	Vector3.new(6, 0, 8),
	Vector3.new(-6, 0, 8),
}

local function buildPet(petId: string): PetVisual?
	local pet = PetConfig.Pets[petId]
	if not pet then
		return nil
	end
	local rarity = RarityConfig[pet.Rarity]
	-- The pet is its emoji floating on an invisible anchor, lit in its color.
	local body = Make.Part({
		Name = pet.Id,
		Size = Vector3.one * pet.Size,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = folder,
	})
	Make.Billboard(body, Vector2.new(pet.Size * 1.5, pet.Size * 1.5), Vector3.new(0, 0, 0), pet.Emoji, {
		TextStrokeTransparency = 1,
	}).MaxDistance =
		100
	Make.Instance("PointLight", { Color = pet.Color, Range = 6, Brightness = 1, Parent = body })
	if rarity.Order >= RarityConfig.Legendary.Order then
		Make.Instance("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(rarity.Color),
			LightEmission = 1,
			Rate = 8,
			Lifetime = NumberRange.new(0.6, 1),
			Speed = NumberRange.new(0.5, 2),
			Size = NumberSequence.new(0.4, 0),
			Parent = body,
		})
	end
	return { Part = body, Size = pet.Size }
end

local function clear(player: Player)
	local list = visuals[player]
	if list then
		for _, visual in list do
			visual.Part:Destroy()
		end
	end
	visuals[player] = nil
end

local function rebuild(player: Player)
	clear(player)
	local list = {}
	local attribute = player:GetAttribute("EquippedPets")
	if type(attribute) == "string" and attribute ~= "" then
		for petId in string.gmatch(attribute, "[^,]+") do
			local visual = buildPet(petId)
			if visual then
				table.insert(list, visual)
			end
		end
	end
	visuals[player] = list
end

local function onPlayer(player: Player)
	player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuild(player)
	end)
	player.CharacterAdded:Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

function PetFollowController.Start()
	folder = Make.Instance("Folder", { Name = "LocalPets", Parent = workspace })
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(clear)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local alpha = math.min(1, dt * 8)
		for player, list in visuals do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			local base = root.CFrame
			for index, visual in list do
				local slot = SLOTS[index] or SLOTS[#SLOTS]
				local bob = math.sin(t * 3 + index) * 0.6
				local target = base * CFrame.new(slot + Vector3.new(0, bob - 1 + visual.Size / 2, 0))
				local current = visual.Part.CFrame
				local position = current.Position:Lerp(target.Position, alpha)
				local look = base.LookVector
				visual.Part.CFrame = CFrame.lookAt(position, position + look)
			end
		end
	end)
end

return PetFollowController
