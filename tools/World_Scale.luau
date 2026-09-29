--!nocheck
--[[
	World_Scale.luau — 세상 전체를 원점 기준으로 K 배 한다.

	섬이 넓고 지은 것이 적어서 빈 데가 많았다. 지물을 세 배로 늘리는 대신
	세상을 1/3 로 줄인다. 캐릭터는 줄어들지 않으므로 사람 기준으로는
	세상이 세 배 빽빽해진다.

	**원점 기준으로 곱한다.** y=0 이 그대로 있어야 물가 높이가 어긋나지 않는다.

	같이 줄여야 하는 것들
	  파트의 Size 와 CFrame 의 위치. 회전은 그대로
	  PointLight 의 Range
	  ParticleEmitter 의 Size, Speed, Acceleration
	  숲 나무에 적어 둔 GY (앉힌 땅 높이)
	  탑 파편의 R (공전 반지름). S, P, T, SP 는 각도와 속도라 그대로
	  Lighting 의 FogStart, FogEnd

	**같이 줄이면 안 되는 것**
	  Ruins_화산. 캐릭터 키 5 를 기준으로 세운 도시라 1/3 이 되면
	  집이 4.7 높이가 되어 사람이 못 들어간다. 줄이기 전에 지우고
	  Zone_VolcanoRuins.luau 를 좌표만 1/3 로 고쳐 다시 돌린다

	되돌리기: K 를 역수로 두고 다시 돌린다. 누적 배율은 Surface 의
	WorldScale 속성에 적힌다
]]

local K = 1 / 3

local SKIP = {
	["Ruins_화산"] = true, -- 사람 치수로 세운 도시. 따로 다시 세운다
}

local S = workspace.Surface
local roots = { S }
local jeol = workspace:FindFirstChild("Jeolhwa_FIXED_ALL_VISIBLE")
if jeol then
	roots[#roots + 1] = jeol
end

-- 줄이면 안 되는 것은 먼저 지운다. 남겨 두면 섬만 작아지고 도시가 바다로 넘친다
for name in pairs(SKIP) do
	local f = S:FindFirstChild(name)
	if f then
		print("[Scale] 따로 다시 세울 것이라 지운다: " .. name .. " (" .. #f:GetDescendants() .. ")")
		f:Destroy()
	end
end

local function scaleSeq(seq)
	local kp = {}
	for _, k in ipairs(seq.Keypoints) do
		kp[#kp + 1] = NumberSequenceKeypoint.new(k.Time, k.Value * K, k.Envelope * K)
	end
	return NumberSequence.new(kp)
end

local parts, lights, emits, attrs = 0, 0, 0, 0
local t0 = os.clock()

for _, root in ipairs(roots) do
	local all = root:GetDescendants()
	for i, d in ipairs(all) do
		if d:IsA("BasePart") then
			d.Size = d.Size * K
			local cf = d.CFrame
			d.CFrame = cf.Rotation + cf.Position * K
			parts = parts + 1
		elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			d.Range = d.Range * K
			lights = lights + 1
		elseif d:IsA("ParticleEmitter") then
			d.Size = scaleSeq(d.Size)
			d.Speed = NumberRange.new(d.Speed.Min * K, d.Speed.Max * K)
			d.Acceleration = d.Acceleration * K
			emits = emits + 1
		end
		-- 길이를 적어 둔 속성
		if d:GetAttribute("GY") then
			d:SetAttribute("GY", d:GetAttribute("GY") * K)
			attrs = attrs + 1
		end
		if d:GetAttribute("R") then
			d:SetAttribute("R", d:GetAttribute("R") * K)
			attrs = attrs + 1
		end
		if i % 4000 == 0 then
			task.wait()
		end
	end
end

local L = game:GetService("Lighting")
L.FogStart = L.FogStart * K
L.FogEnd = L.FogEnd * K

local prev = S:GetAttribute("WorldScale") or 1
S:SetAttribute("WorldScale", prev * K)

--=== 자기검사 ===--
-- 줄인 뒤에도 섬이 물 위에 있어야 한다. 가장 높은 땅과 가장 낮은 땅을 잰다
local G = S:FindFirstChild("World")
local hi, lo, n = -1e9, 1e9, 0
if G then
	for _, p in ipairs(G:GetDescendants()) do
		if p:IsA("BasePart") then
			hi = math.max(hi, p.Position.Y + p.Size.Y / 2)
			lo = math.min(lo, p.Position.Y - p.Size.Y / 2)
			n = n + 1
		end
	end
end

print(string.format("[Scale] %.3f 배 / 파트 %d / 빛 %d / 파티클 %d / 속성 %d / %.1f초",
	K, parts, lights, emits, attrs, os.clock() - t0))
print(string.format("[Scale] 누적 배율 %.4f / 지면 %d조각 y %.1f..%.1f", prev * K, n, lo, hi))
assert(parts > 1000, "줄인 파트가 " .. parts .. "개뿐이다")
assert(hi > 0, "지면이 전부 물 아래로 내려갔다")
print("[Scale] 끝. 이제 Zone_VolcanoRuins.luau 를 좌표 1/3 로 고쳐 다시 돌려라")
