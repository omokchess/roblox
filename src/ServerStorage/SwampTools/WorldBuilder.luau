--!strict
-- 월드 빌더: 지형(바다+섬) → 에셋 배치 → 소품 연출(간판, 불, 연기, 좌석, 부표, 등대 빔) → 스폰/경계.
-- 서버 시작 시(WorldService) 또는 Studio 명령창/플러그인에서 호출:
--     require(game.ServerStorage.SwampTools.WorldBuilder).Build()

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = Shared:WaitForChild("World")
local WorldConfig = require(World:WaitForChild("WorldConfig"))
local WorldData = require(World:WaitForChild("WorldData"))
local AssetLibrary = require(World:WaitForChild("AssetLibrary"))
local TerrainBuilder = require(script.Parent:WaitForChild("TerrainBuilder"))

local Placements = require(World:WaitForChild("Generated"):WaitForChild("Placements")) :: { { a: string, p: { number }, r: number, s: number, i: string? } }

local WorldBuilder = {}

local ROOT_NAME = "SwampWorld"
local TEX = {
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
}

export type BuildOptions = {
	Terrain: boolean?,
	Placements: boolean?,
	Clear: boolean?,
	Verbose: boolean?,
}

local function log(opts: BuildOptions?, ...: any)
	if opts == nil or opts.Verbose ~= false then
		print("[SwampWorld]", ...)
	end
end

local function makeYielder(): () -> ()
	local last = os.clock()
	return function()
		if os.clock() - last > 0.05 then
			if RunService:IsRunning() then
				task.wait()
			end
			last = os.clock()
		end
	end
end

local function sub(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing :: Folder
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function root(): Folder
	return sub(workspace, ROOT_NAME)
end

-- ─────────────────────────────────────────────────────────────
-- 소품 연출
-- ─────────────────────────────────────────────────────────────

local function invisiblePart(name: string, cf: CFrame, size: Vector3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function surfaceText(part: BasePart, text: string, color: Color3?, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.6
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = font or Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color or Color3.fromRGB(58, 40, 26)
	label.Text = text
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.06, 0)
	pad.PaddingBottom = UDim.new(0.06, 0)
	pad.Parent = label
end

local function fireEmitter(parent: Instance, green: boolean?)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Flames"
	e.Texture = TEX.Fire
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = 28
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Acceleration = Vector3.new(0, 3, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(0.5, 1.1), NumberSequenceKeypoint.new(1, 0.1) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.7, 0.5), NumberSequenceKeypoint.new(1, 1) })
	if green then
		e.Color = ColorSequence.new(Color3.fromRGB(150, 255, 170), Color3.fromRGB(40, 200, 140))
	else
		e.Color = ColorSequence.new(Color3.fromRGB(255, 200, 110), Color3.fromRGB(255, 90, 30))
	end
	e.Parent = parent
end

local function smokeEmitter(parent: Instance, green: boolean?)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Smoke"
	e.Texture = TEX.Smoke
	e.Rate = 3
	e.Lifetime = NumberRange.new(4, 7)
	e.Speed = NumberRange.new(2, 3.5)
	e.SpreadAngle = Vector2.new(8, 8)
	e.Acceleration = Vector3.new(1.2, 0.6, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-20, 20)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 6) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	e.Color = if green then ColorSequence.new(Color3.fromRGB(150, 200, 150)) else ColorSequence.new(Color3.fromRGB(170, 170, 170))
	e.LightInfluence = 1
	e.Parent = parent
end

local function bubbleEmitter(parent: Instance)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Bubbles"
	e.Texture = TEX.Sparkle
	e.Rate = 10
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(1, 2)
	e.SpreadAngle = Vector2.new(40, 40)
	e.LightEmission = 0.8
	e.Size = NumberSequence.new(0.35, 0.1)
	e.Color = ColorSequence.new(Color3.fromRGB(150, 255, 110))
	e.Parent = parent
end

local function sound(parent: Instance, id: string, volume: number, looped: boolean, maxDist: number)
	if id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Looped = looped
	s.RollOffMaxDistance = maxDist
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.Parent = parent
	if looped then
		s:Play()
	end
end

local function decorate(model: Model, placement: { a: string, i: string? })
	local fx = sub(model, "FX")
	local anchor = model:FindFirstChild("Anchor") :: BasePart?
	if not anchor then
		return
	end
	local island = placement.i or ""
	local texts = WorldConfig.SignTexts[island] or {}
	for _, a in anchor:GetChildren() do
		if not a:IsA("Attachment") then
			continue
		end
		local name = a.Name
		local cf = a.WorldCFrame
		local w = (a:GetAttribute("width") :: number?) or 4
		local h = (a:GetAttribute("height") :: number?) or 1
		if name == "Sign" or name == "NamePlate" or string.match(name, "^Sign[ABC]$") then
			local text = (a:GetAttribute("text") :: string?) or texts[name] or ""
			if text ~= "" then
				local p = invisiblePart(name .. "Face", cf * CFrame.new(0, 0, -0.06), Vector3.new(w, h, 0.05), fx)
				surfaceText(p, text, if name == "NamePlate" then Color3.fromRGB(230, 196, 110) else nil, Enum.Font.Fantasy)
			end
		elseif name == "Board" then
			local p = invisiblePart("BoardFace", cf * CFrame.new(0, 0, -0.08), Vector3.new(w, h, 0.05), fx)
			surfaceText(p, WorldConfig.NoticeText, Color3.fromRGB(46, 34, 24), Enum.Font.Gotham)
			local label = (p:FindFirstChild("SignGui") :: SurfaceGui):FindFirstChild("Text") :: TextLabel
			label.TextXAlignment = Enum.TextXAlignment.Left
		elseif name == "ScheduleBoard" then
			local p = invisiblePart("ScheduleFace", cf * CFrame.new(0, 0, -0.08), Vector3.new(w, h, 0.05), fx)
			surfaceText(p, "연락선 시간표", Color3.fromRGB(46, 34, 24), Enum.Font.GothamBold)
			CollectionService:AddTag(p, "FerryScheduleBoard")
			p:SetAttribute("Stop", island)
		elseif name == "Fire" then
			local p = invisiblePart("Fire", cf, Vector3.new(1, 1, 1), fx)
			fireEmitter(p)
			smokeEmitter(p)
			sound(p, WorldConfig.Sounds.Fire, 0.5, true, 40)
			CollectionService:AddTag(p, "SwampFlicker")
		elseif name == "Flame" then
			local p = invisiblePart("Flame", cf, Vector3.new(1, 1, 1), fx)
			fireEmitter(p, true)
			CollectionService:AddTag(p, "SwampFlicker")
		elseif name == "Smoke" then
			local p = invisiblePart("Smoke", cf, Vector3.new(1, 1, 1), fx)
			smokeEmitter(p, a:GetAttribute("color") == "green")
		elseif name == "Cauldron" then
			local p = invisiblePart("Cauldron", cf, Vector3.new(2, 0.2, 2), fx)
			bubbleEmitter(p)
			smokeEmitter(p, true)
		elseif name == "Seat" then
			local seat = Instance.new("Seat")
			seat.Name = "Seat"
			seat.Anchored = true
			seat.Transparency = 1
			seat.CanCollide = false
			seat.Size = Vector3.new(2, 0.2, 2)
			seat.CFrame = cf
			seat.Parent = fx
		elseif name == "Beacon" then
			local p = invisiblePart("Beacon", cf, Vector3.new(1, 1, 1), fx)
			for _, yaw in { 0, 180 } do
				local att = Instance.new("Attachment")
				att.CFrame = CFrame.Angles(0, math.rad(yaw), 0)
				att.Parent = p
				local spot = Instance.new("SpotLight")
				spot.Angle = 24
				spot.Range = 60
				spot.Brightness = 6
				spot.Color = Color3.fromRGB(255, 236, 190)
				spot.Face = Enum.NormalId.Front
				spot.Parent = att
			end
			CollectionService:AddTag(p, "SwampBeacon")
		elseif name == "Orb" then
			CollectionService:AddTag(model, "SwampOrb")
		elseif name == "DepartureBell" or name == "Bell" then
			sound(invisiblePart("BellSound", cf, Vector3.new(1, 1, 1), fx), WorldConfig.Sounds.Bell, 1, false, 180)
		end
	end
	if placement.a == "Buoy" then
		CollectionService:AddTag(model, "SwampBuoy")
	end
	if placement.a == "FerryDock" then
		model:SetAttribute("Stop", island)
		CollectionService:AddTag(model, "SwampFerryDock")
	end
	-- 모든 조명: 밤/낮 밝기 조절 대상
	for _, d in anchor:GetDescendants() do
		if d:IsA("Light") then
			d:SetAttribute("BaseBrightness", d.Brightness)
			CollectionService:AddTag(d, "SwampLamp")
		end
	end
end

-- ─────────────────────────────────────────────────────────────
-- 배치
-- ─────────────────────────────────────────────────────────────

function WorldBuilder.PlaceAll(opts: BuildOptions?)
	local r = root()
	local placed = sub(r, "Placed")
	local offset = WorldConfig.GetOffset()
	local yielder = makeYielder()
	local missing: { [string]: number } = {}
	local count = 0
	for _, pl in Placements do
		local island = pl.i or "Misc"
		if WorldConfig.Islands[island] == false then
			continue
		end
		local template = AssetLibrary.Get(pl.a)
		if not template then
			missing[pl.a] = (missing[pl.a] or 0) + 1
			continue
		end
		local m = template:Clone()
		if pl.s and math.abs(pl.s - 1) > 1e-3 then
			pcall(function()
				m:ScaleTo(pl.s)
			end)
		end
		m:PivotTo(CFrame.new(Vector3.new(pl.p[1], pl.p[2], pl.p[3]) + offset) * CFrame.Angles(0, math.rad(pl.r), 0))
		m:SetAttribute("AssetName", pl.a)
		m.Parent = sub(placed, island)
		decorate(m, pl)
		count += 1
		yielder()
	end
	-- 항로 부표
	for _, pos in WorldData.Buoys() do
		local t = AssetLibrary.Get("Buoy")
		if t then
			local m = t:Clone()
			m:PivotTo(CFrame.new(pos))
			m.Parent = sub(placed, "Sea")
			decorate(m, { a = "Buoy", i = "Sea" })
			count += 1
		end
	end
	for name, n in missing do
		warn(string.format("[SwampWorld] 에셋 템플릿 없음: %s (%d개 배치 생략)", name, n))
	end
	log(opts, "배치 완료:", count)
end

local function spawns()
	if not WorldConfig.CreateSpawnLocations then
		return
	end
	local folder = sub(root(), "Spawns")
	folder:ClearAllChildren()
	for _, s in WorldData.SpawnPoints() do
		local sp = Instance.new("SpawnLocation")
		sp.Name = "Spawn_" .. s.Name
		sp.Anchored = true
		sp.CanCollide = false
		sp.Transparency = 1
		sp.Size = Vector3.new(8, 1, 8)
		sp.CFrame = CFrame.new(s.P + Vector3.new(0, 0.5, 0))
		sp.Neutral = true
		sp.Duration = 3
		sp.Enabled = s.Name == "Harbor"
		sp.Parent = folder
		local decal = sp:FindFirstChildOfClass("Decal")
		if decal then
			decal:Destroy()
		end
	end
end

local function seaWalls()
	if not WorldConfig.SeaWalls then
		return
	end
	local folder = sub(root(), "SeaWalls")
	folder:ClearAllChildren()
	local mn, mx = WorldData.SeaBounds()
	local cx, cz = (mn.X + mx.X) / 2, (mn.Z + mx.Z) / 2
	local sx, sz = mx.X - mn.X, mx.Z - mn.Z
	local H = 400
	local defs: { { cf: CFrame, size: Vector3 } } = {
		{ cf = CFrame.new(cx, 100, mn.Z - 4), size = Vector3.new(sx + 16, H, 8) },
		{ cf = CFrame.new(cx, 100, mx.Z + 4), size = Vector3.new(sx + 16, H, 8) },
		{ cf = CFrame.new(mn.X - 4, 100, cz), size = Vector3.new(8, H, sz + 16) },
		{ cf = CFrame.new(mx.X + 4, 100, cz), size = Vector3.new(8, H, sz + 16) },
	}
	for i, d in defs do
		local p = invisiblePart("SeaWall" .. i, d.cf, d.size, folder)
		p.CanCollide = true
	end
end

-- ─────────────────────────────────────────────────────────────
-- 조명 / 물
-- ─────────────────────────────────────────────────────────────

function WorldBuilder.ApplyLighting()
	local Lighting = game:GetService("Lighting")
	local terrain = workspace.Terrain
	local w = WorldConfig.Water
	terrain.WaterColor = w.Color
	terrain.WaterTransparency = w.Transparency
	terrain.WaterReflectance = w.Reflectance
	terrain.WaterWaveSize = w.WaveSize
	terrain.WaterWaveSpeed = w.WaveSpeed
	if not WorldConfig.ApplyLighting then
		return
	end
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	local sea = WorldConfig.Zones.Sea.Atmosphere
	atmo.Density = sea.Density
	atmo.Offset = sea.Offset
	atmo.Color = sea.Color
	atmo.Decay = sea.Decay
	atmo.Glare = sea.Glare
	atmo.Haze = sea.Haze
	atmo.Parent = Lighting
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.SunAngularSize = 12
		sky.MoonAngularSize = 9
		sky.StarCount = 3000
		sky.Parent = Lighting
	end
	local names = { "SwampBloom", "SwampColor", "SwampSunRays", "SwampDepth" }
	for _, n in names do
		local e = Lighting:FindFirstChild(n)
		if e then
			e:Destroy()
		end
	end
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "SwampBloom"
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SwampColor"
	cc.Saturation = 0.05
	cc.Contrast = 0.05
	cc.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Name = "SwampSunRays"
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting
	local dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "SwampDepth"
	dof.FarIntensity = 0.12
	dof.FocusDistance = 60
	dof.InFocusRadius = 80
	dof.NearIntensity = 0
	dof.Parent = Lighting
end

-- ─────────────────────────────────────────────────────────────
-- 공개 API
-- ─────────────────────────────────────────────────────────────

function WorldBuilder.BuildTerrain(opts: BuildOptions?)
	local offset = WorldConfig.GetOffset()
	local yielder = makeYielder()
	local raw = WorldData.Raw()
	local t0 = os.clock()
	local mn, mx = WorldData.SeaBounds()
	TerrainBuilder.FillSea(Vector3.new(mn.X, offset.Y, mn.Z), Vector3.new(mx.X, offset.Y, mx.Z), WorldConfig.WaterLevel + offset.Y, yielder)
	log(opts, string.format("바다 채움 (%.1fs)", os.clock() - t0))
	for _, name in WorldData.IslandNames() do
		local t1 = os.clock()
		TerrainBuilder.BuildIsland(WorldData.IslandData(name), raw.MaterialNames, offset, WorldConfig.WaterLevel + offset.Y, yielder)
		log(opts, string.format("섬 지형 %s (%.1fs)", name, os.clock() - t1))
	end
end

function WorldBuilder.Clear(opts: BuildOptions?)
	local r = workspace:FindFirstChild(ROOT_NAME)
	if r then
		r:Destroy()
	end
	if opts == nil or opts.Terrain ~= false then
		TerrainBuilder.Clear()
	end
	workspace:SetAttribute("SwampWorldVersion", nil)
end

-- 배치만 다시 (메시 임포트 후 AssetSetup 에서 호출)
function WorldBuilder.RebuildPlacements(opts: BuildOptions?)
	local r = workspace:FindFirstChild(ROOT_NAME)
	if r then
		local placed = r:FindFirstChild("Placed")
		if placed then
			placed:Destroy()
		end
	end
	WorldBuilder.PlaceAll(opts)
end

function WorldBuilder.Build(opts: BuildOptions?)
	local o: BuildOptions = opts or {}
	local t0 = os.clock()
	if o.Clear then
		WorldBuilder.Clear(o)
	end
	WorldBuilder.ApplyLighting()
	if o.Terrain ~= false and WorldConfig.BuildTerrain then
		WorldBuilder.BuildTerrain(o)
	end
	if o.Placements ~= false and WorldConfig.BuildPlacements then
		local r = workspace:FindFirstChild(ROOT_NAME)
		local placed = r and r:FindFirstChild("Placed")
		if placed then
			placed:Destroy()
		end
		WorldBuilder.PlaceAll(o)
	end
	spawns()
	seaWalls()
	workspace:SetAttribute("SwampWorldVersion", WorldConfig.Version)
	log(o, string.format("월드 생성 완료 (%.1fs)", os.clock() - t0))
end

function WorldBuilder.IsBuilt(): boolean
	return workspace:GetAttribute("SwampWorldVersion") == WorldConfig.Version and workspace:FindFirstChild(ROOT_NAME) ~= nil
end

return WorldBuilder
