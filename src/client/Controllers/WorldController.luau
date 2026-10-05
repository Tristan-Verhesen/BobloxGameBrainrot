-- Local world tweaks: unlocked gates become walk-through for you, shop and
-- rebirth stalls open their windows, and snack emojis bob in place.

local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local ClientData = require(script.Parent.Parent.ClientData)
local Components = require(script.Parent.Parent.UI.Components)

local WorldController = {}

local function refreshGate(gate: Instance)
	if not gate:IsA("BasePart") then
		return
	end
	local zoneId = gate:GetAttribute("ZoneId")
	local unlocked = ClientData.Data.Zones[zoneId] == true
	gate.CanCollide = not unlocked
	gate.Transparency = if unlocked then 0.85 else 0.1
	local prompt = gate:FindFirstChild("UnlockPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = not unlocked
	end
	local gui = gate:FindFirstChildOfClass("SurfaceGui")
	local label = gui and gui:FindFirstChild("LockText")
	if label and label:IsA("TextLabel") then
		label.Visible = not unlocked
	end
end

local function refreshGates()
	for _, gate in CollectionService:GetTagged("ZoneGate") do
		refreshGate(gate)
	end
end

function WorldController.Start()
	ClientData.Observe({ "Zones" }, refreshGates)
	CollectionService:GetInstanceAddedSignal("ZoneGate"):Connect(refreshGate)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local window = prompt:GetAttribute("OpensWindow")
		if type(window) == "string" then
			Components.OpenWindow(window)
		end
	end)

	-- Bob snack emojis (client-only property change on the billboard).
	local billboards: { [BasePart]: BillboardGui } = {}
	local function onFood(part: Instance)
		if part:IsA("BasePart") then
			local gui = part:FindFirstChildOfClass("BillboardGui")
			if gui then
				billboards[part] = gui
			end
		end
	end
	for _, part in CollectionService:GetTagged("Food") do
		onFood(part)
	end
	CollectionService:GetInstanceAddedSignal("Food"):Connect(onFood)
	CollectionService:GetInstanceRemovedSignal("Food"):Connect(function(part)
		billboards[part :: BasePart] = nil
	end)
	local baseOffsets: { [BillboardGui]: Vector3 } = {}
	RunService.RenderStepped:Connect(function()
		local t = os.clock() * 3
		for part, gui in billboards do
			if gui.Parent ~= part then
				billboards[part] = nil
				continue
			end
			local base = baseOffsets[gui]
			if not base then
				base = gui.StudsOffset
				baseOffsets[gui] = base
			end
			gui.StudsOffset = base + Vector3.new(0, math.sin(t + part.Position.X) * 0.35, 0)
		end
	end)
	-- Forget offsets for destroyed snacks.
	task.spawn(function()
		while true do
			task.wait(10)
			for gui in baseOffsets do
				if gui.Parent == nil then
					baseOffsets[gui] = nil
				end
			end
		end
	end)
end

return WorldController
