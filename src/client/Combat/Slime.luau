--!strict
--[[
	Slime — 슬라임 모양과 몸 변형. (2026-09-28)

	맵 양식대로 블록을 쌓아 만든다: 반투명 젤리 몸(아래가 넓은 3단) + 속 알맹이 + 눈·볼·입 + 바닥 방울.
	모든 부품은 고정(Anchored)이고, `Apply(pose)` 가 매 프레임 바닥 가운데(Pivot)를 기준으로
	Body(늘고 줄기) 비율만큼 자리와 크기를 바꿔 다시 놓는다. 모션 채널 뜻은 Motions/Slime.luau.
	정면 = 모델 -Z (아군 쪽).
]]

local Slime = {}
Slime.__index = Slime

local RAD = math.pi / 180

type PartSpec = { Name: string, Size: Vector3, At: Vector3, Color: Color3, Material: Enum.Material, Alpha: number, Face: boolean?, Spin: number? }

local JELLY = Color3.fromRGB(96, 214, 88)
local CORE = Color3.fromRGB(40, 120, 44)

-- 바닥 가운데 기준 자리(At = 부품 가운데)
local function specs(color: Color3): { PartSpec }
	local dk = color:Lerp(Color3.new(0, 0, 0), 0.28)
	return {
		{ Name = "Base", Size = Vector3.new(3.6, 1.3, 3.6), At = Vector3.new(0, 0.65, 0), Color = color, Material = Enum.Material.Glass, Alpha = 0.3 },
		{ Name = "Mid", Size = Vector3.new(3.2, 0.9, 3.2), At = Vector3.new(0, 1.75, 0), Color = color, Material = Enum.Material.Glass, Alpha = 0.3 },
		{ Name = "Top", Size = Vector3.new(2.4, 0.55, 2.4), At = Vector3.new(0, 2.47, 0), Color = color, Material = Enum.Material.Glass, Alpha = 0.3 },
		{ Name = "Core", Size = Vector3.new(1.1, 1.1, 1.1), At = Vector3.new(0.2, 1.2, 0.4), Color = CORE, Material = Enum.Material.SmoothPlastic, Alpha = 0.05, Spin = 38 },
		{ Name = "Glint", Size = Vector3.new(0.5, 0.18, 0.5), At = Vector3.new(-0.8, 2.78, -0.5), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Alpha = 0.35 },
		{ Name = "EyeL", Size = Vector3.new(0.42, 0.66, 0.1), At = Vector3.new(-0.62, 1.7, -1.62), Color = Color3.fromRGB(24, 30, 26), Material = Enum.Material.SmoothPlastic, Alpha = 0, Face = true },
		{ Name = "EyeR", Size = Vector3.new(0.42, 0.66, 0.1), At = Vector3.new(0.62, 1.7, -1.62), Color = Color3.fromRGB(24, 30, 26), Material = Enum.Material.SmoothPlastic, Alpha = 0, Face = true },
		{ Name = "ShineL", Size = Vector3.new(0.16, 0.16, 0.06), At = Vector3.new(-0.55, 1.86, -1.68), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Alpha = 0, Face = true },
		{ Name = "ShineR", Size = Vector3.new(0.16, 0.16, 0.06), At = Vector3.new(0.69, 1.86, -1.68), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Alpha = 0, Face = true },
		{ Name = "Mouth", Size = Vector3.new(0.5, 0.12, 0.08), At = Vector3.new(0, 1.2, -1.62), Color = Color3.fromRGB(24, 30, 26), Material = Enum.Material.SmoothPlastic, Alpha = 0, Face = true },
		{ Name = "BlushL", Size = Vector3.new(0.4, 0.14, 0.06), At = Vector3.new(-1.1, 1.3, -1.61), Color = Color3.fromRGB(255, 140, 150), Material = Enum.Material.SmoothPlastic, Alpha = 0.2, Face = true },
		{ Name = "BlushR", Size = Vector3.new(0.4, 0.14, 0.06), At = Vector3.new(1.1, 1.3, -1.61), Color = Color3.fromRGB(255, 140, 150), Material = Enum.Material.SmoothPlastic, Alpha = 0.2, Face = true },
		{ Name = "DripA", Size = Vector3.new(0.6, 0.3, 0.6), At = Vector3.new(1.75, 0.15, 1.2), Color = dk, Material = Enum.Material.Glass, Alpha = 0.25 },
		{ Name = "DripB", Size = Vector3.new(0.5, 0.26, 0.5), At = Vector3.new(-1.8, 0.13, -0.9), Color = dk, Material = Enum.Material.Glass, Alpha = 0.25 },
		{ Name = "DripC", Size = Vector3.new(0.45, 0.22, 0.45), At = Vector3.new(-1.3, 0.11, 1.8), Color = dk, Material = Enum.Material.Glass, Alpha = 0.25 },
	}
end

function Slime.Build(name: string, color: Color3?): Model
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
	for _, s in specs(color or JELLY) do
		local p = Instance.new("Part")
		p.Name = s.Name
		p.Size = s.Size
		p.Color = s.Color
		p.Material = s.Material
		p.Transparency = s.Alpha
		p.Anchored = true
		p.CanCollide, p.CanTouch = false, false
		-- 격자 칸을 찾는 광선이 슬라임에 막히지 않게
		p.CanQuery = false
		p.CastShadow = s.Material ~= Enum.Material.Neon
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p:SetAttribute("RestX", s.At.X)
		p:SetAttribute("RestY", s.At.Y)
		p:SetAttribute("RestZ", s.At.Z)
		p:SetAttribute("Spin", s.Spin or 0)
		p:SetAttribute("Face", s.Face == true)
		p:SetAttribute("Alpha", s.Alpha)
		p.Parent = model
	end
	return model
end

--=== 몸 변형(CombatAnimator 가 부르는 rig) ===--

function Slime.new(model: Model)
	local self = setmetatable({}, Slime)
	self.Model = model
	self.Pivot = model:GetPivot()
	self.Parts = {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "Pivot" then
			table.insert(self.Parts, {
				Part = p,
				Rest = Vector3.new(p:GetAttribute("RestX") :: number, p:GetAttribute("RestY") :: number, p:GetAttribute("RestZ") :: number),
				Size = p.Size,
				Spin = (p:GetAttribute("Spin") :: number) * RAD,
				Face = p:GetAttribute("Face") == true,
				Eye = p.Name == "EyeL" or p.Name == "EyeR",
				Shine = p.Name == "ShineL" or p.Name == "ShineR",
				Left = string.sub(p.Name, -1) == "L",
			})
		end
	end
	self.Fade = 0
	return self
end

-- CombatRig 과 같은 이름(연출이 가리지 않고 부른다)
function Slime:SetWeaponMotor() end
function Slime:Take() end
function Slime:Release() end

function Slime:Apply(pose: any)
	local root = pose.Root or { 0, 0, 0, 0, 0, 0 }
	local body = pose.Body or { 0, 0, 0 }
	local eyes = pose.Eyes or { 0, 0 }
	local sx, sy, sz = 1 + body[1] / 100, 1 + body[2] / 100, 1 + body[3] / 100
	local base = self.Pivot * CFrame.new(root[1], root[2], root[3]) * CFrame.fromOrientation(root[4] * RAD, root[5] * RAD, root[6] * RAD)
	local blink = math.clamp(eyes[1] / 100, 0, 1)
	local angry = math.clamp(eyes[2] / 100, 0, 1)
	-- 기준 파트(이름표가 붙는 PrimaryPart)도 따라온다. 안 옮기면 적이 칸을 바꿀 때 이름표만 옛 칸에 남는다.
	local primary = self.Model.PrimaryPart
	if primary then
		primary.CFrame = self.Pivot
	end
	for _, e in self.Parts do
		local rest = e.Rest
		local pos = Vector3.new(rest.X * sx, rest.Y * sy, rest.Z * sz)
		local size: Vector3
		local rot = CFrame.identity
		if e.Face then
			-- 얼굴 부품은 몸이 퍼지는 만큼 자리만 따라가고 크기는 덜 변한다(얼굴이 뭉개지지 않게)
			local k = (sx + sy) / 2
			size = e.Size * Vector3.new(0.5 + 0.5 * sx, 0.5 + 0.5 * sy, 1) * (0.9 + 0.1 * k)
			if e.Eye then
				size = Vector3.new(size.X, math.max(0.06, size.Y * (1 - blink * 0.9)), size.Z)
				rot = CFrame.Angles(0, 0, (if e.Left then -1 else 1) * angry * 0.45)
			elseif e.Shine then
				size = size * (1 - blink)
			end
		else
			size = Vector3.new(e.Size.X * sx, e.Size.Y * sy, e.Size.Z * sz)
		end
		e.Part.Size = size
		e.Part.CFrame = base * CFrame.new(pos) * rot * CFrame.Angles(0, e.Spin, 0)
		if self.Fade > 0 then
			local alpha = e.Part:GetAttribute("Alpha") :: number
			e.Part.Transparency = alpha + (1 - alpha) * self.Fade
		end
	end
end

return Slime
