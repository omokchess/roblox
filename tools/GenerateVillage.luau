local oldVillage = workspace:FindFirstChild("FortressVillageAsset")
if oldVillage then
	oldVillage:Destroy()
end

local previous = workspace:FindFirstChild("ArtisanVillage")
if previous then
	previous:Destroy()
end

local village = Instance.new("Model")
village.Name = "ArtisanVillage"
village.Parent = workspace

local rng = Random.new(271828)

local colors = {
	grass = Color3.fromRGB(76, 105, 55),
	grassDark = Color3.fromRGB(54, 79, 43),
	stone = Color3.fromRGB(86, 83, 78),
	stoneDark = Color3.fromRGB(55, 56, 58),
	stoneLight = Color3.fromRGB(124, 116, 103),
	road = Color3.fromRGB(112, 103, 91),
	wood = Color3.fromRGB(82, 52, 35),
	woodDark = Color3.fromRGB(48, 31, 24),
	plasterA = Color3.fromRGB(194, 174, 139),
	plasterB = Color3.fromRGB(164, 139, 111),
	plasterC = Color3.fromRGB(132, 151, 135),
	roofRed = Color3.fromRGB(100, 48, 43),
	roofBlue = Color3.fromRGB(47, 66, 78),
	roofGreen = Color3.fromRGB(55, 75, 60),
	warm = Color3.fromRGB(255, 194, 93),
	water = Color3.fromRGB(62, 137, 160),
}

local function makePart(parent, name, size, cf, color, material)
	local value = Instance.new("Part")
	value.Name = name
	value.Anchored = true
	value.Size = size
	value.CFrame = cf
	value.Color = color
	value.Material = material or Enum.Material.SmoothPlastic
	value.TopSurface = Enum.SurfaceType.Smooth
	value.BottomSurface = Enum.SurfaceType.Smooth
	value.Parent = parent
	return value
end

local function makeBall(parent, name, size, position, color, material)
	local value = makePart(parent, name, size, CFrame.new(position), color, material)
	value.Shape = Enum.PartType.Ball
	return value
end

local function makeCylinder(parent, name, diameter, height, position, color, material)
	local value = makePart(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	value.Shape = Enum.PartType.Cylinder
	return value
end

local function localPart(parent, name, size, base, offset, color, material, rotation)
	return makePart(parent, name, size, base * CFrame.new(offset) * (rotation or CFrame.identity), color, material)
end

local function addPointLight(parent, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = true
	light.Parent = parent
end

local function buildHouse(x, groundY, z, yaw, width, depth, floors, wallColor, roofColor, shop)
	local model = Instance.new("Model")
	model.Name = shop and "Workshop" or "Townhouse"
	model.Parent = village
	local base = CFrame.new(x, groundY, z) * CFrame.Angles(0, math.rad(yaw), 0)
	local wallHeight = 8 + (floors - 1) * 6

	localPart(
		model,
		"StoneFoundation",
		Vector3.new(width + 1, 2, depth + 1),
		base,
		Vector3.new(0, 1, 0),
		colors.stone,
		Enum.Material.Cobblestone
	)
	localPart(
		model,
		"PlasterWalls",
		Vector3.new(width, wallHeight, depth),
		base,
		Vector3.new(0, 2 + wallHeight / 2, 0),
		wallColor,
		Enum.Material.Brick
	)

	for _, xOffset in { -width / 2 + 0.45, width / 2 - 0.45 } do
		for _, zOffset in { -depth / 2 - 0.12, depth / 2 + 0.12 } do
			localPart(
				model,
				"CornerBeam",
				Vector3.new(0.7, wallHeight + 0.5, 0.7),
				base,
				Vector3.new(xOffset, 2 + wallHeight / 2, zOffset),
				colors.woodDark,
				Enum.Material.WoodPlanks
			)
		end
	end

	for floor = 1, floors do
		local beamY = 2 + floor * 6
		localPart(
			model,
			"FloorBeamFront",
			Vector3.new(width + 0.8, 0.55, 0.55),
			base,
			Vector3.new(0, beamY, -depth / 2 - 0.18),
			colors.woodDark,
			Enum.Material.WoodPlanks
		)
		localPart(
			model,
			"FloorBeamBack",
			Vector3.new(width + 0.8, 0.55, 0.55),
			base,
			Vector3.new(0, beamY, depth / 2 + 0.18),
			colors.woodDark,
			Enum.Material.WoodPlanks
		)
	end

	local roofY = 2 + wallHeight + 2.5
	local roofHalf = width * 0.58
	for _, side in { -1, 1 } do
		localPart(
			model,
			"RoofSlope",
			Vector3.new(roofHalf, 0.75, depth + 2.2),
			base,
			Vector3.new(side * width * 0.25, roofY, 0),
			roofColor,
			Enum.Material.Slate,
			CFrame.Angles(0, 0, math.rad(side * 31))
		)
	end
	localPart(
		model,
		"RoofRidge",
		Vector3.new(0.7, 0.8, depth + 2.4),
		base,
		Vector3.new(0, roofY + 1.2, 0),
		colors.woodDark,
		Enum.Material.WoodPlanks
	)

	localPart(
		model,
		"Door",
		Vector3.new(3.1, 5.3, 0.35),
		base,
		Vector3.new(0, 4.65, -depth / 2 - 0.24),
		colors.wood,
		Enum.Material.WoodPlanks
	)
	localPart(
		model,
		"DoorFrameTop",
		Vector3.new(3.8, 0.35, 0.55),
		base,
		Vector3.new(0, 7.4, -depth / 2 - 0.35),
		colors.woodDark,
		Enum.Material.WoodPlanks
	)
	for _, side in { -1, 1 } do
		localPart(
			model,
			"DoorFrameSide",
			Vector3.new(0.35, 5.6, 0.55),
			base,
			Vector3.new(side * 1.72, 4.7, -depth / 2 - 0.35),
			colors.woodDark,
			Enum.Material.WoodPlanks
		)
	end

	local windowXs = if width >= 14 then { -width * 0.28, width * 0.28 } else { width * 0.27 }
	for floor = 1, floors do
		local windowY = 5 + (floor - 1) * 6
		for _, wx in windowXs do
			if floor > 1 or math.abs(wx) > 2.2 then
				local pane = localPart(
					model,
					"WarmWindow",
					Vector3.new(2.3, 2.4, 0.28),
					base,
					Vector3.new(wx, windowY, -depth / 2 - 0.3),
					colors.warm,
					Enum.Material.Neon
				)
				pane.Transparency = 0.2
				localPart(
					model,
					"WindowLintel",
					Vector3.new(3, 0.35, 0.48),
					base,
					Vector3.new(wx, windowY + 1.4, -depth / 2 - 0.38),
					colors.woodDark,
					Enum.Material.WoodPlanks
				)
				localPart(
					model,
					"WindowSill",
					Vector3.new(3, 0.35, 0.48),
					base,
					Vector3.new(wx, windowY - 1.4, -depth / 2 - 0.38),
					colors.woodDark,
					Enum.Material.WoodPlanks
				)
			end
		end
	end

	localPart(
		model,
		"Chimney",
		Vector3.new(2, 6, 2),
		base,
		Vector3.new(width * 0.28, roofY + 1.5, depth * 0.12),
		colors.stoneDark,
		Enum.Material.Brick
	)

	if shop then
		local awningColor = if rng:NextNumber() > 0.5 then colors.roofRed else colors.roofBlue
		localPart(
			model,
			"Awning",
			Vector3.new(width * 0.75, 0.55, 4.5),
			base,
			Vector3.new(0, 7.6, -depth / 2 - 2),
			awningColor,
			Enum.Material.Fabric,
			CFrame.Angles(math.rad(-12), 0, 0)
		)
		for _, side in { -1, 1 } do
			localPart(
				model,
				"AwningPost",
				Vector3.new(0.35, 6, 0.35),
				base,
				Vector3.new(side * width * 0.32, 4.5, -depth / 2 - 3.3),
				colors.woodDark,
				Enum.Material.WoodPlanks
			)
		end
		localPart(
			model,
			"Counter",
			Vector3.new(width * 0.7, 1.2, 2.2),
			base,
			Vector3.new(0, 2.7, -depth / 2 - 2.7),
			colors.wood,
			Enum.Material.WoodPlanks
		)
	end

	return model
end

local function buildTree(x, y, z, scale)
	local model = Instance.new("Model")
	model.Name = "GroundedTree"
	model.Parent = village
	makePart(
		model,
		"Trunk",
		Vector3.new(2.2 * scale, 9 * scale, 2.2 * scale),
		CFrame.new(x, y + 4.5 * scale, z),
		colors.wood,
		Enum.Material.Wood
	)
	local foliageColor = if rng:NextNumber() > 0.45 then colors.grassDark else Color3.fromRGB(68, 105, 55)
	makeBall(
		model,
		"Crown",
		Vector3.new(9, 7, 9) * scale,
		Vector3.new(x, y + 10 * scale, z),
		foliageColor,
		Enum.Material.LeafyGrass
	)
	makeBall(
		model,
		"Crown",
		Vector3.new(7, 6, 7) * scale,
		Vector3.new(x - 3 * scale, y + 9 * scale, z + 1 * scale),
		foliageColor,
		Enum.Material.LeafyGrass
	)
	makeBall(
		model,
		"Crown",
		Vector3.new(7, 6, 7) * scale,
		Vector3.new(x + 3 * scale, y + 9.5 * scale, z - 1 * scale),
		foliageColor,
		Enum.Material.LeafyGrass
	)
end

local function buildLamp(x, y, z)
	local model = Instance.new("Model")
	model.Name = "StreetLamp"
	model.Parent = village
	makePart(model, "Post", Vector3.new(0.45, 7, 0.45), CFrame.new(x, y + 3.5, z), colors.woodDark, Enum.Material.Metal)
	makePart(model, "Cap", Vector3.new(1.8, 0.35, 1.8), CFrame.new(x, y + 7.1, z), colors.woodDark, Enum.Material.Metal)
	local lantern = makePart(
		model,
		"Lantern",
		Vector3.new(1.2, 1.8, 1.2),
		CFrame.new(x, y + 6.2, z),
		colors.warm,
		Enum.Material.Neon
	)
	lantern.Transparency = 0.12
	addPointLight(lantern, colors.warm, 1.1, 18)
end

local function buildStall(x, y, z, yaw, canopyColor)
	local model = Instance.new("Model")
	model.Name = "MarketStall"
	model.Parent = village
	local base = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0)
	localPart(
		model,
		"Table",
		Vector3.new(7, 1, 3.4),
		base,
		Vector3.new(0, 2.6, 0),
		colors.wood,
		Enum.Material.WoodPlanks
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			localPart(
				model,
				"Post",
				Vector3.new(0.35, 6, 0.35),
				base,
				Vector3.new(sx * 3, 3.4, sz * 1.3),
				colors.woodDark,
				Enum.Material.WoodPlanks
			)
		end
	end
	localPart(
		model,
		"Canopy",
		Vector3.new(7.8, 0.45, 4.6),
		base,
		Vector3.new(0, 6.4, 0),
		canopyColor,
		Enum.Material.Fabric
	)
	for i = -2, 2 do
		local produceColor = (
			{ Color3.fromRGB(154, 69, 55), Color3.fromRGB(207, 146, 52), Color3.fromRGB(81, 125, 68) }
		)[(i + 3) % 3 + 1]
		makeBall(
			model,
			"Produce",
			Vector3.new(0.8, 0.8, 0.8),
			(base * CFrame.new(i * 1.1, 3.5, -0.3)).Position,
			produceColor,
			Enum.Material.SmoothPlastic
		)
	end
end

local function buildBarrel(x, y, z, scale)
	local model = Instance.new("Model")
	model.Name = "Barrel"
	model.Parent = village
	local barrel = makeCylinder(
		model,
		"WoodenBarrel",
		2.4 * scale,
		3.2 * scale,
		Vector3.new(x, y + 1.6 * scale, z),
		colors.wood,
		Enum.Material.WoodPlanks
	)
	for _, offset in { -1, 1 } do
		makeCylinder(
			model,
			"IronBand",
			2.48 * scale,
			0.18 * scale,
			Vector3.new(x, y + (1.6 + offset * 0.8) * scale, z),
			colors.stoneDark,
			Enum.Material.Metal
		)
	end
	return barrel
end

local function buildCrate(x, y, z, scale, yaw)
	local base = CFrame.new(x, y + scale, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	local crate =
		makePart(village, "CargoCrate", Vector3.new(2, 2, 2) * scale, base, colors.wood, Enum.Material.WoodPlanks)
	for _, axis in { -0.75, 0.75 } do
		localPart(
			village,
			"CrateBand",
			Vector3.new(0.18, 2.06, 2.08) * scale,
			base,
			Vector3.new(axis * scale, 0, 0),
			colors.woodDark,
			Enum.Material.WoodPlanks
		)
	end
	return crate
end

local function buildSteps(x, z, width, startY, endY, count, direction)
	local rise = (endY - startY) / count
	local run = 3.2
	for i = 1, count do
		local y = startY + rise * (i - 0.5)
		local offset = (i - (count + 1) / 2) * run
		local px = x + (if direction == "x" then offset else 0)
		local pz = z + (if direction == "z" then offset else 0)
		local size = if direction == "z"
			then Vector3.new(width, math.max(0.45, rise), run + 0.08)
			else Vector3.new(run + 0.08, math.max(0.45, rise), width)
		makePart(village, "StoneStep", size, CFrame.new(px, y, pz), colors.stoneLight, Enum.Material.Cobblestone)
	end
end

local function buildFence(x, y, z, length, yaw)
	local base = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0)
	local posts = math.max(2, math.floor(length / 5))
	for i = 0, posts do
		local xOffset = -length / 2 + length * i / posts
		localPart(
			village,
			"FencePost",
			Vector3.new(0.45, 3.2, 0.45),
			base,
			Vector3.new(xOffset, 1.6, 0),
			colors.woodDark,
			Enum.Material.WoodPlanks
		)
	end
	for _, h in { 1.1, 2.2 } do
		localPart(
			village,
			"FenceRail",
			Vector3.new(length, 0.35, 0.35),
			base,
			Vector3.new(0, h, 0),
			colors.wood,
			Enum.Material.WoodPlanks
		)
	end
end

-- Terraced terrain: low plaza, western rise, eastern upper quarter, northern craft hill.
makePart(village, "VillageGround", Vector3.new(360, 8, 300), CFrame.new(0, -4, 0), colors.grass, Enum.Material.Grass)
makePart(
	village,
	"WestTerrace",
	Vector3.new(118, 5, 154),
	CFrame.new(-101, 2.5, -5),
	colors.grassDark,
	Enum.Material.Grass
)
makePart(
	village,
	"WestRetainingWall",
	Vector3.new(3, 5, 154),
	CFrame.new(-41.5, 2.5, -5),
	colors.stone,
	Enum.Material.Rock
)
makePart(village, "EastTerrace", Vector3.new(122, 11, 166), CFrame.new(101, 5.5, -2), colors.grass, Enum.Material.Grass)
makePart(
	village,
	"EastRetainingWall",
	Vector3.new(3, 11, 166),
	CFrame.new(39.5, 5.5, -2),
	colors.stoneDark,
	Enum.Material.Rock
)
makePart(
	village,
	"NorthTerrace",
	Vector3.new(218, 17, 62),
	CFrame.new(0, 8.5, -119),
	colors.grassDark,
	Enum.Material.Grass
)
makePart(
	village,
	"NorthRetainingWall",
	Vector3.new(218, 17, 3),
	CFrame.new(0, 8.5, -87),
	colors.stone,
	Enum.Material.Rock
)

-- Main roads and the civic plaza.
makePart(
	village,
	"MainRoad",
	Vector3.new(22, 0.55, 178),
	CFrame.new(0, 0.28, 22),
	colors.road,
	Enum.Material.Cobblestone
)
makeCylinder(village, "CentralPlaza", 62, 0.65, Vector3.new(0, 0.33, -12), colors.stoneLight, Enum.Material.Cobblestone)
makePart(
	village,
	"WestLane",
	Vector3.new(105, 0.5, 12),
	CFrame.new(-92, 5.25, 22),
	colors.road,
	Enum.Material.Cobblestone
)
makePart(
	village,
	"WestBackLane",
	Vector3.new(12, 0.5, 118),
	CFrame.new(-108, 5.25, -15),
	colors.road,
	Enum.Material.Cobblestone
)
makePart(
	village,
	"EastLane",
	Vector3.new(112, 0.5, 12),
	CFrame.new(96, 11.25, 28),
	colors.road,
	Enum.Material.Cobblestone
)
makePart(
	village,
	"EastBackLane",
	Vector3.new(12, 0.5, 126),
	CFrame.new(105, 11.25, -9),
	colors.road,
	Enum.Material.Cobblestone
)
makePart(
	village,
	"CraftRoad",
	Vector3.new(174, 0.55, 14),
	CFrame.new(0, 17.3, -117),
	colors.road,
	Enum.Material.Cobblestone
)

buildSteps(-40, 25, 12, 0, 5, 5, "x")
buildSteps(40, 30, 12, 0, 11, 8, "x")
buildSteps(0, -78, 20, 0, 17, 10, "z")

-- Fountain and market establish a dense but readable center.
makeCylinder(village, "FountainBasin", 13, 2, Vector3.new(-13, 1, -12), colors.stoneDark, Enum.Material.Slate)
makeCylinder(village, "FountainWater", 10.5, 0.35, Vector3.new(-13, 2.05, -12), colors.water, Enum.Material.Glass).Transparency =
	0.25
makeCylinder(village, "FountainPillar", 2.2, 7, Vector3.new(-13, 5.2, -12), colors.stoneLight, Enum.Material.Marble)
makeBall(
	village,
	"FountainFinial",
	Vector3.new(3, 3, 3),
	Vector3.new(-13, 9.2, -12),
	colors.stoneLight,
	Enum.Material.Marble
)

for _, stall in
	{
		{ -24, 0, 5, 25, colors.roofRed },
		{ -7, 0, 12, 0, colors.roofBlue },
		{ 11, 0, 11, 0, colors.roofGreen },
		{ 24, 0, 2, -25, colors.roofRed },
		{ -26, 0, -29, 150, colors.roofBlue },
		{ 7, 0, -36, 180, colors.roofGreen },
	}
do
	buildStall(table.unpack(stall))
end

-- Lower-town buildings frame the road without closing the player's view.
for _, house in
	{
		{ -29, 0, 82, 90, 16, 14, 2, colors.plasterA, colors.roofRed, true },
		{ 30, 0, 88, -90, 18, 15, 2, colors.plasterC, colors.roofBlue, false },
		{ -31, 0, 51, 90, 14, 13, 1, colors.plasterB, colors.roofGreen, false },
		{ 31, 0, 53, -90, 15, 13, 2, colors.plasterA, colors.roofRed, true },
		{ -31, 0, -53, 90, 17, 14, 2, colors.plasterC, colors.roofBlue, false },
		{ 31, 0, -57, -90, 16, 14, 2, colors.plasterB, colors.roofGreen, true },
	}
do
	buildHouse(table.unpack(house))
end

-- Western artisan quarter, compact and irregular.
for _, house in
	{
		{ -65, 5, 63, 180, 18, 15, 2, colors.plasterA, colors.roofRed, false },
		{ -95, 5, 63, 180, 15, 13, 1, colors.plasterC, colors.roofBlue, true },
		{ -130, 5, 58, 180, 19, 15, 2, colors.plasterB, colors.roofGreen, false },
		{ -74, 5, -2, 0, 16, 14, 2, colors.plasterB, colors.roofBlue, true },
		{ -132, 5, 1, 0, 18, 15, 2, colors.plasterA, colors.roofRed, false },
		{ -72, 5, -58, 0, 18, 14, 1, colors.plasterC, colors.roofGreen, false },
		{ -112, 5, -68, 0, 16, 13, 2, colors.plasterA, colors.roofBlue, true },
	}
do
	buildHouse(table.unpack(house))
end

-- Eastern upper quarter has taller homes and small gardens.
for _, house in
	{
		{ 62, 11, 71, 180, 17, 14, 2, colors.plasterC, colors.roofBlue, false },
		{ 96, 11, 68, 180, 19, 15, 2, colors.plasterA, colors.roofRed, true },
		{ 132, 11, 58, 180, 16, 14, 1, colors.plasterB, colors.roofGreen, false },
		{ 69, 11, 1, 0, 18, 15, 2, colors.plasterA, colors.roofBlue, false },
		{ 133, 11, 2, 0, 17, 14, 2, colors.plasterC, colors.roofRed, true },
		{ 67, 11, -63, 0, 15, 13, 2, colors.plasterB, colors.roofGreen, false },
		{ 113, 11, -70, 0, 20, 16, 2, colors.plasterA, colors.roofBlue, false },
	}
do
	buildHouse(table.unpack(house))
end

-- Northern craft hill creates a destination and leaves a tower approach in the middle.
for _, house in
	{
		{ -79, 17, -128, 20, 22, 17, 2, colors.plasterB, colors.roofRed, true },
		{ -43, 17, -132, 10, 18, 15, 1, colors.plasterC, colors.roofBlue, true },
		{ 43, 17, -132, -10, 18, 15, 2, colors.plasterA, colors.roofGreen, true },
		{ 80, 17, -127, -20, 22, 17, 2, colors.plasterB, colors.roofBlue, true },
	}
do
	buildHouse(table.unpack(house))
end

-- Tower approach terminus; the tower itself will be supplied separately.
makeCylinder(village, "TowerApproach", 38, 1, Vector3.new(0, 17.5, -137), colors.stoneDark, Enum.Material.Slate)
for _, side in { -1, 1 } do
	makePart(
		village,
		"TowerGatePillar",
		Vector3.new(5, 16, 5),
		CFrame.new(side * 12, 25, -151),
		colors.stoneDark,
		Enum.Material.Brick
	)
	makePart(
		village,
		"GateBrazier",
		Vector3.new(3, 1, 3),
		CFrame.new(side * 12, 33.5, -151),
		colors.stone,
		Enum.Material.Metal
	)
	local flame = makeBall(
		village,
		"GateFlame",
		Vector3.new(2.1, 3.2, 2.1),
		Vector3.new(side * 12, 35.5, -151),
		colors.warm,
		Enum.Material.Neon
	)
	addPointLight(flame, colors.warm, 1.4, 24)
end

-- Canal and bridges break up the western silhouette.
local canal =
	makePart(village, "Canal", Vector3.new(12, 0.55, 252), CFrame.new(-158, 0.2, -5), colors.water, Enum.Material.Glass)
canal.Transparency = 0.22
for _, bridgeZ in { -58, 22, 72 } do
	makePart(
		village,
		"WoodBridge",
		Vector3.new(24, 1.2, 7),
		CFrame.new(-158, 1, bridgeZ),
		colors.wood,
		Enum.Material.WoodPlanks
	)
	buildFence(-158, 1.4, bridgeZ - 3.1, 24, 0)
	buildFence(-158, 1.4, bridgeZ + 3.1, 24, 0)
end

-- Lamps, trees, fences, and cargo fill empty sightlines without blocking routes.
for _, lamp in
	{
		{ -13, 0, 31 },
		{ 13, 0, 31 },
		{ -13, 0, 67 },
		{ 13, 0, 67 },
		{ -28, 0, -10 },
		{ 28, 0, -10 },
		{ -83, 5, 18 },
		{ -122, 5, 18 },
		{ 72, 11, 24 },
		{ 118, 11, 24 },
		{ -55, 17, -111 },
		{ 55, 17, -111 },
	}
do
	buildLamp(table.unpack(lamp))
end

for _, tree in
	{
		{ -46, 0, 108, 1.15 },
		{ 47, 0, 112, 1.1 },
		{ -20, 0, -73, 0.95 },
		{ -53, 5, 42, 0.9 },
		{ -89, 5, 40, 1.05 },
		{ -142, 5, 32, 0.95 },
		{ -53, 5, -38, 1.0 },
		{ -142, 5, -38, 1.1 },
		{ 50, 11, 48, 0.95 },
		{ 79, 11, 47, 1.0 },
		{ 145, 11, 31, 1.05 },
		{ 51, 11, -35, 0.9 },
		{ 143, 11, -40, 1.15 },
		{ -105, 17, -111, 0.85 },
		{ 105, 17, -111, 0.85 },
	}
do
	buildTree(table.unpack(tree))
end

buildFence(-101, 5, 76, 92, 0)
buildFence(103, 11, 81, 100, 0)
buildFence(-145, 5, -7, 120, 90)
buildFence(145, 11, -6, 130, 90)

for _, cargo in
	{
		{ -18, 0, 20 },
		{ 19, 0, 19 },
		{ -87, 5, -20 },
		{ -124, 5, -25 },
		{ 83, 11, -24 },
		{ 123, 11, -22 },
		{ -59, 17, -103 },
		{ 63, 17, -104 },
	}
do
	buildBarrel(cargo[1], cargo[2], cargo[3], rng:NextNumber(0.85, 1.15))
	buildCrate(cargo[1] + 3, cargo[2], cargo[3] + 1.5, rng:NextNumber(0.8, 1.15), rng:NextInteger(-20, 20))
end

-- Low perimeter rock shelves avoid a hard boxed-in arena while masking the base edge.
makePart(village, "SouthRockShelf", Vector3.new(360, 8, 8), CFrame.new(0, 0, 146), colors.stoneDark, Enum.Material.Rock)
makePart(
	village,
	"WestRockShelf",
	Vector3.new(8, 10, 300),
	CFrame.new(-176, 1, 0),
	colors.stoneDark,
	Enum.Material.Rock
)
makePart(village, "EastRockShelf", Vector3.new(8, 12, 300), CFrame.new(176, 2, 0), colors.stoneDark, Enum.Material.Rock)

local lighting = game:GetService("Lighting")
lighting.ClockTime = 16.4
lighting.Brightness = 2.2
lighting.Ambient = Color3.fromRGB(92, 82, 76)
lighting.OutdoorAmbient = Color3.fromRGB(128, 122, 114)
lighting.EnvironmentDiffuseScale = 0.45
lighting.EnvironmentSpecularScale = 0.3

local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Parent = lighting
end
atmosphere.Density = 0.22
atmosphere.Haze = 1.1
atmosphere.Color = Color3.fromRGB(202, 210, 214)
atmosphere.Decay = Color3.fromRGB(116, 105, 94)

village.PrimaryPart = village:FindFirstChild("VillageGround")
game:GetService("Selection"):Set({ village })
print("ArtisanVillage generated", #village:GetDescendants(), "instances")
