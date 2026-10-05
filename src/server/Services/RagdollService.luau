-- Goofy ragdolls for R15 and R6. The server swaps each Motor6D for a
-- BallSocketConstraint and adds invisible limb colliders; the owning client
-- switches its Humanoid into the Physics state and applies the fling (the
-- client owns its character's physics, so velocity must be set there).

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Make = require(Shared.Util.Make)
local Net = require(Shared.Net)

local RagdollService = {}

local PLAYER_GROUP = "Players"
local COLLIDER_GROUP = "RagdollColliders"

type RagdollState = {
	Motors: { Motor6D },
	Created: { Instance },
	RootCollide: boolean,
}

local states: { [Model]: RagdollState } = {}

local function setupCollisionGroups()
	for _, group in { PLAYER_GROUP, COLLIDER_GROUP } do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(group)
		end)
	end
	-- Players walk through each other (no blocking doorways), and ragdoll
	-- limbs don't jitter against each other or their owner's body.
	PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, PLAYER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, COLLIDER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(COLLIDER_GROUP, COLLIDER_GROUP, false)
end

function RagdollService.IsRagdolled(character: Model?): boolean
	return character ~= nil and character:GetAttribute("Ragdolled") == true
end

-- Seconds of immunity remaining after getting up.
function RagdollService.IsImmune(character: Model?): boolean
	return character ~= nil and (character:GetAttribute("ImmuneUntil") or 0) > os.clock()
end

local function recover(player: Player, character: Model)
	local state = states[character]
	states[character] = nil
	if not state or character.Parent == nil then
		return
	end
	for _, instance in state.Created do
		instance:Destroy()
	end
	for _, motor in state.Motors do
		motor.Enabled = true
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.RequiresNeck = true
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.CanCollide = state.RootCollide
	end

	character:SetAttribute("Ragdolled", false)
	character:SetAttribute("ImmuneUntil", os.clock() + GameConfig.PostRagdollImmunity)
	local shield = Make.Instance("ForceField", { Visible = true, Parent = character })
	task.delay(GameConfig.PostRagdollImmunity, function()
		shield:Destroy()
	end)
	if player.Parent then
		Net.Fire(player, "Ragdoll", false)
	end
end

-- Ragdolls a player's character for `duration` seconds and flings it.
-- Returns false if they're already ragdolled.
function RagdollService.Ragdoll(player: Player, duration: number, fling: Vector3): boolean
	local character = player.Character
	if not character or RagdollService.IsRagdolled(character) then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	character:SetAttribute("Ragdolled", true)
	humanoid.RequiresNeck = false
	local state: RagdollState = { Motors = {}, Created = {}, RootCollide = true }
	states[character] = state

	for _, motor in character:GetDescendants() do
		-- Keep the root joint so the camera and HumanoidRootPart follow the body.
		if not motor:IsA("Motor6D") or motor.Name == "Root" or motor.Name == "RootJoint" then
			continue
		end
		local part0, part1 = motor.Part0, motor.Part1
		if not part0 or not part1 then
			continue
		end
		local attachment0 = Make.Instance("Attachment", { Name = "RagdollA0", CFrame = motor.C0, Parent = part0 })
		local attachment1 = Make.Instance("Attachment", { Name = "RagdollA1", CFrame = motor.C1, Parent = part1 })
		local socket = Make.Instance("BallSocketConstraint", {
			Name = "RagdollSocket",
			Attachment0 = attachment0,
			Attachment1 = attachment1,
			LimitsEnabled = true,
			TwistLimitsEnabled = true,
			UpperAngle = 50,
			TwistLowerAngle = -50,
			TwistUpperAngle = 50,
			Parent = part0,
		})
		table.insert(state.Created, attachment0)
		table.insert(state.Created, attachment1)
		table.insert(state.Created, socket)
		motor.Enabled = false
		table.insert(state.Motors, motor)
	end

	-- Most limbs don't collide by default; give each one a collider so the
	-- body lands on the floor instead of sinking through it.
	for _, part in character:GetChildren() do
		if not part:IsA("BasePart") or part.Name == "HumanoidRootPart" then
			continue
		end
		local collider = Make.Part({
			Name = "RagdollCollider",
			Anchored = false,
			Massless = true,
			CanCollide = true,
			CanQuery = false,
			CanTouch = false,
			Transparency = 1,
			Size = part.Size * 0.8,
			CFrame = part.CFrame,
			CollisionGroup = COLLIDER_GROUP,
			Parent = part,
		})
		Make.Instance("WeldConstraint", { Part0 = part, Part1 = collider, Parent = collider })
		table.insert(state.Created, collider)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		state.RootCollide = root.CanCollide
		root.CanCollide = false
	end

	Net.Fire(player, "Ragdoll", true, fling)
	task.delay(duration, recover, player, character)
	return true
end

function RagdollService.Start()
	setupCollisionGroups()

	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.BreakJointsOnDeath = false
		end
		local function setGroup(part: Instance)
			if part:IsA("BasePart") and part.Name ~= "RagdollCollider" then
				part.CollisionGroup = PLAYER_GROUP
			end
		end
		for _, part in character:GetDescendants() do
			setGroup(part)
		end
		character.DescendantAdded:Connect(setGroup)
		character.Destroying:Connect(function()
			states[character] = nil
		end)
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return RagdollService
