-- Builds the greybox map at runtime: hub, zones, walls, gates, props, snack
-- machines, egg stands, shop stalls, leaderboards and lighting.
--
-- Everything is generated from MapLayout + ZoneConfig, so changing a zone's
-- size or adding a zone in config is enough to rebuild the map.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local FoodConfig = require(Config.FoodConfig)
local GameConfig = require(Config.GameConfig)
local PetConfig = require(Config.PetConfig)
local RarityConfig = require(Config.RarityConfig)
local ZoneConfig = require(Config.ZoneConfig)
local Format = require(Shared.Util.Format)
local Make = require(Shared.Util.Make)
local MapLayout = require(Shared.MapLayout)
local WeightedRandom = require(Shared.Util.WeightedRandom)

export type Obstacle = { Center: Vector3, Half: Vector3 }

local MapBuilder = {
	Map = nil :: Folder?,
	Folders = {} :: { [string]: Folder },
	Obstacles = {} :: { [string]: { Obstacle } }, -- [zoneId]
	Machines = {} :: { BasePart },
	Gates = {} :: { [string]: BasePart },
	EggStands = {} :: { { Part: BasePart, EggId: string, Prompt: ProximityPrompt } },
	Boards = {} :: { [string]: { Rows: { TextLabel }, Status: TextLabel } },
	Spawn = nil :: SpawnLocation?,
	StaticGeometry = {} :: { Instance }, -- for duck line-of-sight raycasts
}

local WALL_THICKNESS = 4

-- World-space XZ bounding box of a part (handles 90 degree rotations).
local function aabbOf(part: BasePart, padding: number): Obstacle
	local cf = part.CFrame
	local half = part.Size / 2
	local function extent(axis: Vector3): number
		return math.abs(cf.RightVector:Dot(axis)) * half.X
			+ math.abs(cf.UpVector:Dot(axis)) * half.Y
			+ math.abs(cf.LookVector:Dot(axis)) * half.Z
	end
	return {
		Center = Vector3.new(cf.Position.X, 0, cf.Position.Z),
		Half = Vector3.new(extent(Vector3.xAxis) + padding, 0, extent(Vector3.zAxis) + padding),
	}
end

local function overlaps(a: Obstacle, b: Obstacle): boolean
	return math.abs(a.Center.X - b.Center.X) < a.Half.X + b.Half.X
		and math.abs(a.Center.Z - b.Center.Z) < a.Half.Z + b.Half.Z
end

local function folder(name: string, parent: Instance): Folder
	local f = Make.Instance("Folder", { Name = name, Parent = parent })
	MapBuilder.Folders[name] = f
	return f
end

local function buildLighting()
	Make.Instance("Atmosphere", {
		Density = 0.28,
		Offset = 0.1,
		Color = Color3.fromRGB(255, 220, 240),
		Decay = Color3.fromRGB(120, 110, 200),
		Glare = 0.3,
		Haze = 1.2,
		Parent = Lighting,
	})
	Make.Instance("BloomEffect", { Intensity = 0.6, Size = 24, Threshold = 1.6, Parent = Lighting })
	Make.Instance("ColorCorrectionEffect", {
		Name = "MapColor",
		Saturation = 0.2,
		Contrast = 0.05,
		Parent = Lighting,
	})
	Make.Instance("SunRaysEffect", { Intensity = 0.08, Spread = 0.6, Parent = Lighting })
	if not Lighting:FindFirstChildOfClass("Sky") then
		Make.Instance("Sky", { Parent = Lighting })
	end
end

-- A wall segment between two XZ points.
local function wall(from: Vector3, to: Vector3, color: Color3, parent: Instance): Part
	local mid = (from + to) / 2
	local length = (to - from).Magnitude
	local direction = (to - from).Unit
	local part = Make.Part({
		Name = "Wall",
		Size = Vector3.new(WALL_THICKNESS, MapLayout.WallHeight, length + WALL_THICKNESS),
		CFrame = CFrame.lookAt(
			Vector3.new(mid.X, MapLayout.FloorY + MapLayout.WallHeight / 2, mid.Z),
			Vector3.new(mid.X, MapLayout.FloorY + MapLayout.WallHeight / 2, mid.Z) + direction
		),
		Color = color,
		Parent = parent,
	})
	return part
end

local function buildHub()
	local hubFolder = MapBuilder.Folders.Hub
	local half = MapLayout.HubHalf

	Make.Part({
		Name = "HubFloor",
		Size = Vector3.new(half * 2, 4, half * 2),
		Position = Vector3.new(0, MapLayout.FloorY - 2, 0),
		Color = Color3.fromRGB(235, 220, 255),
		Parent = hubFolder,
	})

	-- Colored paths from the capy to each gate.
	for _, zone in ZoneConfig.List do
		local direction = zone.Direction.Unit
		local length = half - 8
		local center = direction * (8 + length / 2)
		Make.Part({
			Name = "Path_" .. zone.Id,
			Size = if math.abs(direction.X) > 0.5
				then Vector3.new(length, 0.2, MapLayout.GateWidth - 6)
				else Vector3.new(MapLayout.GateWidth - 6, 0.2, length),
			Position = Vector3.new(center.X, MapLayout.FloorY + 0.1, center.Z),
			Color = zone.FloorColor,
			CanCollide = false,
			Parent = hubFolder,
		})
	end

	-- Hub walls with a gap for each zone's gate.
	local wallColor = Color3.fromRGB(170, 140, 230)
	local gap = MapLayout.GateWidth / 2
	for _, zone in ZoneConfig.List do
		local d = zone.Direction.Unit
		local side = Vector3.new(-d.Z, 0, d.X)
		local edge = d * (half + WALL_THICKNESS / 2)
		MapBuilder.StaticGeometry[#MapBuilder.StaticGeometry + 1] =
			wall(edge + side * gap, edge + side * half, wallColor, MapBuilder.Folders.Walls)
		MapBuilder.StaticGeometry[#MapBuilder.StaticGeometry + 1] =
			wall(edge - side * gap, edge - side * half, wallColor, MapBuilder.Folders.Walls)
	end

	-- Spawn pad, facing the capybara.
	local spawnPos = MapLayout.SpawnPosition + Vector3.new(0, 0.5, 0)
	MapBuilder.Spawn = Make.Part({
		Name = "Spawn",
		Size = Vector3.new(14, 1, 14),
		CFrame = CFrame.lookAt(spawnPos, Vector3.new(0, spawnPos.Y, 0)),
		Color = Color3.fromRGB(255, 120, 200),
		Material = Enum.Material.Neon,
		Neutral = true,
		Duration = 0,
		CanCollide = true,
		Parent = hubFolder,
	}, nil, "SpawnLocation")

	local safeSign = Make.Part({
		Name = "SafeSign",
		Size = Vector3.new(24, 6, 1),
		CFrame = CFrame.lookAt(spawnPos + Vector3.new(0, 10, 0), Vector3.new(0, 10, 0)) * CFrame.new(0, 0, 9),
		Color = Color3.fromRGB(60, 40, 100),
		Parent = hubFolder,
	})
	Make.SurfaceText(safeSign, Enum.NormalId.Front, "🏠 CAPY HUB · SAFE ZONE 🏠")
	Make.SurfaceText(safeSign, Enum.NormalId.Back, "🏠 CAPY HUB · SAFE ZONE 🏠")
end

local function buildGate(zone: ZoneConfig.Zone)
	local d = zone.Direction.Unit
	local gatePos = d * (MapLayout.HubHalf + WALL_THICKNESS / 2)
	local facingHub = -d

	-- Arch sign over the gate (both sides).
	local signPos = Vector3.new(gatePos.X, MapLayout.FloorY + MapLayout.WallHeight + 3, gatePos.Z)
	local sign = Make.Part({
		Name = "GateSign_" .. zone.Id,
		Size = Vector3.new(MapLayout.GateWidth + 8, 6, WALL_THICKNESS),
		CFrame = CFrame.lookAt(signPos, signPos + facingHub),
		Color = zone.WallColor,
		Parent = MapBuilder.Folders.Gates,
	})
	local label = zone.Emoji .. " " .. string.upper(zone.Name)
	Make.SurfaceText(sign, Enum.NormalId.Front, label)
	Make.SurfaceText(sign, Enum.NormalId.Back, label)

	if zone.Cost <= 0 then
		return
	end

	local centerPos = Vector3.new(gatePos.X, MapLayout.FloorY + MapLayout.WallHeight / 2, gatePos.Z)
	local gate = Make.Part({
		Name = "Gate_" .. zone.Id,
		Size = Vector3.new(MapLayout.GateWidth, MapLayout.WallHeight, 2),
		CFrame = CFrame.lookAt(centerPos, centerPos + facingHub),
		Color = zone.FloorColor,
		Material = Enum.Material.ForceField,
		Transparency = 0.1,
		CanCollide = true,
		Parent = MapBuilder.Folders.Gates,
	})
	gate:SetAttribute("ZoneId", zone.Id)
	local lockText = string.format(
		"🔒 %s\n%s\n<font size=\"40\">walk up & press E</font>",
		string.upper(zone.Name),
		Format.Cash(zone.Cost)
	)
	Make.SurfaceText(gate, Enum.NormalId.Front, lockText, { Name = "LockText" })

	local attachment = Make.Instance("Attachment", {
		Position = Vector3.new(0, -MapLayout.WallHeight / 2 + 4, -2),
		Parent = gate,
	})
	Make.Instance("ProximityPrompt", {
		Name = "UnlockPrompt",
		ActionText = "Unlock " .. Format.Cash(zone.Cost),
		ObjectText = zone.Emoji .. " " .. zone.Name,
		HoldDuration = 0.25,
		MaxActivationDistance = 14,
		RequiresLineOfSight = false,
		KeyboardKeyCode = Enum.KeyCode.E,
		Parent = attachment,
	})
	CollectionService:AddTag(gate, "ZoneGate")
	MapBuilder.Gates[zone.Id] = gate
end

local function buildMachine(zone: ZoneConfig.Zone, forward: number, right: number, parent: Instance): BasePart
	local food = FoodConfig[zone.MachineFood]
	local bounds = MapLayout.GetZoneBounds(zone.Id)
	local rightVector = Vector3.new(-bounds.Direction.Z, 0, bounds.Direction.X)
	local position = MapLayout.ZoneLocalToWorld(zone.Id, forward, right) + Vector3.new(0, 7, 0)
	-- Face the zone's center line so players see the screen coming in.
	local facing = if right < 0 then rightVector else -rightVector

	local body = Make.Part({
		Name = "SnackMachine",
		Size = Vector3.new(10, 14, 7),
		CFrame = CFrame.lookAt(position, position + facing),
		Color = zone.WallColor,
		Parent = parent,
	})
	local screen = Make.Part({
		Name = "Screen",
		Size = Vector3.new(8, 8, 0.4),
		CFrame = body.CFrame * CFrame.new(0, 1.5, -3.6),
		Color = food.Color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = body,
	})
	Make.SurfaceText(
		screen,
		Enum.NormalId.Front,
		string.format("%s\n%s\n<font size=\"28\">CLICK ME!</font>", food.Emoji, zone.MachineName),
		{ TextColor3 = Color3.new(1, 1, 1) }
	)
	Make.Instance("ClickDetector", {
		MaxActivationDistance = GameConfig.MachineClickRange,
		Parent = body,
	})
	body:SetAttribute("ZoneId", zone.Id)
	body:SetAttribute("FoodId", zone.MachineFood)
	CollectionService:AddTag(body, "SnackMachine")
	table.insert(MapBuilder.Machines, body)
	return body
end

local function buildZone(zone: ZoneConfig.Zone)
	local bounds = MapLayout.GetZoneBounds(zone.Id)
	local zoneFolder = Make.Instance("Folder", { Name = zone.Id, Parent = MapBuilder.Folders.Zones })
	local obstacles: { Obstacle } = {}
	MapBuilder.Obstacles[zone.Id] = obstacles

	Make.Part({
		Name = "Floor",
		Size = Vector3.new(bounds.Size.X, 4, bounds.Size.Z),
		Position = Vector3.new(bounds.Center.X, MapLayout.FloorY - 2, bounds.Center.Z),
		Color = zone.FloorColor,
		Parent = zoneFolder,
	})

	-- Outer walls on the three sides that don't touch the hub.
	local d = bounds.Direction
	local side = Vector3.new(-d.Z, 0, d.X)
	local near = d * MapLayout.HubHalf
	local far = d * (MapLayout.HubHalf + MapLayout.ZoneDepth + WALL_THICKNESS / 2)
	local halfWidth = MapLayout.ZoneHalfWidth + WALL_THICKNESS / 2
	local walls = {
		wall(near + side * halfWidth, far + side * halfWidth, zone.WallColor, zoneFolder),
		wall(near - side * halfWidth, far - side * halfWidth, zone.WallColor, zoneFolder),
		wall(far + side * halfWidth, far - side * halfWidth, zone.WallColor, zoneFolder),
	}
	for _, w in walls do
		table.insert(MapBuilder.StaticGeometry, w)
	end

	buildGate(zone)

	-- Snack machines first so props never spawn on top of them.
	local machineSpots = {
		{ MapLayout.ZoneDepth * 0.36, -MapLayout.ZoneHalfWidth + 14 },
		{ MapLayout.ZoneDepth * 0.74, MapLayout.ZoneHalfWidth - 14 },
	}
	for _, spot in machineSpots do
		local machine = buildMachine(zone, spot[1], spot[2], zoneFolder)
		table.insert(obstacles, aabbOf(machine, 0))
		table.insert(MapBuilder.StaticGeometry, machine)
	end

	-- Giant snack-box props to hide behind. Seeded so the layout is the same
	-- on every server.
	local rng = Random.new(zone.Order * 7919)
	local placed = 0
	local tries = 0
	local emojis = {}
	for _, entry in zone.Foods do
		table.insert(emojis, FoodConfig[entry.Id].Emoji)
	end
	while placed < zone.ObstacleCount and tries < zone.ObstacleCount * 40 do
		tries += 1
		local width = rng:NextInteger(8, 16)
		local depth = rng:NextInteger(8, 16)
		local height = rng:NextInteger(12, 24)
		local forward = rng:NextNumber(32, MapLayout.ZoneDepth - 14)
		local right = rng:NextNumber(-MapLayout.ZoneHalfWidth + 14, MapLayout.ZoneHalfWidth - 14)
		local base = MapLayout.ZoneLocalToWorld(zone.Id, forward, right)
		local candidate: Obstacle = {
			Center = Vector3.new(base.X, 0, base.Z),
			Half = Vector3.new(width / 2 + 7, 0, depth / 2 + 7), -- keep corridors between props
		}
		local blocked = false
		for _, other in obstacles do
			if overlaps(candidate, other) then
				blocked = true
				break
			end
		end
		if not blocked then
			placed += 1
			local prop = Make.Part({
				Name = "SnackBox",
				Size = Vector3.new(width, height, depth),
				Position = Vector3.new(base.X, MapLayout.FloorY + height / 2, base.Z),
				Color = zone.PropColors[rng:NextInteger(1, #zone.PropColors)],
				Parent = MapBuilder.Folders.Obstacles,
			})
			local emoji = emojis[rng:NextInteger(1, #emojis)]
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
				Make.SurfaceText(prop, face, emoji, { TextTransparency = 0.15, TextStrokeTransparency = 1 })
			end
			table.insert(obstacles, aabbOf(prop, 0))
			table.insert(MapBuilder.StaticGeometry, prop)
		end
	end
end

local function oddsText(egg: PetConfig.Egg): string
	local chances = WeightedRandom.Chances(egg.Pets)
	local lines = {}
	for index, entry in egg.Pets do
		local pet = PetConfig.Pets[entry.Id]
		local rarity = RarityConfig[pet.Rarity]
		table.insert(
			lines,
			string.format(
				"%s %s %s",
				pet.Emoji,
				Make.Colored(pet.Name, rarity.Color),
				Make.Colored(Format.Percent(chances[index]), Color3.fromRGB(230, 230, 230))
			)
		)
	end
	return table.concat(lines, "\n")
end

local function buildEggs()
	local area = MapLayout.EggArea
	for index, egg in PetConfig.Eggs do
		local position = area + Vector3.new((index - 2) * 18, 0, 6)
		local pedestal = Make.Part({
			Name = "EggStand_" .. egg.Id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 10, 10),
			CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(70, 50, 110),
			Parent = MapBuilder.Folders.Eggs,
		})
		local eggPart = Make.Ellipsoid({
			Name = "Egg",
			Size = Vector3.new(6, 8, 6),
			Position = position + Vector3.new(0, 7, 0),
			Color = egg.Color,
			Material = Enum.Material.SmoothPlastic,
			Parent = pedestal,
		})
		Make.Instance("PointLight", { Color = egg.Color, Range = 14, Brightness = 1.5, Parent = eggPart })

		local requiredZone = ZoneConfig.ById[egg.RequiredZone]
		local header = string.format(
			"<b>%s</b>\n%s",
			egg.Name,
			Make.Colored(Format.Cash(egg.Cost), Color3.fromRGB(120, 255, 140))
		)
		if requiredZone.Order > 1 then
			header ..= "\n" .. Make.Colored("Needs " .. requiredZone.Name, Color3.fromRGB(255, 170, 120))
		end
		local gui = Make.Instance("BillboardGui", {
			Size = UDim2.fromOffset(240, 230),
			StudsOffset = Vector3.new(0, 8, 0),
			MaxDistance = 70,
			LightInfluence = 0,
			Parent = eggPart,
		})
		Make.Instance("TextLabel", {
			Size = UDim2.new(1, 0, 0, 70),
			BackgroundTransparency = 1,
			Text = header,
			RichText = true,
			TextScaled = true,
			Font = Enum.Font.FredokaOne,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0,
			Parent = gui,
		})
		Make.Instance("TextLabel", {
			Position = UDim2.fromOffset(0, 74),
			Size = UDim2.new(1, 0, 1, -74),
			BackgroundColor3 = Color3.fromRGB(25, 20, 45),
			BackgroundTransparency = 0.35,
			Text = oddsText(egg),
			RichText = true,
			TextScaled = true,
			Font = Enum.Font.FredokaOne,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.5,
			Parent = gui,
		}, { Make.Instance("UICorner", { CornerRadius = UDim.new(0, 10) }) })

		local prompt = Make.Instance("ProximityPrompt", {
			Name = "HatchPrompt",
			ActionText = "Hatch " .. Format.Cash(egg.Cost),
			ObjectText = egg.Name,
			HoldDuration = 0,
			MaxActivationDistance = 12,
			RequiresLineOfSight = false,
			KeyboardKeyCode = Enum.KeyCode.E,
			Parent = pedestal,
		})
		pedestal:SetAttribute("EggId", egg.Id)
		table.insert(MapBuilder.EggStands, { Part = pedestal, EggId = egg.Id, Prompt = prompt })
	end
end

-- Stalls that open UI windows on the client (see client InteractController).
local function buildStall(name: string, text: string, window: string, position: Vector3, color: Color3)
	local facing = Vector3.new(0, position.Y, 0)
	local counter = Make.Part({
		Name = name,
		Size = Vector3.new(16, 5, 6),
		CFrame = CFrame.lookAt(position + Vector3.new(0, 2.5, 0), facing + Vector3.new(0, 2.5, 0)),
		Color = color,
		Parent = MapBuilder.Folders.Hub,
	})
	for _, x in { -7, 7 } do
		Make.Part({
			Name = "Pole",
			Size = Vector3.new(1, 10, 1),
			CFrame = counter.CFrame * CFrame.new(x, 7.5, 2),
			Color = Color3.fromRGB(240, 240, 240),
			Parent = counter,
		})
	end
	local roof = Make.Part({
		Name = "Roof",
		Size = Vector3.new(18, 4, 8),
		CFrame = counter.CFrame * CFrame.new(0, 14, 1),
		Color = color:Lerp(Color3.new(1, 1, 1), 0.3),
		Parent = counter,
	})
	Make.SurfaceText(roof, Enum.NormalId.Front, text)
	local prompt = Make.Instance("ProximityPrompt", {
		ActionText = "Open",
		ObjectText = text,
		HoldDuration = 0,
		MaxActivationDistance = 12,
		RequiresLineOfSight = false,
		KeyboardKeyCode = Enum.KeyCode.E,
		Parent = counter,
	})
	prompt:SetAttribute("OpensWindow", window)
end

local function buildBoard(boardId: string, title: string, position: Vector3)
	local center = position + Vector3.new(0, 12, 0)
	local board = Make.Part({
		Name = "Leaderboard_" .. boardId,
		Size = Vector3.new(18, 22, 1),
		CFrame = CFrame.lookAt(center, Vector3.new(0, center.Y, 0)),
		Color = Color3.fromRGB(40, 30, 70),
		Parent = MapBuilder.Folders.Boards,
	})
	Make.Part({
		Name = "Post",
		Size = Vector3.new(2, 2, 2),
		CFrame = board.CFrame * CFrame.new(0, -11, 0),
		Color = Color3.fromRGB(30, 20, 50),
		Parent = board,
	})
	local gui = Make.Instance("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Vector2.new(360, 440),
		LightInfluence = 0,
		Parent = board,
	})
	Make.Instance("TextLabel", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Text = title,
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 210, 70),
		TextStrokeTransparency = 0,
		Parent = gui,
	})
	local status = Make.Instance("TextLabel", {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "Loading...",
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(190, 180, 230),
		Parent = gui,
	})
	local rows = {}
	for index = 1, GameConfig.LeaderboardSize do
		rows[index] = Make.Instance("TextLabel", {
			Position = UDim2.fromOffset(10, 74 + (index - 1) * 36),
			Size = UDim2.new(1, -20, 0, 32),
			BackgroundColor3 = if index % 2 == 0 then Color3.fromRGB(55, 45, 90) else Color3.fromRGB(65, 55, 105),
			Text = "",
			RichText = true,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.FredokaOne,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = gui,
		}, {
			Make.Instance("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Make.Instance("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		})
	end
	MapBuilder.Boards[boardId] = { Rows = rows, Status = status }
end

function MapBuilder.Build()
	local map = Make.Instance("Folder", { Name = "Map", Parent = workspace })
	MapBuilder.Map = map
	for _, name in { "Hub", "Walls", "Gates", "Zones", "Obstacles", "Eggs", "Boards", "Food", "Ducks", "Capybara" } do
		folder(name, map)
	end

	buildLighting()
	buildHub()
	for _, zone in ZoneConfig.List do
		buildZone(zone)
	end
	buildEggs()
	buildStall(
		"ShopStall",
		"🛒 UPGRADE SHOP",
		"Shop",
		MapLayout.ShopArea + Vector3.new(8, 0, 4),
		Color3.fromRGB(70, 180, 255)
	)
	buildStall(
		"RebirthAltar",
		"🔁 REBIRTH ALTAR",
		"Rebirth",
		MapLayout.ShopArea + Vector3.new(-14, 0, -10),
		Color3.fromRGB(255, 90, 160)
	)
	buildBoard("TotalFed", "🍔 TOP FEEDERS", MapLayout.LeaderboardArea + Vector3.new(-6, 0, 14))
	buildBoard("Rebirths", "🔁 TOP REBIRTHS", MapLayout.LeaderboardArea + Vector3.new(14, 0, -6))
end

-- True if a point (with radius) is inside any prop of a zone.
function MapBuilder.IsBlocked(zoneId: string, position: Vector3, radius: number): boolean
	local obstacles = MapBuilder.Obstacles[zoneId]
	if not obstacles then
		return false
	end
	for _, obstacle in obstacles do
		if
			math.abs(position.X - obstacle.Center.X) < obstacle.Half.X + radius
			and math.abs(position.Z - obstacle.Center.Z) < obstacle.Half.Z + radius
		then
			return true
		end
	end
	return false
end

return MapBuilder
