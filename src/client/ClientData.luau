-- The local player's save data, mirrored from the server. The server sends a
-- full snapshot once (GetData) and then whole top-level keys as they change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local ClientData = {
	Data = nil :: any,
	Offline = false,
	Changed = Signal.new(), -- (key, value)
}

function ClientData.Get(key: string): any
	return ClientData.Data and ClientData.Data[key]
end

-- Calls `callback` now and again whenever any of `keys` changes.
function ClientData.Observe(keys: { string }, callback: () -> ())
	callback()
	ClientData.Changed:Connect(function(key)
		if table.find(keys, key) then
			callback()
		end
	end)
end

-- Yields until the first snapshot arrives.
function ClientData.Load()
	Net.Event("DataChanged").OnClientEvent:Connect(function(key, value)
		if ClientData.Data then
			ClientData.Data[key] = value
			ClientData.Changed:Fire(key, value)
		end
	end)
	while true do
		local ok, flag, data = Net.Invoke("GetData")
		if ok and data then
			ClientData.Data = data
			ClientData.Offline = flag == "offline"
			return
		end
		task.wait(2)
	end
end

return ClientData
