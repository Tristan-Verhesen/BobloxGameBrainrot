-- Small helpers for building instances in code (the whole greybox map and all
-- UI are built at runtime, so this gets used a lot).

local Make = {}

-- Make.Instance("Part", { Size = ..., Parent = ... }, { child1, child2 })
-- Parent is always assigned last so property changes don't replicate one by one.
function Make.Instance(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

-- Anchored smooth part with sensible defaults. Pass `className` for
-- "WedgePart", "SpawnLocation", etc.
function Make.Part(props: { [string]: any }, children: { Instance }?, className: string?): any
	local merged = {
		Anchored = true,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Material = Enum.Material.SmoothPlastic,
	}
	for key, value in props do
		merged[key] = value
	end
	return Make.Instance(className or "Part", merged, children)
end

-- Part with an ellipsoid mesh (non-uniform spheres for bodies, eggs, beaks).
function Make.Ellipsoid(props: { [string]: any }): Part
	local part = Make.Part(props)
	Make.Instance("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = part })
	return part
end

-- A SurfaceGui with one big text label on a face of a part.
function Make.SurfaceText(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	props: { [string]: any }?
): (SurfaceGui, TextLabel)
	local gui = Make.Instance("SurfaceGui", {
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 20,
		LightInfluence = 0,
		Parent = part,
	})
	local labelProps = {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		RichText = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0,
		Parent = gui,
	}
	if props then
		for key, value in props do
			labelProps[key] = value
		end
	end
	local label = Make.Instance("TextLabel", labelProps)
	return gui, label
end

-- A BillboardGui with one text label floating above a part.
function Make.Billboard(
	adornee: Instance,
	sizeStuds: Vector2,
	offset: Vector3,
	text: string,
	props: { [string]: any }?
): (BillboardGui, TextLabel)
	local gui = Make.Instance("BillboardGui", {
		Size = UDim2.fromScale(sizeStuds.X, sizeStuds.Y),
		StudsOffset = offset,
		AlwaysOnTop = false,
		LightInfluence = 0,
		MaxDistance = 120,
		Parent = adornee,
	})
	local labelProps = {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		RichText = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0,
		Parent = gui,
	}
	if props then
		for key, value in props do
			labelProps[key] = value
		end
	end
	local label = Make.Instance("TextLabel", labelProps)
	return gui, label
end

-- Welds every BasePart in `model` to `root` (WeldConstraint), unanchors them
-- and makes them massless so the root alone drives the physics.
function Make.WeldAll(model: Instance, root: BasePart)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= root then
			Make.Instance("WeldConstraint", { Part0 = root, Part1 = part, Parent = part })
			part.Anchored = false
			part.Massless = true
		end
	end
end

function Make.ColorToHex(color: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

-- "<font color=...>text</font>" for RichText labels.
function Make.Colored(text: string, color: Color3): string
	return string.format('<font color="%s">%s</font>', Make.ColorToHex(color), text)
end

return Make
