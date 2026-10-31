--!strict
--[[
	Alcor — 칼리스토 2페이지 소환체 알코르의 몸(2026-10-31). "성위는 떠돌이, 갈 곳 잃은 아이를 바로잡아"로 불려 나온
	작은 별(미자르 곁의 동반성). 적 칸 위에 떠서 천천히 돈다 — 공격하지 않는다.
	  빛나는 속별 + 겉 유리 껍질 + 엇갈린 고리 둘 + 네 갈래 빛살 + 푸른 점광원
	슬라임과 같은 틀(Pivot = 칸 바닥 가운데, 모든 부품 고정, Apply 가 매 프레임 자리를 다시 놓는다). 모션 채널은 Root 하나
	(Motions/Callisto 의 Alcor). 정면 = 모델 -Z.
]]

local Alcor = {}
Alcor.__index = Alcor

local RAD = math.pi / 180
local LIFT = 2.6

type Spec = { Name: string, Size: Vector3, At: CFrame, Color: Color3, Material: Enum.Material, Alpha: number, Shape: Enum.PartType? }

local CORE = Color3.fromRGB(235, 244, 255)
local GLOW = Color3.fromRGB(150, 200, 255)

local function specs(): { Spec }
	local list: { Spec } = {
		{ Name = "Core", Size = Vector3.new(1.1, 1.1, 1.1), At = CFrame.new(0, LIFT, 0), Color = CORE, Material = Enum.Material.Neon, Alpha = 0, Shape = Enum.PartType.Ball },
		{ Name = "Shell", Size = Vector3.new(1.8, 1.8, 1.8), At = CFrame.new(0, LIFT, 0), Color = GLOW, Material = Enum.Material.Glass, Alpha = 0.55, Shape = Enum.PartType.Ball },
		{ Name = "RingA", Size = Vector3.new(0.08, 2.8, 2.8), At = CFrame.new(0, LIFT, 0) * CFrame.Angles(0, 0, 90 * RAD), Color = GLOW, Material = Enum.Material.Neon, Alpha = 0.35, Shape = Enum.PartType.Cylinder },
		{ Name = "RingB", Size = Vector3.new(0.08, 2.4, 2.4), At = CFrame.new(0, LIFT, 0) * CFrame.Angles(60 * RAD, 0, 90 * RAD), Color = CORE, Material = Enum.Material.Neon, Alpha = 0.45, Shape = Enum.PartType.Cylinder },
	}
	-- 네 갈래 빛살(별 꼴)
	for i = 0, 3 do
		table.insert(list, {
			Name = "Ray" .. i,
			Size = Vector3.new(0.12, 1.6, 0.12),
			At = CFrame.new(0, LIFT, 0) * CFrame.Angles(0, 0, (i * 90 + 45) * RAD) * CFrame.new(0, 1.1, 0),
			Color = CORE,
			Material = Enum.Material.Neon,
			Alpha = 0.15,
		})
	end
	-- 둘레를 도는 별가루
	for i = 0, 2 do
		local a = i * 120 * RAD
		table.insert(list, {
			Name = "Mote" .. i,
			Size = Vector3.new(0.22, 0.22, 0.22),
			At = CFrame.new(math.cos(a) * 1.6, LIFT + 0.4 * math.sin(a * 2), math.sin(a) * 1.6),
			Color = CORE,
			Material = Enum.Material.Neon,
			Alpha = 0,
			Shape = Enum.PartType.Ball,
		})
	end
	return list
end

function Alcor.Build(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local pivot = Instance.new("Part")
	pivot.Name = "Pivot"
	pivot.Size = Vector3.new(0.2, 0.2, 0.2)
	pivot.Transparency = 1
	pivot.Anchored = true
	pivot.CanCollide, pivot.CanQuery, pivot.CanTouch = false, false, false
	pivot.Parent = model
	model.PrimaryPart = pivot
	for _, s in specs() do
		local p = Instance.new("Part")
		p.Name = s.Name
		p.Size = s.Size
		p.Color = s.Color
		p.Material = s.Material
		p.Transparency = s.Alpha
		if s.Shape then
			p.Shape = s.Shape
		end
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p:SetAttribute("Alpha", s.Alpha)
		p.Parent = model
	end
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 10
	light.Brightness = 2
	light.Parent = model:FindFirstChild("Core")
	return model
end

function Alcor.new(model: Model)
	local self = setmetatable({}, Alcor)
	self.Model = model
	self.Pivot = model:GetPivot()
	self.Fade = 0
	self.Parts = {}
	local rest: { [string]: CFrame } = {}
	for _, s in specs() do
		rest[s.Name] = s.At
	end
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and rest[p.Name] then
			table.insert(self.Parts, { Part = p, Rest = rest[p.Name], Ring = string.sub(p.Name, 1, 4) == "Ring" })
		end
	end
	return self
end

-- CombatRig 과 같은 이름(연출이 가리지 않고 부른다)
function Alcor:SetWeaponMotor() end
function Alcor:Take() end
function Alcor:Release() end

function Alcor:Apply(pose: any)
	local root = pose.Root or { 0, 0, 0, 0, 0, 0 }
	local base = self.Pivot * CFrame.new(root[1], root[2], root[3]) * CFrame.fromOrientation(root[4] * RAD, root[5] * RAD, root[6] * RAD)
	local primary = self.Model.PrimaryPart
	if primary then
		primary.CFrame = self.Pivot
	end
	-- 고리는 몸과 반대로 조금 더 돌아 엇갈려 보이게
	local counter = CFrame.new(0, LIFT, 0) * CFrame.fromOrientation(0, -root[5] * 2 * RAD, 0) * CFrame.new(0, -LIFT, 0)
	for _, e in self.Parts do
		e.Part.CFrame = base * (if e.Ring then counter * e.Rest else e.Rest)
		if self.Fade > 0 then
			local alpha = e.Part:GetAttribute("Alpha") :: number
			e.Part.Transparency = alpha + (1 - alpha) * self.Fade
		end
	end
end

return Alcor
