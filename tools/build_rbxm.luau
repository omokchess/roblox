--!nocheck
-- Part 버전 에셋 변환기 (Lune): assets/parts/*.json + manifest.json + palette.json -> assets/rbxm/{server,replicated}/*.rbxm
--   실행:  lune run tools/build_rbxm.luau
--
-- 생성되는 모델 구조
--   Model <Name>            (Attributes: AssetName, Category, Kind="Parts", ... )
--     Anchor (Part, PrimaryPart, 원점, 투명)   └ Attachment 마커들 / Light_n (PointLight, SpotLight)
--     Visual (Model)       ├ 파트 (Main 그룹)  └ <그룹명> (Model) …
--     Colliders (Folder)   └ 투명 충돌 파트 (Block/Cylinder/Truss, Attribute Tag)

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local Color3 = roblox.Color3
local Enum = roblox.Enum

local ROOT = "."
local manifest = serde.decode("json", fs.readFile(ROOT .. "/assets/manifest.json"))
local palette = serde.decode("json", fs.readFile(ROOT .. "/assets/palette.json"))

local function cf(pos, rot)
	return CFrame.new(pos[1], pos[2], pos[3], rot[1], rot[2], rot[3], rot[4], rot[5], rot[6], rot[7], rot[8], rot[9])
end

local function applyPalette(part, key)
	local info = palette[key]
	if not info then
		error("palette key missing: " .. tostring(key))
	end
	part.Material = (Enum.Material :: any)[info.material]
	part.Color = Color3.fromRGB(info.color[1], info.color[2], info.color[3])
	part.Transparency = info.transparency or 0
	part.Reflectance = info.reflectance or 0
end

local function toAttr(v)
	local t = type(v)
	if t == "table" then
		if #v == 3 and type(v[1]) == "number" then
			return Vector3.new(v[1], v[2], v[3])
		end
		return serde.encode("json", v)
	end
	return v
end

local function newPart(className)
	local p = Instance.new(className)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local SHAPES = { B = "Block", C = "Cylinder", S = "Ball" }

local function build(name, info, partsData)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("AssetName", name)
	model:SetAttribute("Category", info.category)
	model:SetAttribute("Kind", "Parts")
	model:SetAttribute("Description", info.description or "")
	model:SetAttribute("Replicated", info.replicated == true)
	for k, v in info.attributes or {} do
		model:SetAttribute(k, toAttr(v))
	end

	local anchor = newPart("Part")
	anchor.Name = "Anchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.CastShadow = false
	anchor.CFrame = CFrame.new(0, 0, 0)
	anchor.Parent = model
	model.PrimaryPart = anchor

	local visual = Instance.new("Model")
	visual.Name = "Visual"
	visual.Parent = model
	local groups = {}
	local function groupFolder(g)
		if g == nil or g == "Main" then
			return visual
		end
		local f = groups[g]
		if not f then
			f = Instance.new("Model")
			f.Name = g
			f.Parent = visual
			groups[g] = f
		end
		return f
	end

	for _, p in partsData do
		local part
		if p.s == "W" then
			part = newPart("WedgePart")
		else
			part = newPart("Part")
			part.Shape = (Enum.PartType :: any)[SHAPES[p.s]]
		end
		part.Name = p.k
		part.Size = Vector3.new(p.z[1], p.z[2], p.z[3])
		part.CFrame = cf(p.p, p.r)
		applyPalette(part, p.k)
		part.CastShadow = p.sh == true
		part.Parent = groupFolder(p.g)
	end

	local colliders = Instance.new("Folder")
	colliders.Name = "Colliders"
	colliders.Parent = model
	for i, c in info.colliders do
		local part
		if c.shape == "Truss" then
			part = newPart("TrussPart")
			part.Style = Enum.Style.NoSupports
		else
			part = newPart("Part")
			part.Shape = c.shape == "Cylinder" and Enum.PartType.Cylinder or Enum.PartType.Block
		end
		part.Name = c.tag or ("Collider" .. i)
		part.Size = Vector3.new(c.size[1], c.size[2], c.size[3])
		part.CFrame = cf(c.pos, c.rot)
		part.Transparency = 1
		part.CastShadow = false
		part.CanCollide = true
		part.CanQuery = true
		part.Material = Enum.Material.WoodPlanks
		part:SetAttribute("Tag", c.tag or "")
		if c.group and c.group ~= "Main" then
			part:SetAttribute("Group", c.group)
		end
		part.Parent = colliders
	end

	for _, m in info.markers do
		local a = Instance.new("Attachment")
		a.Name = m.name
		a.CFrame = cf(m.pos, m.rot)
		for k, v in m.attrs or {} do
			a:SetAttribute(k, toAttr(v))
		end
		if m.group and m.group ~= "Main" then
			a:SetAttribute("Group", m.group)
		end
		a.Parent = anchor
	end

	for i, L in info.lights do
		local a = Instance.new("Attachment")
		a.Name = "Light_" .. i
		a.CFrame = CFrame.new(L.pos[1], L.pos[2], L.pos[3])
		if L.group and L.group ~= "Main" then
			a:SetAttribute("Group", L.group)
		end
		local light
		if L.kind == "Spot" then
			light = Instance.new("SpotLight")
			light.Angle = L.angle or 60
		else
			light = Instance.new("PointLight")
		end
		light.Color = Color3.fromRGB(L.color[1], L.color[2], L.color[3])
		light.Range = L.range
		light.Brightness = L.brightness
		light.Shadows = L.shadows == true
		light.Parent = a
		a.Parent = anchor
	end

	model.WorldPivot = CFrame.new(0, 0, 0)
	return model
end

fs.writeDir(ROOT .. "/assets/rbxm/server")
fs.writeDir(ROOT .. "/assets/rbxm/replicated")

local names = {}
for name in manifest do
	table.insert(names, name)
end
table.sort(names)

local total = 0
for _, name in names do
	local info = manifest[name]
	local path = ROOT .. "/assets/parts/" .. name .. ".json"
	if fs.isFile(path) then
		local pdata = serde.decode("json", fs.readFile(path))
		local model = build(name, info, pdata.parts)
		local dir = info.replicated and "replicated" or "server"
		fs.writeFile(ROOT .. "/assets/rbxm/" .. dir .. "/" .. name .. ".rbxm", roblox.serializeModel({ model }))
		total += #pdata.parts
		print(string.format("[rbxm] %-22s %5d parts -> %s", name, #pdata.parts, dir))
	end
end
print(string.format("[rbxm] %d assets, %d parts total", #names, total))
