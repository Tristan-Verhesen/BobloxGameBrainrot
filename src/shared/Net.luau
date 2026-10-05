--!strict
-- Every remote in the game is declared here. The server creates them on start;
-- clients wait for them. Server-side handlers go through Net.Handle, which adds
-- per-player rate limiting and error isolation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Server -> client
local EVENTS = {
	"DataChanged", -- (key, value) a top-level save key changed
	"Notify", -- (text, kind) toast message
	"Effect", -- (effectName, payload) one-shot juice: popups, shakes, sounds
	"Ragdoll", -- (enabled, flingVelocity)
	"HatchResult", -- (eggId, petId, uid)
	"Announce", -- (text, color) big server-wide banner
}

-- Client -> server (all return ok: boolean, message: string?)
local FUNCTIONS = {
	"GetData",
	"BuyUpgrade",
	"UnlockZone",
	"Rebirth",
	"HatchEgg",
	"EquipPet",
	"UnequipPet",
	"EquipBest",
	"DeletePet",
	"EquipTitle",
	"ClaimDaily",
	"ClaimPlaytime",
}

local Net = {}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.Event(name: string): RemoteEvent
	local remote = folder:WaitForChild(name, 10)
	assert(remote and remote:IsA("RemoteEvent"), "Unknown RemoteEvent " .. name)
	return remote
end

function Net.Function(name: string): RemoteFunction
	local remote = folder:WaitForChild(name, 10)
	assert(remote and remote:IsA("RemoteFunction"), "Unknown RemoteFunction " .. name)
	return remote
end

-- Server: fire an event to one player.
function Net.Fire(player: Player, name: string, ...: any)
	Net.Event(name):FireClient(player, ...)
end

-- Server: fire an event to everyone.
function Net.FireAll(name: string, ...: any)
	Net.Event(name):FireAllClients(...)
end

-- Server: register a handler for a RemoteFunction. The handler returns
-- (ok, message?, ...extra). Calls over `perSecond` are rejected.
local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}

function Net.Handle(name: string, handler: (Player, ...any) -> ...any, perSecond: number?)
	assert(RunService:IsServer(), "Net.Handle is server-only")
	local rate = perSecond or 6
	Net.Function(name).OnServerInvoke = function(player: Player, ...)
		local playerBuckets = buckets[player]
		if not playerBuckets then
			playerBuckets = {}
			buckets[player] = playerBuckets
		end
		local now = os.clock()
		local bucket = playerBuckets[name]
		if not bucket then
			bucket = { tokens = rate, last = now }
			playerBuckets[name] = bucket
		end
		bucket.tokens = math.min(rate, bucket.tokens + (now - bucket.last) * rate)
		bucket.last = now
		if bucket.tokens < 1 then
			return false, "Slow down!"
		end
		bucket.tokens -= 1

		local results = table.pack(pcall(handler, player, ...))
		if not results[1] then
			warn(string.format("[Net] %s handler error for %s: %s", name, player.Name, tostring(results[2])))
			return false, "Something went wrong"
		end
		return table.unpack(results, 2, results.n)
	end
end

-- Client: invoke a RemoteFunction safely. Always returns (ok, message, ...).
function Net.Invoke(name: string, ...: any): (boolean, string?, ...any)
	local results = table.pack(pcall(Net.Function(name).InvokeServer, Net.Function(name), ...))
	if not results[1] then
		return false, "Connection problem, try again"
	end
	return table.unpack(results, 2, results.n)
end

if RunService:IsServer() then
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return Net
