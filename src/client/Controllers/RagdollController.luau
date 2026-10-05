-- Client half of the ragdoll: the server swaps the joints, then tells us to
-- go limp (Physics state) and fling, because we own our character's physics.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local SoundController = require(script.Parent.SoundController)

local RagdollController = {}

local player = Players.LocalPlayer

function RagdollController.Start()
	Net.Event("Ragdoll").OnClientEvent:Connect(function(enabled: boolean, fling: Vector3?)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not root then
			return
		end
		if enabled then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			humanoid.AutoRotate = false
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			if fling then
				root.AssemblyLinearVelocity = fling
				root.AssemblyAngularVelocity =
					Vector3.new(math.random(-12, 12), math.random(-12, 12), math.random(-12, 12))
			end
		else
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			humanoid.AutoRotate = true
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			SoundController.Play("GetUp")
		end
	end)
end

return RagdollController
