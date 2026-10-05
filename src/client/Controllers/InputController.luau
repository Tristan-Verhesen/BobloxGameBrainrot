-- PC keybinds for the menu windows (see HUDController.Menu).

local UserInputService = game:GetService("UserInputService")

local Components = require(script.Parent.Parent.UI.Components)
local HUDController = require(script.Parent.HUDController)

local InputController = {}

function InputController.Start()
	local bindings = {}
	for _, item in HUDController.Menu do
		bindings[item.Key] = item.Window
	end
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or UserInputService:GetFocusedTextBox() then
			return
		end
		local window = bindings[input.KeyCode]
		if window then
			Components.ToggleWindow(window)
		end
	end)
end

return InputController
