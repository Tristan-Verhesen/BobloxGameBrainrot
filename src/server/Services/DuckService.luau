-- The Giant Angry Rubber Ducks. Each zone has its own duck(s) that patrol,
-- spot players with a vision cone + line of sight (props block it, so you can
-- hide), chase, and bonk you: ragdoll + drop all your snacks.
--
-- Ducks never leave their zone, so running back into the hub always saves you.
-- Movement is simulated on the server and driven through AlignPosition /
-- AlignOrientation on a server-owned physics root, so clients see it smoothly
-- interpolated.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local SoundConfig = require(Shared.Config.SoundConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local MapLayout = require(Shared.MapLayout)
local Make = require(Shared.Util.Make)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local EventService = require(script.Parent.EventService)
local FoodService = require(script.Parent.FoodService)
local MapBuilder = require(script.Parent.MapBuilder)
local RagdollService = require(script.Parent.RagdollService)

type Duck = {
	Model: Model,
	Root: BasePart,
	Align: AlignPosition,
	Orient: AlignOrientation,
	ZoneId: string,
	Stats: ZoneConfig.DuckStats,
	Radius: number,
	Hover: number,
	EyeHeight: number,
	Position: Vector3,
	Heading: Vector3,
	State: string, -- "Patrol" | "Idle" | "Chase" | "Celebrate"
	StateUntil: number,
	Target: Player?,
	LastSeenAt: number,
	LastSeenPos: Vector3,
	PatrolPoint: Vector3,
	PatrolUntil: number,
	NextQuack: number,
	Alert: BillboardGui,
	Sounds: { [string]: Sound },
}

local DuckService = {}

local ducks: { Duck } = {}
local chasers: { [Player]: { [Duck]: boolean } } = {}
local rng = Random.new()
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Include

local CLOSE_SENSE = 12 -- studs: ducks "hear" players this close even from behind
local DETECT_TICK = 0.2
local STEER_ANGLES = { 0, 25, -25, 50, -50, 80, -80, 115, -115, 150, -150 }

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function rotateY(vector: Vector3, degrees: number): Vector3
	return CFrame.Angles(0, math.rad(degrees), 0):VectorToWorldSpace(vector)
end

local function sound(
	parent: Instance,
	name: string,
	settings: { Id: string, Volume: number, Speed: number },
	looped: boolean
): Sound
	return Make.Instance("Sound", {
		Name = name,
		SoundId = settings.Id,
		Volume = settings.Volume,
		PlaybackSpeed = settings.Speed,
		Looped = looped,
		RollOffMaxDistance = SoundConfig.Duck.RollOffMaxDistance,
		RollOffMinDistance = 15,
		Parent = parent,
	})
end

-- Builds the greybox duck. Returns the model, its physics root, and how high
-- the root's center sits above the floor.
local function buildGreyboxDuck(stats: ZoneConfig.DuckStats): (Model, BasePart, number)
	local s = stats.Scale
	local model = Make.Instance("Model", { Name = stats.Name })
	local root = Make.Part({
		Name = "Root",
		Size = Vector3.new(6, 6, 6) * s,
		Transparency = 1,
		Parent = model,
	})
	model.PrimaryPart = root
	local yellow = stats.Color
	local orange = Color3.fromRGB(255, 140, 20)

	local function piece(kind: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): BasePart
		local props = {
			Size = size * s,
			CFrame = root.CFrame * CFrame.new(offset.Position * s) * offset.Rotation,
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			Parent = model,
		}
		if kind == "Ellipsoid" then
			return Make.Ellipsoid(props)
		elseif kind == "Wedge" then
			return Make.Part(props, nil, "WedgePart")
		end
		return Make.Part(props)
	end

	piece("Ellipsoid", Vector3.new(9, 7, 11), CFrame.new(0, 0, 0), yellow)
	piece("Ellipsoid", Vector3.new(7, 6, 6), CFrame.new(0, 0.8, -3.2), yellow)
	piece("Ellipsoid", Vector3.new(6, 6, 6), CFrame.new(0, 4.8, -4.2), yellow)
	piece("Ellipsoid", Vector3.new(1.2, 4, 6), CFrame.new(4.4, 0.6, 0.4), yellow:Lerp(Color3.new(0, 0, 0), 0.12))
	piece("Ellipsoid", Vector3.new(1.2, 4, 6), CFrame.new(-4.4, 0.6, 0.4), yellow:Lerp(Color3.new(0, 0, 0), 0.12))
	piece("Ellipsoid", Vector3.new(3.8, 1.3, 3.4), CFrame.new(0, 4.1, -7.4), orange)
	piece("Ellipsoid", Vector3.new(3, 0.8, 2.6), CFrame.new(0, 3.3, -7), orange:Lerp(Color3.new(0, 0, 0), 0.25))
	piece("Wedge", Vector3.new(3, 2.5, 3), CFrame.new(0, 1.8, 5.6) * CFrame.Angles(0, math.pi, 0), yellow)
	piece("Part", Vector3.new(2.6, 0.5, 3.2), CFrame.new(2, -3.5, -1.5), orange)
	piece("Part", Vector3.new(2.6, 0.5, 3.2), CFrame.new(-2, -3.5, -1.5), orange)
	for _, side in { -1, 1 } do
		local eye = piece(
			"Ellipsoid",
			Vector3.new(1.3, 1.3, 1.3),
			CFrame.new(1.6 * side, 5.6, -6.6),
			Color3.fromRGB(255, 30, 30),
			Enum.Material.Neon
		)
		Make.Instance(
			"PointLight",
			{ Color = Color3.fromRGB(255, 40, 40), Range = 10 * s, Brightness = 2, Parent = eye }
		)
		-- Angry eyebrows slanting down toward the beak.
		piece(
			"Part",
			Vector3.new(2.2, 0.45, 0.5),
			CFrame.new(1.5 * side, 6.7, -6.7) * CFrame.Angles(0, 0, math.rad(-22 * side)),
			Color3.fromRGB(30, 20, 20)
		)
	end
	return model, root, 3.75 * s
end

-- Uses ReplicatedStorage.Assets.Duck if you've added a custom model.
local function buildDuckModel(stats: ZoneConfig.DuckStats): (Model, BasePart, number)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("Duck")
	if custom and custom:IsA("Model") then
		local model = custom:Clone()
		model.Name = stats.Name
		pcall(function()
			model:ScaleTo(model:GetScale() * stats.Scale)
		end)
		local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if root then
			model.PrimaryPart = root
			local boxCFrame, boxSize = model:GetBoundingBox()
			local hover = root.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
			return model, root, hover
		end
		warn("[DuckService] Assets.Duck has no parts; using the greybox duck")
	end
	return buildGreyboxDuck(stats)
end

local function pickPatrolPoint(duck: Duck)
	for _ = 1, 15 do
		local point = MapLayout.RandomPointInZone(duck.ZoneId, rng, duck.Radius + 8)
		if not MapBuilder.IsBlocked(duck.ZoneId, point, duck.Radius) then
			duck.PatrolPoint = point
			duck.PatrolUntil = os.clock() + 10
			return
		end
	end
	duck.PatrolPoint = MapLayout.GetZoneBounds(duck.ZoneId).Center
	duck.PatrolUntil = os.clock() + 10
end

local function spawnDuck(zone: ZoneConfig.Zone, index: number)
	local stats = zone.Duck
	local model, root, hover = buildDuckModel(stats)
	local s = stats.Scale

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = part ~= root
		end
	end
	Make.WeldAll(model, root)
	root.Anchored = false
	root.Massless = false

	local start = MapLayout.ZoneLocalToWorld(zone.Id, MapLayout.ZoneDepth * 0.6 + index * 12, (index - 1.5) * 30)
	local heading = -MapLayout.GetZoneBounds(zone.Id).Direction
	model:PivotTo(CFrame.lookAt(start + Vector3.new(0, hover, 0), start + Vector3.new(0, hover, 0) + heading))

	local attachment = Make.Instance("Attachment", { Name = "DuckAlign", Parent = root })
	local align = Make.Instance("AlignPosition", {
		Mode = Enum.PositionAlignmentMode.OneAttachment,
		Attachment0 = attachment,
		RigidityEnabled = true,
		Position = start + Vector3.new(0, hover, 0),
		Parent = root,
	})
	local orient = Make.Instance("AlignOrientation", {
		Mode = Enum.OrientationAlignmentMode.OneAttachment,
		Attachment0 = attachment,
		RigidityEnabled = true,
		CFrame = CFrame.lookAt(Vector3.zero, heading),
		Parent = root,
	})

	Make.Billboard(
		root,
		Vector2.new(14, 2.4) * math.sqrt(s),
		Vector3.new(0, 9.5 * s, 0),
		"🦆 " .. string.upper(stats.Name),
		{
			TextColor3 = Color3.fromRGB(255, 230, 80),
		}
	)
	local alert = Make.Billboard(root, Vector2.new(5, 5) * s, Vector3.new(0, 13 * s, 0), "❗", {
		TextColor3 = Color3.fromRGB(255, 40, 40),
	})
	alert.Enabled = false

	local sounds = {
		Quack = sound(root, "Quack", SoundConfig.Duck.Quack, false),
		Squeak = sound(root, "Squeak", SoundConfig.Duck.Squeak, false),
		Waddle = sound(root, "Waddle", SoundConfig.Duck.Waddle, true),
	}

	model.Parent = MapBuilder.Folders.Ducks
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local duck: Duck = {
		Model = model,
		Root = root,
		Align = align,
		Orient = orient,
		ZoneId = zone.Id,
		Stats = stats,
		Radius = 5 * s,
		Hover = hover,
		EyeHeight = hover + 4.8 * s,
		Position = Vector3.new(start.X, MapLayout.FloorY, start.Z),
		Heading = heading,
		State = "Patrol",
		StateUntil = 0,
		Target = nil,
		LastSeenAt = 0,
		LastSeenPos = start,
		PatrolPoint = start,
		PatrolUntil = 0,
		NextQuack = os.clock() + rng:NextNumber(4, 10),
		Alert = alert,
		Sounds = sounds,
	}
	pickPatrolPoint(duck)
	table.insert(ducks, duck)
end

local function refreshChased(player: Player)
	local set = chasers[player]
	local name = nil
	if set then
		for duck in set do
			name = duck.Stats.Name
			break
		end
		if not name then
			chasers[player] = nil
		end
	end
	if player.Parent then
		player:SetAttribute("ChasedBy", name)
	end
end

local function targetRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Whether this player is a legal target for this duck right now.
local function isHuntable(duck: Duck, player: Player): (boolean, BasePart?)
	local root = targetRoot(player)
	if not root then
		return false, nil
	end
	local character = player.Character
	if RagdollService.IsRagdolled(character) or RagdollService.IsImmune(character) then
		return false, nil
	end
	if MapLayout.ZoneAt(root.Position) ~= duck.ZoneId then
		return false, nil
	end
	return true, root
end

local function canSee(duck: Duck, root: BasePart, range: number, useCone: boolean): boolean
	local offset = flat(root.Position - duck.Position)
	local distance = offset.Magnitude
	if distance > range then
		return false
	end
	if useCone and distance > CLOSE_SENSE then
		local cosHalf = math.cos(math.rad(duck.Stats.FieldOfView / 2))
		if duck.Heading:Dot(offset.Unit) < cosHalf then
			return false
		end
	end
	local eye = duck.Position + Vector3.new(0, duck.EyeHeight, 0)
	local result = workspace:Raycast(eye, root.Position - eye, losParams)
	return result == nil
end

local function startChase(duck: Duck, player: Player)
	duck.State = "Chase"
	duck.Target = player
	duck.LastSeenAt = os.clock()
	duck.Alert.Enabled = true
	duck.Sounds.Squeak:Play()
	local set = chasers[player] or {}
	set[duck] = true
	chasers[player] = set
	refreshChased(player)
	Net.Fire(player, "Effect", "DuckSpotted", { Duck = duck.Stats.Name })
end

local function stopChase(duck: Duck, notify: boolean)
	local player = duck.Target
	duck.Target = nil
	duck.Alert.Enabled = false
	duck.State = "Patrol"
	pickPatrolPoint(duck)
	if player then
		local set = chasers[player]
		if set then
			set[duck] = nil
		end
		refreshChased(player)
		if notify and player.Parent then
			Net.Fire(player, "Effect", "DuckLost", { Duck = duck.Stats.Name })
		end
	end
end

local function catch(duck: Duck, player: Player, root: BasePart)
	local away = flat(root.Position - duck.Position)
	away = if away.Magnitude > 0.1 then away.Unit else duck.Heading
	local fling = away * GameConfig.CatchFlingSpeed + Vector3.new(0, GameConfig.CatchFlingUp, 0)
	stopChase(duck, false)
	duck.State = "Celebrate"
	duck.StateUntil = os.clock() + 1.6
	duck.Sounds.Quack:Play()
	if RagdollService.Ragdoll(player, GameConfig.RagdollDuration, fling) then
		FoodService.DropCarry(player, root.Position)
		DataService.AddStat(player, "TimesCaught", 1)
		Net.Fire(player, "Effect", "Caught", { Duck = duck.Stats.Name })
		Net.FireAll("Effect", "Bonk", {
			Player = player.DisplayName,
			UserId = player.UserId,
			Duck = duck.Stats.Name,
			Position = root.Position,
		})
	end
end

local function findTarget(duck: Duck): Player?
	local sightRange = duck.Stats.SightRange * EventService.GetDuckSightMultiplier()
	local best, bestScore = nil, math.huge
	for _, player in Players:GetPlayers() do
		local ok, root = isHuntable(duck, player)
		if not ok or not root then
			continue
		end
		if canSee(duck, root, sightRange, true) then
			-- Prefer players carrying lots of snacks.
			local carried = FoodService.GetCarry(player).Total
			local score = (root.Position - duck.Position).Magnitude - carried * 0.5
			if score < bestScore then
				best, bestScore = player, score
			end
		end
	end
	return best
end

local function detectTick()
	local now = os.clock()
	for _, duck in ducks do
		if duck.State == "Celebrate" or duck.State == "Idle" then
			if now >= duck.StateUntil then
				duck.State = "Patrol"
				pickPatrolPoint(duck)
			end
		end

		if duck.State == "Chase" then
			local player = duck.Target :: Player
			local ok, root = isHuntable(duck, player)
			if not ok or not root then
				-- Only say "you escaped" if they weren't just bonked by another duck.
				stopChase(duck, player.Parent ~= nil and not RagdollService.IsRagdolled(player.Character))
				continue
			end
			local chaseRange = duck.Stats.SightRange * EventService.GetDuckSightMultiplier() * 1.4
			if canSee(duck, root, chaseRange, false) then
				duck.LastSeenAt = now
				duck.LastSeenPos = root.Position
			elseif now - duck.LastSeenAt > duck.Stats.GiveUpTime then
				stopChase(duck, true)
			end
		elseif duck.State == "Patrol" or duck.State == "Idle" then
			local target = findTarget(duck)
			if target then
				startChase(duck, target)
			elseif duck.State == "Patrol" then
				local reached = (flat(duck.PatrolPoint - duck.Position)).Magnitude < 3
				if reached or now > duck.PatrolUntil then
					if rng:NextNumber() < 0.3 then
						duck.State = "Idle"
						duck.StateUntil = now + rng:NextNumber(1, 2.5)
					else
						pickPatrolPoint(duck)
					end
				end
			end
		end

		if now >= duck.NextQuack and duck.State ~= "Chase" then
			duck.NextQuack = now + rng:NextNumber(6, 14)
			duck.Sounds.Quack:Play()
		end
	end
end

-- Picks the first clear direction near `desired` (simple whisker steering).
local function steer(duck: Duck, desired: Vector3): Vector3
	local lookAhead = duck.Radius * 2 + 4
	local bounds = MapLayout.GetZoneBounds(duck.ZoneId)
	for _, angle in STEER_ANGLES do
		local direction = rotateY(desired, angle)
		local probe = duck.Position + direction * lookAhead
		local inside = probe.X > bounds.Min.X + duck.Radius
			and probe.X < bounds.Max.X - duck.Radius
			and probe.Z > bounds.Min.Z + duck.Radius
			and probe.Z < bounds.Max.Z - duck.Radius
		if inside and not MapBuilder.IsBlocked(duck.ZoneId, probe, duck.Radius * 0.7) then
			return direction
		end
	end
	return desired
end

local function moveDuck(duck: Duck, dt: number)
	local speedMultiplier = EventService.GetDuckSpeedMultiplier()
	local goal: Vector3? = nil
	local speed = 0
	if duck.State == "Chase" then
		speed = duck.Stats.ChaseSpeed * speedMultiplier
		goal = duck.LastSeenPos
		local root = duck.Target and targetRoot(duck.Target)
		if root and os.clock() - duck.LastSeenAt < 0.3 then
			goal = root.Position
		end
	elseif duck.State == "Patrol" then
		speed = duck.Stats.PatrolSpeed * speedMultiplier
		goal = duck.PatrolPoint
	end

	local moving = false
	if goal then
		local toGoal = flat(goal - duck.Position)
		local distance = toGoal.Magnitude
		if distance > 0.5 then
			moving = true
			local direction = steer(duck, toGoal.Unit)
			local blended = duck.Heading:Lerp(direction, math.min(1, dt * 8))
			duck.Heading = if blended.Magnitude > 0.01 then blended.Unit else direction
			local step = math.min(speed * dt, distance)
			local nextPos = MapLayout.ClampToZone(duck.ZoneId, duck.Position + duck.Heading * step, duck.Radius)
			if not MapBuilder.IsBlocked(duck.ZoneId, nextPos, duck.Radius * 0.6) then
				duck.Position = nextPos
			else
				-- Slide along whichever axis is free.
				local slideX = Vector3.new(nextPos.X, nextPos.Y, duck.Position.Z)
				local slideZ = Vector3.new(duck.Position.X, nextPos.Y, nextPos.Z)
				if not MapBuilder.IsBlocked(duck.ZoneId, slideX, duck.Radius * 0.6) then
					duck.Position = slideX
				elseif not MapBuilder.IsBlocked(duck.ZoneId, slideZ, duck.Radius * 0.6) then
					duck.Position = slideZ
				end
			end
		end
	end

	-- Waddle: bob up and down and rock side to side while moving.
	local t = os.clock()
	local bob, roll = 0, 0
	if moving then
		bob = math.abs(math.sin(t * speed * 0.6)) * 0.5 * duck.Stats.Scale
		roll = math.sin(t * speed * 0.3) * 0.14
	elseif duck.State == "Celebrate" then
		bob = math.abs(math.sin(t * 14)) * 2 * duck.Stats.Scale -- happy bonk hop
	end
	duck.Align.Position = duck.Position + Vector3.new(0, duck.Hover + bob, 0)
	duck.Orient.CFrame = CFrame.lookAt(Vector3.zero, duck.Heading) * CFrame.Angles(0, 0, roll)

	local waddle = duck.Sounds.Waddle
	if moving and not waddle.IsPlaying then
		waddle:Play()
	elseif not moving and waddle.IsPlaying then
		waddle:Stop()
	end
	waddle.PlaybackSpeed = SoundConfig.Duck.Waddle.Speed * math.max(1, speed / 12)

	-- Catch check every frame for responsive bonks.
	if duck.State == "Chase" and duck.Target then
		local root = targetRoot(duck.Target)
		if root then
			local offset = flat(root.Position - duck.Position)
			if offset.Magnitude <= duck.Stats.CatchRadius and math.abs(root.Position.Y - duck.Position.Y) < 14 then
				local ok = isHuntable(duck, duck.Target)
				if ok then
					catch(duck, duck.Target, root)
				end
			end
		end
	end
end

function DuckService.Start()
	losParams.FilterDescendantsInstances = MapBuilder.StaticGeometry
	for _, zone in ZoneConfig.List do
		for index = 1, zone.Duck.Count do
			spawnDuck(zone, index)
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		for _, duck in ducks do
			moveDuck(duck, dt)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(DETECT_TICK)
			detectTick()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, duck in ducks do
			if duck.Target == player then
				stopChase(duck, false)
			end
		end
		chasers[player] = nil
	end)
end

return DuckService
