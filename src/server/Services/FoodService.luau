-- Snacks: spawning in zones, magnet pickup, snack-machine clicks, the stack of
-- snacks on your back, and dropping it all when a duck bonks you.
--
-- Pickup is server-driven (players just walk near snacks), so it can't be
-- exploited by firing remotes and works the same with any input device.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FoodConfig = require(Shared.Config.FoodConfig)
local GameConfig = require(Shared.Config.GameConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local Formulas = require(Shared.Formulas)
local MapLayout = require(Shared.MapLayout)
local Make = require(Shared.Util.Make)
local Net = require(Shared.Net)
local WeightedRandom = require(Shared.Util.WeightedRandom)

local DataService = require(script.Parent.DataService)
local MapBuilder = require(script.Parent.MapBuilder)

type FoodEntry = {
	Part: BasePart,
	FoodId: string,
	Count: number,
	ZoneId: string,
	Natural: boolean, -- counts toward the zone's spawn cap
	ReadyAt: number, -- can't be picked up before this (while falling)
}

type Carry = {
	Total: number,
	Items: { [string]: number },
}

local FoodService = {}

local rng = Random.new()
local foodsByZone: { [string]: { [BasePart]: FoodEntry } } = {}
local naturalCount: { [string]: number } = {}
local carries: { [Player]: Carry } = {}
local lastClick: { [Player]: number } = {}

local PICKUP_TICK = 0.1

local function getCarry(player: Player): Carry
	local carry = carries[player]
	if not carry then
		carry = { Total = 0, Items = {} }
		carries[player] = carry
	end
	return carry
end

local function rootOf(player: Player): BasePart?
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

local function canAct(player: Player): boolean
	local character = player.Character
	return character ~= nil and not character:GetAttribute("Ragdolled")
end

-- Rebuilds the snack tower welded to the player's back.
local function updateCarryVisual(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local old = character:FindFirstChild("SnackStack")
	if old then
		old:Destroy()
	end
	local carry = getCarry(player)
	if carry.Total <= 0 then
		return
	end

	local stack = Make.Instance("Model", { Name = "SnackStack" })
	-- Show the most valuable snacks at the top of the tower.
	local order = {}
	for foodId, count in carry.Items do
		table.insert(order, { FoodId = foodId, Count = count })
	end
	table.sort(order, function(a, b)
		return FoodConfig[a.FoodId].Value < FoodConfig[b.FoodId].Value
	end)
	local shown = 0
	local maxShown = math.min(GameConfig.MaxCarryVisual, carry.Total)
	local height = 0
	for _, entry in order do
		local food = FoodConfig[entry.FoodId]
		for _ = 1, entry.Count do
			if shown >= maxShown then
				break
			end
			shown += 1
			local size = 1.2
			local part = Make.Part({
				Name = "Snack",
				Anchored = false,
				Massless = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Size = Vector3.new(size * 1.3, size, size * 1.3),
				Color = food.Color,
				Material = if food.Golden then Enum.Material.Neon else Enum.Material.SmoothPlastic,
				Parent = stack,
			})
			local wobble = CFrame.Angles(0, math.rad(rng:NextNumber(-25, 25)), math.rad(rng:NextNumber(-8, 8)))
			Make.Instance("Weld", {
				Part0 = torso,
				Part1 = part,
				C0 = CFrame.new(0, -torso.Size.Y / 2 + height + size / 2, torso.Size.Z / 2 + 0.9) * wobble,
				Parent = part,
			})
			height += size * 0.95
		end
	end
	if carry.Total > maxShown then
		Make.Billboard(
			stack:FindFirstChildWhichIsA("BasePart") :: BasePart,
			Vector2.new(4, 1.5),
			Vector3.new(0, height + 1, 0),
			"x" .. carry.Total,
			{ TextColor3 = Color3.fromRGB(255, 230, 90) }
		)
	end
	stack.Parent = character
end

local function setCarryAttributes(player: Player)
	local data = DataService.Get(player)
	player:SetAttribute("Carry", getCarry(player).Total)
	if data then
		player:SetAttribute("CarryCapacity", Formulas.CarryCapacity(data))
	end
end

local function onCarryChanged(player: Player)
	setCarryAttributes(player)
	updateCarryVisual(player)
end

-- Adds up to `count` snacks; returns how many fit.
function FoodService.AddToCarry(player: Player, foodId: string, count: number): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local carry = getCarry(player)
	local space = Formulas.CarryCapacity(data) - carry.Total
	local added = math.clamp(count, 0, math.max(space, 0))
	if added > 0 then
		carry.Items[foodId] = (carry.Items[foodId] or 0) + added
		carry.Total += added
		DataService.AddStat(player, "SnacksCollected", added)
		onCarryChanged(player)
	end
	return added
end

function FoodService.GetCarry(player: Player): Carry
	return getCarry(player)
end

-- Empties the player's carry and returns what they had.
function FoodService.TakeCarry(player: Player): ({ [string]: number }, number)
	local carry = getCarry(player)
	local items, total = carry.Items, carry.Total
	carries[player] = { Total = 0, Items = {} }
	onCarryChanged(player)
	return items, total
end

local function createFoodPart(food: FoodConfig.Food, count: number): BasePart
	local size = food.Size
	local shape = if food.Shape == "Ball"
		then Enum.PartType.Ball
		elseif food.Shape == "Cylinder" then Enum.PartType.Cylinder
		else Enum.PartType.Block
	local partSize = if food.Shape == "Cylinder"
		then Vector3.new(size * 0.45, size, size)
		elseif food.Shape == "Ball" then Vector3.new(size, size, size)
		else Vector3.new(size, size * 0.6, size * 0.8)
	local part = Make.Part({
		Name = food.Id,
		Shape = shape,
		Size = partSize,
		Color = food.Color,
		Material = if food.Golden then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	Make.Billboard(part, Vector2.new(3, 3), Vector3.new(0, size * 0.9 + 0.8, 0), food.Emoji, {
		TextStrokeTransparency = 1,
	}).MaxDistance = 90
	if food.Golden then
		Make.Instance("PointLight", { Color = food.Color, Range = 10, Brightness = 2, Parent = part })
		Make.Instance("Sparkles", { SparkleColor = food.Color, Parent = part })
	end
	if count > 1 then
		Make.Billboard(part, Vector2.new(3, 1.2), Vector3.new(0, size * 0.9 + 2.6, 0), "x" .. count, {
			Name = "CountLabel",
			TextColor3 = Color3.fromRGB(255, 230, 90),
		})
	end
	part:SetAttribute("FoodId", food.Id)
	CollectionService:AddTag(part, "Food")
	return part
end

local function removeFood(entry: FoodEntry)
	local zoneFoods = foodsByZone[entry.ZoneId]
	if zoneFoods and zoneFoods[entry.Part] then
		zoneFoods[entry.Part] = nil
		if entry.Natural then
			naturalCount[entry.ZoneId] -= 1
		end
	end
	entry.Part:Destroy()
end

-- Spawns one snack lying in a zone. `dropFrom` makes it fall from that
-- height first (golden rain, dropped loot).
local function spawnFood(
	zoneId: string,
	foodId: string,
	position: Vector3,
	count: number,
	natural: boolean,
	lifetime: number?,
	dropFrom: number?
): FoodEntry
	local food = FoodConfig[foodId]
	local part = createFoodPart(food, count)
	local restY = MapLayout.FloorY + food.Size / 2 + 1
	local target = CFrame.new(position.X, restY, position.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local readyAt = os.clock()
	if dropFrom then
		part.CFrame = target + Vector3.new(0, dropFrom, 0)
		local fallTime = math.clamp(dropFrom / 40, 0.35, 1.4)
		TweenService:Create(part, TweenInfo.new(fallTime, Enum.EasingStyle.Bounce), { CFrame = target }):Play()
		readyAt += fallTime * 0.6
	else
		part.CFrame = target
	end
	part.Parent = MapBuilder.Folders.Food

	local entry: FoodEntry = {
		Part = part,
		FoodId = foodId,
		Count = count,
		ZoneId = zoneId,
		Natural = natural,
		ReadyAt = readyAt,
	}
	foodsByZone[zoneId][part] = entry
	if natural then
		naturalCount[zoneId] += 1
	end
	if lifetime then
		task.delay(lifetime, function()
			if foodsByZone[zoneId][part] then
				removeFood(entry)
			end
		end)
	end
	return entry
end

local function findSpawnPoint(zoneId: string, margin: number): Vector3?
	for _ = 1, 12 do
		local point = MapLayout.RandomPointInZone(zoneId, rng, margin)
		if not MapBuilder.IsBlocked(zoneId, point, 3) then
			return point
		end
	end
	return nil
end

-- Golden rain: drops `perZone` golden snacks into every zone.
function FoodService.SpawnGolden(perZone: number, lifetime: number)
	for _, zone in ZoneConfig.List do
		for _ = 1, perZone do
			local point = findSpawnPoint(zone.Id, 10)
			if point then
				spawnFood(zone.Id, zone.GoldenFood, point, 1, false, lifetime, rng:NextNumber(40, 70))
			end
		end
	end
end

-- Scatters everything the player is carrying around a position. Anyone
-- (including the victim) can pick it back up for a while.
function FoodService.DropCarry(player: Player, position: Vector3)
	local items, total = FoodService.TakeCarry(player)
	if total <= 0 then
		return
	end
	local zoneId = MapLayout.ZoneAt(position)
	if not zoneId then
		return -- dropped in the hub (shouldn't happen, ducks stay in zones)
	end
	local perPiece = math.max(1, math.ceil(total / GameConfig.MaxDroppedPieces))
	for foodId, count in items do
		local remaining = count
		while remaining > 0 do
			local pieceCount = math.min(perPiece, remaining)
			remaining -= pieceCount
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = rng:NextNumber(5, 12)
			local point = position + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			point = MapLayout.ClampToZone(zoneId, point, 4)
			spawnFood(zoneId, foodId, point, pieceCount, false, GameConfig.DroppedFoodLifetime, 8)
		end
	end
end

local function spawnLoop(zone: ZoneConfig.Zone)
	-- Start each zone half full so it never feels empty.
	for _ = 1, math.floor(zone.SpawnCap / 2) do
		local point = findSpawnPoint(zone.Id, 8)
		if point then
			spawnFood(zone.Id, WeightedRandom.Pick(zone.Foods, rng).Id, point, 1, true)
		end
	end
	while true do
		task.wait(zone.SpawnInterval)
		if naturalCount[zone.Id] < zone.SpawnCap then
			local point = findSpawnPoint(zone.Id, 8)
			if point then
				spawnFood(zone.Id, WeightedRandom.Pick(zone.Foods, rng).Id, point, 1, true, nil, 6)
			end
		end
	end
end

local function pickupTick()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		local root = rootOf(player)
		if not data or not root or not canAct(player) then
			continue
		end
		local zoneId = MapLayout.ZoneAt(root.Position)
		if not zoneId or not data.Zones[zoneId] then
			continue
		end
		local carry = getCarry(player)
		local capacity = Formulas.CarryCapacity(data)
		if carry.Total >= capacity then
			continue
		end
		local range = Formulas.PickupRange(data)
		local rootPosition = root.Position
		for part, entry in foodsByZone[zoneId] do
			if entry.ReadyAt > now then
				continue
			end
			local offset = part.Position - rootPosition
			if offset.X * offset.X + offset.Z * offset.Z > range * range or math.abs(offset.Y) > 10 then
				continue
			end
			local added = FoodService.AddToCarry(player, entry.FoodId, entry.Count)
			if added <= 0 then
				break
			end
			Net.Fire(player, "Effect", "Pickup", {
				FoodId = entry.FoodId,
				Count = added,
				Position = part.Position,
				Full = carry.Total >= capacity,
			})
			if added >= entry.Count then
				removeFood(entry)
			else
				entry.Count -= added
				local label = part:FindFirstChild("CountLabel")
				if label then
					(label:FindFirstChildOfClass("TextLabel") :: TextLabel).Text = "x" .. entry.Count
				end
			end
			if carry.Total >= capacity then
				break
			end
		end
	end
end

local function onMachineClicked(player: Player, machine: BasePart)
	local data = DataService.Get(player)
	local root = rootOf(player)
	if not data or not root or not canAct(player) then
		return
	end
	local zoneId = machine:GetAttribute("ZoneId")
	if not data.Zones[zoneId] then
		return
	end
	if (root.Position - machine.Position).Magnitude > GameConfig.MachineClickRange + 4 then
		return
	end
	local now = os.clock()
	if now - (lastClick[player] or 0) < GameConfig.ClickCooldown then
		return
	end
	lastClick[player] = now

	local foodId = machine:GetAttribute("FoodId")
	local added = FoodService.AddToCarry(player, foodId, Formulas.ClickPower(data))
	local carry = getCarry(player)
	Net.Fire(player, "Effect", "MachineClick", {
		FoodId = foodId,
		Count = added,
		Position = machine.Position + Vector3.new(0, 4, 0),
		Full = carry.Total >= Formulas.CarryCapacity(data),
	})
end

function FoodService.Start()
	for _, zone in ZoneConfig.List do
		foodsByZone[zone.Id] = {}
		naturalCount[zone.Id] = 0
		task.spawn(spawnLoop, zone)
	end

	for _, machine in MapBuilder.Machines do
		local detector = machine:FindFirstChildOfClass("ClickDetector")
		if detector then
			detector.MouseClick:Connect(function(player)
				onMachineClicked(player, machine)
			end)
		end
	end

	task.spawn(function()
		while true do
			task.wait(PICKUP_TICK)
			pickupTick()
		end
	end)

	DataService.Changed:Connect(function(player, key)
		if key == "Upgrades" then
			setCarryAttributes(player)
		end
	end)
	DataService.Loaded:Connect(function(player)
		setCarryAttributes(player)
	end)

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function()
			-- Respawning loses whatever you were carrying.
			carries[player] = { Total = 0, Items = {} }
			setCarryAttributes(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		carries[player] = nil
		lastClick[player] = nil
	end)
end

return FoodService
