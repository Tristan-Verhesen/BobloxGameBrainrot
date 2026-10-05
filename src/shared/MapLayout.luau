--!strict
-- Map geometry shared by the server (building, AI, validation) and the client
-- (gates, zone labels). The hub is a square centered on the origin; each zone
-- is a rectangle attached to one side of the hub.

local ZoneConfig = require(script.Parent.Config.ZoneConfig)

export type Bounds = {
	Min: Vector3,
	Max: Vector3,
	Center: Vector3,
	Size: Vector3,
	Direction: Vector3,
}

local MapLayout = {
	HubHalf = 80, -- hub is 160 x 160
	ZoneDepth = 180, -- how far a zone extends away from the hub
	ZoneHalfWidth = 80,
	GateWidth = 30,
	WallHeight = 28,
	FloorY = 0,
	CapyPosition = Vector3.new(0, 0, 0),
	SpawnPosition = Vector3.new(-52, 0, 52),
	EggArea = Vector3.new(52, 0, 52),
	ShopArea = Vector3.new(52, 0, -52),
	LeaderboardArea = Vector3.new(-52, 0, -52),
}

local boundsCache: { [string]: Bounds } = {}

function MapLayout.GetZoneBounds(zoneId: string): Bounds
	local cached = boundsCache[zoneId]
	if cached then
		return cached
	end
	local zone = ZoneConfig.ById[zoneId]
	assert(zone, "Unknown zone " .. tostring(zoneId))
	local direction = zone.Direction.Unit
	local center = direction * (MapLayout.HubHalf + MapLayout.ZoneDepth / 2)
	local size
	if math.abs(direction.X) > 0.5 then
		size = Vector3.new(MapLayout.ZoneDepth, 0, MapLayout.ZoneHalfWidth * 2)
	else
		size = Vector3.new(MapLayout.ZoneHalfWidth * 2, 0, MapLayout.ZoneDepth)
	end
	local bounds = {
		Min = Vector3.new(center.X - size.X / 2, MapLayout.FloorY, center.Z - size.Z / 2),
		Max = Vector3.new(center.X + size.X / 2, MapLayout.FloorY, center.Z + size.Z / 2),
		Center = Vector3.new(center.X, MapLayout.FloorY, center.Z),
		Size = size,
		Direction = direction,
	}
	boundsCache[zoneId] = bounds
	return bounds
end

function MapLayout.IsInHub(position: Vector3): boolean
	return math.abs(position.X) <= MapLayout.HubHalf and math.abs(position.Z) <= MapLayout.HubHalf
end

-- Returns the zone id at a position, or nil for the hub / outside the map.
function MapLayout.ZoneAt(position: Vector3): string?
	for _, zone in ZoneConfig.List do
		local bounds = MapLayout.GetZoneBounds(zone.Id)
		if
			position.X >= bounds.Min.X
			and position.X <= bounds.Max.X
			and position.Z >= bounds.Min.Z
			and position.Z <= bounds.Max.Z
		then
			return zone.Id
		end
	end
	return nil
end

function MapLayout.ClampToZone(zoneId: string, position: Vector3, margin: number): Vector3
	local bounds = MapLayout.GetZoneBounds(zoneId)
	return Vector3.new(
		math.clamp(position.X, bounds.Min.X + margin, bounds.Max.X - margin),
		position.Y,
		math.clamp(position.Z, bounds.Min.Z + margin, bounds.Max.Z - margin)
	)
end

function MapLayout.RandomPointInZone(zoneId: string, rng: Random, margin: number): Vector3
	local bounds = MapLayout.GetZoneBounds(zoneId)
	return Vector3.new(
		rng:NextNumber(bounds.Min.X + margin, bounds.Max.X - margin),
		MapLayout.FloorY,
		rng:NextNumber(bounds.Min.Z + margin, bounds.Max.Z - margin)
	)
end

-- Point on the hub edge where a zone's gate sits.
function MapLayout.GatePosition(zoneId: string): Vector3
	local zone = ZoneConfig.ById[zoneId]
	return zone.Direction.Unit * MapLayout.HubHalf
end

-- Converts a local offset (Forward = away from the hub, Right = sideways) into
-- a world position inside a zone. Used to place machines and duck spawns.
function MapLayout.ZoneLocalToWorld(zoneId: string, forward: number, right: number): Vector3
	local bounds = MapLayout.GetZoneBounds(zoneId)
	local direction = bounds.Direction
	local rightVector = Vector3.new(-direction.Z, 0, direction.X)
	local start = direction * MapLayout.HubHalf
	return Vector3.new(start.X, MapLayout.FloorY, start.Z) + direction * forward + rightVector * right
end

return MapLayout
