-- The Giant Capybara in the middle of the hub. Walk into the orange ring with
-- snacks and he eats them all, paying you cash. Every snack also fills a
-- server-wide meter; when it's full everyone gets a CAPY FEAST (2x cash).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FoodConfig = require(Shared.Config.FoodConfig)
local GameConfig = require(Shared.Config.GameConfig)
local SoundConfig = require(Shared.Config.SoundConfig)
local Formulas = require(Shared.Formulas)
local MapLayout = require(Shared.MapLayout)
local Make = require(Shared.Util.Make)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local EventService = require(script.Parent.EventService)
local FoodService = require(script.Parent.FoodService)
local MapBuilder = require(script.Parent.MapBuilder)

local CapybaraService = {}

local DELIVERY_TICK = 0.15

local model: Model
local head: BasePart
local headRest: CFrame
local mouthPosition: Vector3
local meterFill: Frame
local meterText: TextLabel
local chompSound: Sound
local happySound: Sound
local chomping = false
local fullness = 0

local function feastTarget(): number
	return GameConfig.CapyFeastFoodBase + GameConfig.CapyFeastFoodPerPlayer * #Players:GetPlayers()
end

-- Builds the greybox capybara facing `facing`. Head pieces are welded to an
-- anchored head part so the head can be animated on its own.
local function buildGreyboxCapy(origin: CFrame): (Model, BasePart)
	local capy = Make.Instance("Model", { Name = "GiantCapybara" })
	local brown = Color3.fromRGB(150, 100, 60)
	local dark = Color3.fromRGB(105, 70, 45)

	local function piece(kind: string, size: Vector3, offset: Vector3, color: Color3, parent: Instance): BasePart
		local props = {
			Size = size,
			CFrame = origin * CFrame.new(offset),
			Color = color,
			Parent = parent,
		}
		if kind == "Ellipsoid" then
			return Make.Ellipsoid(props)
		end
		return Make.Part(props)
	end

	local body = piece("Ellipsoid", Vector3.new(24, 19, 36), Vector3.new(0, 12, 2), brown, capy)
	capy.PrimaryPart = body
	for _, x in { -7.5, 7.5 } do
		for _, z in { -9, 12 } do
			piece("Part", Vector3.new(6, 8, 6), Vector3.new(x, 3.5, z), dark, capy)
		end
	end

	local headModel = Make.Instance("Model", { Name = "Head", Parent = capy })
	local headPart = piece("Ellipsoid", Vector3.new(17, 15, 17), Vector3.new(0, 18, -17), brown, headModel)
	headModel.PrimaryPart = headPart
	local attached = {
		piece("Ellipsoid", Vector3.new(13, 9, 9), Vector3.new(0, 14.5, -25), dark, headModel), -- snout
		piece("Ellipsoid", Vector3.new(6, 2.5, 2), Vector3.new(0, 17.5, -29.4), Color3.fromRGB(30, 20, 15), headModel), -- nose
		piece("Part", Vector3.new(6, 0.6, 0.6), Vector3.new(0, 12.2, -29), Color3.fromRGB(40, 25, 15), headModel), -- mouth
		piece("Ellipsoid", Vector3.new(3.5, 3.5, 2), Vector3.new(-6.5, 25.5, -13), dark, headModel), -- ears
		piece("Ellipsoid", Vector3.new(3.5, 3.5, 2), Vector3.new(6.5, 25.5, -13), dark, headModel),
		piece("Ellipsoid", Vector3.new(2.4, 1.2, 1), Vector3.new(-4.8, 21, -25.2), Color3.fromRGB(20, 15, 10), headModel), -- chill eyes
		piece("Ellipsoid", Vector3.new(2.4, 1.2, 1), Vector3.new(4.8, 21, -25.2), Color3.fromRGB(20, 15, 10), headModel),
		piece("Ellipsoid", Vector3.new(5.5, 5, 5.5), Vector3.new(0, 27.5, -17), Color3.fromRGB(255, 150, 30), headModel), -- the iconic orange
		piece("Part", Vector3.new(0.5, 1.5, 0.5), Vector3.new(0, 30.6, -17), Color3.fromRGB(60, 140, 50), headModel), -- orange stem
	}
	for _, part in attached do
		part.Anchored = false
		Make.Instance("WeldConstraint", { Part0 = headPart, Part1 = part, Parent = part })
	end
	return capy, headPart
end

local function buildCapy()
	local origin = CFrame.lookAt(MapLayout.CapyPosition, MapLayout.CapyPosition + Vector3.new(-1, 0, 1))
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("Capybara")
	if custom and custom:IsA("Model") then
		model = custom:Clone()
		model:PivotTo(origin)
		local customHead = model:FindFirstChild("Head", true)
		head = if customHead and customHead:IsA("BasePart")
			then customHead
			else model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true) :: BasePart
	else
		model, head = buildGreyboxCapy(origin)
	end
	model.Parent = MapBuilder.Folders.Capybara
	headRest = head.CFrame
	mouthPosition = (origin * CFrame.new(0, 12, -30)).Position

	-- Orange "drop zone" ring.
	Make.Part({
		Name = "FeedRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, GameConfig.DeliveryRadius * 2, GameConfig.DeliveryRadius * 2),
		CFrame = CFrame.new(MapLayout.CapyPosition + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 150, 40),
		Material = Enum.Material.Neon,
		Transparency = 0.65,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = MapBuilder.Folders.Capybara,
	})

	-- Name + hunger meter above his head.
	local gui = Make.Instance("BillboardGui", {
		Size = UDim2.fromOffset(360, 110),
		StudsOffset = Vector3.new(0, 20, 0),
		MaxDistance = 400,
		LightInfluence = 0,
		AlwaysOnTop = true,
		Parent = head,
	})
	Make.Instance("TextLabel", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Text = "🦫 SIR CHONKS THE GIANT CAPY 🦫",
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(255, 220, 120),
		TextStrokeTransparency = 0,
		Parent = gui,
	})
	local bar = Make.Instance("Frame", {
		Position = UDim2.fromOffset(20, 56),
		Size = UDim2.new(1, -40, 0, 40),
		BackgroundColor3 = Color3.fromRGB(40, 25, 20),
		Parent = gui,
	}, {
		Make.Instance("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Make.Instance("UIStroke", { Thickness = 3, Color = Color3.fromRGB(20, 10, 5) }),
	})
	meterFill = Make.Instance("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(255, 150, 40),
		Parent = bar,
	}, { Make.Instance("UICorner", { CornerRadius = UDim.new(0, 12) }) })
	meterText = Make.Instance("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0,
		ZIndex = 2,
		Parent = bar,
	})

	chompSound = Make.Instance("Sound", {
		SoundId = SoundConfig.Capy.Chomp.Id,
		Volume = SoundConfig.Capy.Chomp.Volume,
		PlaybackSpeed = SoundConfig.Capy.Chomp.Speed,
		RollOffMaxDistance = SoundConfig.Capy.RollOffMaxDistance,
		Parent = head,
	})
	happySound = Make.Instance("Sound", {
		SoundId = SoundConfig.Capy.Happy.Id,
		Volume = SoundConfig.Capy.Happy.Volume,
		PlaybackSpeed = SoundConfig.Capy.Happy.Speed,
		RollOffMaxDistance = SoundConfig.Capy.RollOffMaxDistance,
		Parent = head,
	})
end

local function updateMeter()
	local target = feastTarget()
	local feasting = EventService.IsActive("CapyFeast")
	local fraction = if feasting then 1 else math.clamp(fullness / target, 0, 1)
	meterFill.Size = UDim2.fromScale(fraction, 1)
	meterFill.BackgroundColor3 = if feasting then Color3.fromRGB(255, 80, 160) else Color3.fromRGB(255, 150, 40)
	meterText.Text = if feasting
		then "🎉 CAPY FEAST! 2x CASH 🎉"
		else string.format("FEED ME 🍔 %d / %d", math.floor(fullness), target)
	local gameState = EventService.GetGameState()
	gameState:SetAttribute("CapyFullness", fullness)
	gameState:SetAttribute("CapyFullnessMax", target)
end

local function chomp()
	if chomping then
		return
	end
	chomping = true
	chompSound:Play()
	local down = headRest * CFrame.new(0, -2.5, -1.5) * CFrame.Angles(math.rad(-14), 0, 0)
	local tweenDown = TweenService:Create(head, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { CFrame = down })
	tweenDown:Play()
	tweenDown.Completed:Wait()
	local tweenUp = TweenService:Create(head, TweenInfo.new(0.18, Enum.EasingStyle.Back), { CFrame = headRest })
	tweenUp:Play()
	tweenUp.Completed:Wait()
	chomping = false
end

local function feastDance()
	while chomping do
		task.wait()
	end
	chomping = true -- blocks chomps so they don't fight the dance tween
	happySound:Play()
	local origin = model:GetPivot()
	local value = Make.Instance("NumberValue", { Value = 0 })
	value.Changed:Connect(function(t)
		model:PivotTo(origin * CFrame.new(0, math.abs(math.sin(t * math.pi * 6)) * 6, 0) * CFrame.Angles(0, t * math.pi * 4, 0))
	end)
	local tween = TweenService:Create(value, TweenInfo.new(2.5, Enum.EasingStyle.Linear), { Value = 1 })
	tween:Play()
	tween.Completed:Wait()
	model:PivotTo(origin)
	headRest = head.CFrame
	value:Destroy()
	chomping = false
end

local function deliver(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local items, total = FoodService.TakeCarry(player)
	if total <= 0 then
		return
	end
	local baseValue = 0
	for foodId, count in items do
		baseValue += FoodConfig[foodId].Value * count
	end
	local multiplier = Formulas.CashMultiplier(data, os.time()) * EventService.GetCashMultiplier()
	local cash = math.max(1, math.floor(baseValue * multiplier))
	DataService.AddCash(player, cash)
	DataService.Increment(player, "TotalFed", total)

	Net.Fire(player, "Effect", "Deliver", {
		Cash = cash,
		Count = total,
		Multiplier = multiplier,
		Position = mouthPosition,
	})
	task.spawn(chomp)

	if not EventService.IsActive("CapyFeast") then
		fullness += total
		if fullness >= feastTarget() then
			fullness = 0
			EventService.Trigger("CapyFeast")
			task.spawn(feastDance)
		end
	end
	updateMeter()
end

function CapybaraService.Start()
	buildCapy()
	updateMeter()

	EventService.Ended:Connect(function(eventId)
		if eventId == "CapyFeast" then
			updateMeter()
		end
	end)
	Players.PlayerAdded:Connect(updateMeter)
	Players.PlayerRemoving:Connect(function()
		task.defer(updateMeter)
	end)

	local radiusSquared = GameConfig.DeliveryRadius * GameConfig.DeliveryRadius
	task.spawn(function()
		while true do
			task.wait(DELIVERY_TICK)
			for _, player in Players:GetPlayers() do
				if FoodService.GetCarry(player).Total <= 0 then
					continue
				end
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not root or character:GetAttribute("Ragdolled") then
					continue
				end
				local offset = (root :: BasePart).Position - MapLayout.CapyPosition
				if offset.X * offset.X + offset.Z * offset.Z <= radiusSquared then
					deliver(player)
				end
			end
		end
	end)
end

return CapybaraService
