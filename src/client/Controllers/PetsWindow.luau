-- Pets window [P]: inventory grid, equip / unequip / delete, Equip Best.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local PetConfig = require(Shared.Config.PetConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Util.Format)
local Make = require(Shared.Util.Make)
local Net = require(Shared.Net)

local ClientData = require(script.Parent.Parent.ClientData)
local Components = require(script.Parent.Parent.UI.Components)
local Theme = require(script.Parent.Parent.UI.Theme)
local HUDController = require(script.Parent.HUDController)
local SoundController = require(script.Parent.SoundController)

local PetsWindow = {}

local selectedUid: string? = nil
local deleteArmedUntil = 0

local function invoke(remote: string, ...: any): boolean
	local ok, message = Net.Invoke(remote, ...)
	if not ok then
		SoundController.Play("UIError")
	end
	if message then
		HUDController.Toast(message, if ok then "Good" else "Bad")
	end
	return ok
end

function PetsWindow.Start()
	local window = Components.Window("Pets", "🐾 PETS", Vector2.new(780, 580), Color3.fromRGB(90, 200, 110))
	local body = window.Body

	local summary = Components.Label({
		Size = UDim2.new(1, -200, 0, 46),
		Text = "",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = body,
	})
	Components.Button({
		Text = "⭐ Equip Best",
		Color = Theme.Accent,
		Size = UDim2.fromOffset(190, 46),
		Position = UDim2.new(1, -190, 0, 0),
		Parent = body,
		OnClick = function()
			invoke("EquipBest")
		end,
	})

	local grid = Components.ScrollList({
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -56 - 96),
		Grid = UDim2.fromOffset(110, 124),
		Parent = body,
	})
	local emptyLabel = Components.Label({
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -56 - 96),
		Text = "No pets yet!\nHatch eggs at the 🥚 Egg Stands in the hub (walk up + press E).",
		TextSize = 26,
		TextWrapped = true,
		TextColor3 = Theme.SubText,
		Visible = false,
		Parent = body,
	})

	-- Details bar for the selected pet.
	local details = Make.Instance("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 86),
		BackgroundColor3 = Theme.Panel,
		Parent = body,
	}, { Components.Corner(14), Components.Stroke(2) })
	local detailsLabel = Components.Label({
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -380, 1, 0),
		Text = "",
		TextSize = 22,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = details,
	})
	local equipButton = Components.Button({
		Text = "Equip",
		Size = UDim2.fromOffset(170, 56),
		Position = UDim2.new(1, -360, 0.5, -28),
		Parent = details,
		OnClick = function()
			local data = ClientData.Data
			if not selectedUid or not data.Pets[selectedUid] then
				return
			end
			if table.find(data.EquippedPets, selectedUid) then
				invoke("UnequipPet", selectedUid)
			else
				invoke("EquipPet", selectedUid)
			end
		end,
	})
	local deleteButton
	deleteButton = Components.Button({
		Text = "🗑️ Delete",
		Color = Theme.Bad,
		Size = UDim2.fromOffset(170, 56),
		Position = UDim2.new(1, -180, 0.5, -28),
		Parent = details,
		OnClick = function()
			if not selectedUid then
				return
			end
			if os.clock() > deleteArmedUntil then
				deleteArmedUntil = os.clock() + 2.5
				Components.SetButton(deleteButton, "Sure? Click again")
				task.delay(2.5, function()
					if os.clock() >= deleteArmedUntil then
						Components.SetButton(deleteButton, "🗑️ Delete")
					end
				end)
				return
			end
			deleteArmedUntil = 0
			Components.SetButton(deleteButton, "🗑️ Delete")
			if invoke("DeletePet", selectedUid) then
				selectedUid = nil
			end
		end,
	})

	local cells: { Instance } = {}

	local function refresh()
		local data = ClientData.Data
		for _, cell in cells do
			cell:Destroy()
		end
		table.clear(cells)

		local owned = {}
		for uid, petId in data.Pets do
			local pet = PetConfig.Pets[petId]
			if pet then
				table.insert(owned, { Uid = uid, Pet = pet, Equipped = table.find(data.EquippedPets, uid) ~= nil })
			end
		end
		table.sort(owned, function(a, b)
			if a.Equipped ~= b.Equipped then
				return a.Equipped
			end
			if a.Pet.Multiplier ~= b.Pet.Multiplier then
				return a.Pet.Multiplier > b.Pet.Multiplier
			end
			return a.Uid < b.Uid
		end)

		summary.Text = string.format(
			"%d/%d pets · %d/%d equipped · pet boost %s",
			#owned,
			GameConfig.MaxPetInventory,
			#data.EquippedPets,
			GameConfig.MaxEquippedPets,
			Make.Colored(Format.Multiplier(Formulas.PetMultiplier(data)), Theme.Accent)
		)
		emptyLabel.Visible = #owned == 0

		if selectedUid and not data.Pets[selectedUid] then
			selectedUid = nil
		end

		for index, entry in owned do
			local rarity = RarityConfig[entry.Pet.Rarity]
			local cell = Make.Instance("TextButton", {
				Text = "",
				AutoButtonColor = true,
				BackgroundColor3 = if entry.Uid == selectedUid then Theme.PanelLight else Theme.Panel,
				LayoutOrder = index,
				Parent = grid,
			}, {
				Components.Corner(12),
				Components.Stroke(if entry.Uid == selectedUid then 5 else 3, rarity.Color),
			})
			Components.Label({
				Size = UDim2.new(1, 0, 0, 62),
				Text = entry.Pet.Emoji,
				TextSize = 48,
				Outline = false,
				Parent = cell,
			})
			Components.Label({
				Position = UDim2.fromOffset(4, 62),
				Size = UDim2.new(1, -8, 0, 34),
				Text = entry.Pet.Name,
				TextSize = 15,
				TextWrapped = true,
				TextColor3 = rarity.Color,
				Parent = cell,
			})
			Components.Label({
				Position = UDim2.fromOffset(0, 96),
				Size = UDim2.new(1, 0, 0, 24),
				Text = Format.Multiplier(entry.Pet.Multiplier),
				TextSize = 18,
				TextColor3 = Theme.Accent,
				Parent = cell,
			})
			if entry.Equipped then
				Components.Label({
					Position = UDim2.fromOffset(4, 2),
					Size = UDim2.fromOffset(26, 26),
					Text = "✅",
					TextSize = 20,
					Outline = false,
					Parent = cell,
				})
			end
			cell.Activated:Connect(function()
				SoundController.Play("UIClick")
				selectedUid = entry.Uid
				deleteArmedUntil = 0
				Components.SetButton(deleteButton, "🗑️ Delete")
				refresh()
			end)
			table.insert(cells, cell)
		end

		local selectedPetId = selectedUid and data.Pets[selectedUid]
		local selectedPet = selectedPetId and PetConfig.Pets[selectedPetId]
		details.Visible = selectedPet ~= nil
		if selectedPet then
			local rarity = RarityConfig[selectedPet.Rarity]
			detailsLabel.Text = string.format(
				"%s %s\n%s · %s cash",
				selectedPet.Emoji,
				selectedPet.Name,
				Make.Colored(rarity.Name, rarity.Color),
				Make.Colored(Format.Multiplier(selectedPet.Multiplier), Theme.Accent)
			)
			local equipped = table.find(data.EquippedPets, selectedUid) ~= nil
			Components.SetButton(
				equipButton,
				if equipped then "Unequip" else "Equip",
				if equipped then Theme.Info else Theme.Good
			)
		end
	end

	ClientData.Observe({ "Pets", "EquippedPets" }, function()
		if window.IsOpen() then
			refresh()
		end
	end)
	window.Opened:Connect(refresh)
end

return PetsWindow
