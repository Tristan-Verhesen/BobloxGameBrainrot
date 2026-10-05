-- Reusable UI pieces: the root ScreenGui, labels, juicy buttons, progress
-- bars, and pop-up windows (only one window is open at a time).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Make = require(Shared.Util.Make)
local Signal = require(Shared.Util.Signal)

local Theme = require(script.Parent.Theme)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local Components = {}

local screenGui: ScreenGui? = nil
local overlayGui: ScreenGui? = nil

local function makeScreen(name: string, order: number): ScreenGui
	local gui = Make.Instance("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	-- Scale everything with the window height (designed at 900px tall).
	local scale = Make.Instance("UIScale", { Parent = gui })
	local camera = workspace.CurrentCamera
	local function rescale()
		scale.Scale = math.clamp(camera.ViewportSize.Y / 900, 0.6, 1.4)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
	return gui
end

-- Main HUD/windows gui.
function Components.Screen(): ScreenGui
	if not screenGui then
		screenGui = makeScreen("CapyUI", 1)
	end
	return screenGui :: ScreenGui
end

-- Full-screen effects, hatch reveals and banners draw above everything.
function Components.Overlay(): ScreenGui
	if not overlayGui then
		overlayGui = makeScreen("CapyOverlay", 10)
	end
	return overlayGui :: ScreenGui
end

function Components.Corner(radius: number?): UICorner
	return Make.Instance("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Components.Stroke(thickness: number?, color: Color3?): UIStroke
	return Make.Instance("UIStroke", {
		Thickness = thickness or 3,
		Color = color or Theme.Stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Components.Padding(pixels: number): UIPadding
	local padding = UDim.new(0, pixels)
	return Make.Instance("UIPadding", {
		PaddingTop = padding,
		PaddingBottom = padding,
		PaddingLeft = padding,
		PaddingRight = padding,
	})
end

-- Text label with an outline. Use TextSize for fixed sizes, or Scaled = true.
function Components.Label(props: { [string]: any }): TextLabel
	local merged = {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Theme.Text,
		TextSize = 22,
		RichText = true,
	}
	for key, value in props do
		if key ~= "Scaled" and key ~= "Outline" then
			merged[key] = value
		end
	end
	if props.Scaled then
		merged.TextScaled = true
	end
	local label = Make.Instance("TextLabel", merged)
	if props.Outline ~= false then
		Make.Instance("UIStroke", {
			Thickness = if type(props.Outline) == "number" then props.Outline else 2,
			Color = Theme.Stroke,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Parent = label,
		})
	end
	return label
end

export type ButtonProps = {
	Text: string,
	Color: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	TextSize: number?,
	LayoutOrder: number?,
	Parent: Instance?,
	OnClick: (() -> ())?,
}

-- Chunky button that squishes on hover/click and plays a click sound.
function Components.Button(props: ButtonProps): TextButton
	local button = Make.Instance("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = props.Color or Theme.Good,
		Size = props.Size or UDim2.fromOffset(140, 48),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
	}, {
		Components.Corner(12),
		Components.Stroke(3),
		Make.Instance("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
		}),
	})
	local scale = Make.Instance("UIScale", { Parent = button })
	Components.Label({
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		Text = props.Text,
		TextSize = props.TextSize or 22,
		TextWrapped = true,
		Parent = button,
	})
	local function tweenScale(target: number)
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = target }):Play()
	end
	button.MouseEnter:Connect(function()
		tweenScale(1.06)
	end)
	button.MouseLeave:Connect(function()
		tweenScale(1)
	end)
	button.MouseButton1Down:Connect(function()
		tweenScale(0.92)
	end)
	button.MouseButton1Up:Connect(function()
		tweenScale(1.06)
	end)
	button.Activated:Connect(function()
		SoundController.Play("UIClick", 0.05)
		if props.OnClick then
			props.OnClick()
		end
	end)
	if props.Parent then
		button.Parent = props.Parent
	end
	return button
end

function Components.SetButton(button: TextButton, text: string, color: Color3?)
	local label = button:FindFirstChild("Label") :: TextLabel
	label.Text = text
	if color then
		button.BackgroundColor3 = color
	end
end

-- Horizontal progress bar. Returns the bar, a setter, and its text label.
function Components.ProgressBar(props: { [string]: any }): (Frame, (number) -> (), TextLabel)
	local bar = Make.Instance("Frame", {
		BackgroundColor3 = Theme.Stroke,
		Size = props.Size or UDim2.fromOffset(300, 30),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	}, { Components.Corner(10), Components.Stroke(3) })
	local fill = Make.Instance("Frame", {
		Name = "Fill",
		BackgroundColor3 = props.Color or Theme.Accent,
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	}, { Components.Corner(10) })
	local label = Components.Label({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		Text = props.Text or "",
		TextSize = props.TextSize or 18,
		ZIndex = 2,
		Parent = bar,
	})
	local function set(fraction: number)
		TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) }):Play()
	end
	return bar, set, label
end

-- Windows -------------------------------------------------------------------

export type Window = {
	Name: string,
	Frame: Frame,
	Body: Frame,
	Opened: any, -- Signal
	IsOpen: () -> boolean,
	Open: () -> (),
	Close: () -> (),
	Toggle: () -> (),
}

local windows: { [string]: Window } = {}
local openWindow: Window? = nil

function Components.GetWindow(name: string): Window?
	return windows[name]
end

function Components.OpenWindow(name: string)
	local window = windows[name]
	if window then
		window.Open()
	end
end

function Components.ToggleWindow(name: string)
	local window = windows[name]
	if window then
		window.Toggle()
	end
end

function Components.CloseWindows()
	if openWindow then
		openWindow.Close()
	end
end

function Components.Window(name: string, title: string, size: Vector2, accent: Color3?): Window
	local frame = Make.Instance("Frame", {
		Name = name .. "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Theme.Background,
		Visible = false,
		ZIndex = 5,
		Parent = Components.Screen(),
	}, { Components.Corner(18), Components.Stroke(4) })
	local scale = Make.Instance("UIScale", { Parent = frame })

	local header = Make.Instance("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundColor3 = accent or Theme.Pink,
		Parent = frame,
	}, { Components.Corner(18) })
	-- Square off the header's bottom corners.
	Make.Instance("Frame", {
		Position = UDim2.new(0, 0, 1, -18),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = accent or Theme.Pink,
		BorderSizePixel = 0,
		Parent = header,
	})
	Components.Label({
		Size = UDim2.new(1, -80, 1, 0),
		Position = UDim2.fromOffset(20, 0),
		Text = title,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = header,
	})

	local body = Make.Instance("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 1, -60),
		BackgroundTransparency = 1,
		Parent = frame,
	}, { Components.Padding(14) })

	local window: Window
	local opened = Signal.new()

	local function close()
		if not frame.Visible then
			return
		end
		frame.Visible = false
		if openWindow == window then
			openWindow = nil
		end
	end

	local function open()
		if openWindow and openWindow ~= window then
			openWindow.Close()
		end
		openWindow = window
		frame.Visible = true
		scale.Scale = 0.6
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		SoundController.Play("UIClick")
		opened:Fire()
	end

	Components.Button({
		Text = "X",
		Color = Theme.Bad,
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(1, -54, 0, 7),
		TextSize = 28,
		Parent = header,
		OnClick = close,
	})

	window = {
		Name = name,
		Frame = frame,
		Body = body,
		Opened = opened,
		IsOpen = function()
			return frame.Visible
		end,
		Open = open,
		Close = close,
		Toggle = function()
			if frame.Visible then
				close()
			else
				open()
			end
		end,
	}
	windows[name] = window
	return window
end

-- Scrolling list that grows with its contents.
function Components.ScrollList(props: { [string]: any }): ScrollingFrame
	local list = Make.Instance("ScrollingFrame", {
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = props.Parent,
	})
	if props.Grid then
		Make.Instance("UIGridLayout", {
			CellSize = props.Grid,
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = list,
		})
	else
		Make.Instance("UIListLayout", {
			Padding = UDim.new(0, props.Gap or 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = list,
		})
	end
	Make.Instance("UIPadding", {
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		Parent = list,
	})
	return list
end

-- A rounded panel row used by shop/reward lists.
function Components.Row(height: number, layoutOrder: number, parent: Instance): Frame
	return Make.Instance("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Theme.Panel,
		LayoutOrder = layoutOrder,
		Parent = parent,
	}, { Components.Corner(14), Components.Stroke(2) })
end

return Components
