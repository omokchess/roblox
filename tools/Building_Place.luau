--!nocheck
--[[
	Building_Place.luau — 블렌더에서 가져온 한옥 건물에 색을 입히고 앉힌다.

	**궁이 아니라 일반 건물 모델이다.** 안은 비어 있고 어디에나 갖다 쓴다.

	**가져오기만 하면 또 단색이 된다.** 로블록스는 메시 하나에 색 하나를 준다.
	그래서 블렌더에서 재질마다 오브젝트를 갈라 내보냈고, 여기서 이름을 보고
	월드에서 실측해 뽑은 팔레트를 하나씩 입힌다.

	지금 앉히는 자리는 광장 북쪽 빈 땅이다. X, Z, YAW 만 바꾸면 다른 데로 옮긴다. 지면을 재서 기단 밑이 땅에 닿게 내린다.
	모델 원점은 기단 바닥 한가운데이고, 블렌더에서 -Z 를 정면으로 내보냈으므로
	로블록스에서도 -Z 를 본다. 광장을 보게 180 도 돌린다.

	되돌리기: Workspace.Building_Hall 을 지운다
]]

local RGB = Color3.fromRGB
local M = Enum.Material

-- 블렌더 PALETTE 와 같은 값이다. 한쪽만 고치면 어긋난다
local SKIN = {
	Stylobate = { RGB(193, 190, 176), M.Limestone },
	Stairs = { RGB(197, 194, 179), M.Limestone },
	Plinth = { RGB(169, 165, 151), M.Limestone },
	Column = { RGB(138, 90, 69), M.Wood },
	Beam = { RGB(126, 83, 64), M.Wood },
	Bracket = { RGB(110, 71, 54), M.Wood },
	-- Plaster 재질은 회색끼가 강해서 따뜻한 크림이 차갑게 보인다. 색을 그대로 내는 재질로 둔다
	Wall = { RGB(219, 212, 193), M.SmoothPlastic },
	Lattice = { RGB(154, 106, 78), M.Wood },
	Paper = { RGB(228, 220, 198), M.SmoothPlastic },
	Roof = { RGB(85, 88, 79), M.Slate },
	RoofEdge = { RGB(71, 74, 67), M.Slate },
	Eave = { RGB(94, 64, 51), M.Wood },
	Trim = { RGB(78, 111, 99), M.SmoothPlastic },
	Ochre = { RGB(180, 136, 74), M.SmoothPlastic },
}

-- 충돌.
-- **조각이 여러 개 든 메시에 상자나 껍데기를 쓰면 문이 막힌다.** 하나의 상자가
-- 벽 전체를 덮어 버리기 때문이다. 구멍이 살아 있어야 하는 것은 정밀 분해로 잡는다
local PRECISE = {
	Wall = true, Lattice = true, Stairs = true, Column = true, Plinth = true,
	Beam = true, Bracket = true, Stylobate = true,
}
local HULL = { Roof = true, RoofEdge = true, Eave = true }
local NOCOLLIDE = { Trim = true, Ochre = true, Paper = true }

local X, Z, YAW = 225, 360, 180 -- 광장 북쪽. 광장을 바라본다

local model = workspace:FindFirstChild("Building_Hall")
assert(model, "Workspace 에 Building_Hall 이 없다. 먼저 FBX 를 가져와라")

--=== 색과 재질 ===--
local done, unknown = 0, {}
for _, p in ipairs(model:GetDescendants()) do
	if p:IsA("BasePart") then
		local key = p.Name:match("^Hall_(.+)$")
		local skin = key and SKIN[key]
		if skin then
			p.Color = skin[1]
			p.Material = skin[2]
			done = done + 1
		else
			unknown[#unknown + 1] = p.Name
		end
		p.Anchored = true
		p.CanCollide = not (key and NOCOLLIDE[key])
		p.CastShadow = true
		if p:IsA("MeshPart") then
			if key and PRECISE[key] then
				p.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
			elseif key and HULL[key] then
				p.CollisionFidelity = Enum.CollisionFidelity.Hull
			else
				p.CollisionFidelity = Enum.CollisionFidelity.Box
			end
			p.RenderFidelity = Enum.RenderFidelity.Precise
		end
	end
end

--=== 자리 ===--
local G = workspace.Surface.World["G_평원"]
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { G }

-- 기단이 앉을 자리의 땅을 아홉 점 재서 가장 높은 데에 맞춘다.
-- 가장 낮은 데에 맞추면 한쪽이 땅에 묻힌다
local lo, hi = 1e9, -1e9
for ix = -1, 1 do
	for iz = -1, 1 do
		local h = workspace:Raycast(
			Vector3.new(X + ix * 46, 4000, Z + iz * 33),
			Vector3.new(0, -8000, 0), rp
		)
		assert(h, string.format("(%d, %d) 아래에 평원 땅이 없다", X + ix * 46, Z + iz * 33))
		lo, hi = math.min(lo, h.Position.Y), math.max(hi, h.Position.Y)
	end
end

-- 모델을 그 자리로. 바운딩 박스 밑면이 땅 높이에 오게 내린다
model:PivotTo(CFrame.new(X, 0, Z) * CFrame.Angles(0, math.rad(YAW), 0))
local cf, size = model:GetBoundingBox()
local bottom = cf.Position.Y - size.Y / 2
model:PivotTo(model:GetPivot() + Vector3.new(0, hi - bottom, 0))

--=== 자기검사 ===--
assert(#unknown == 0, "이름을 못 알아본 파트: " .. table.concat(unknown, " "))
assert(done >= 10, "색을 입힌 파트가 " .. done .. "개뿐이다")

local cf2, size2 = model:GetBoundingBox()
local bot = cf2.Position.Y - size2.Y / 2
assert(math.abs(bot - hi) < 0.5, string.format("기단 밑이 땅에서 %.1f 떨어져 있다", bot - hi))

-- 색이 정말 여러 가지인지. 앞선 판이 단색 하나였던 것을 다시 겪지 않으려는 검사다
local seen = {}
local n = 0
for _, p in ipairs(model:GetDescendants()) do
	if p:IsA("BasePart") then
		local k = tostring(p.Color)
		if not seen[k] then
			seen[k] = true
			n = n + 1
		end
	end
end
assert(n >= 10, "색이 " .. n .. "가지뿐이다. 단색으로 뭉쳤다")

-- **문이 정말 뚫렸는지 광선으로 지나가 본다.**
-- 파트 경계 상자로는 알 수 없다. 메시의 경계 상자는 벽 전체를 덮기 때문이다.
-- 광선은 충돌 형상을 따르므로 플레이어가 겪는 것과 같은 것을 잰다
-- 문 높이는 건물 크기에 비례해 잡는다. 배율이 바뀌어도 따라간다
local doorY = bot + size2.Y * 0.22
local frontZ = cf2.Position.Z + size2.Z / 2
local rq = RaycastParams.new()
rq.FilterType = Enum.RaycastFilterType.Include
rq.FilterDescendantsInstances = { model }
-- 앞벽만 본다. 길게 쏘면 앞문을 통과해 뒷벽을 맞고 막혔다고 한다
local probe = 8 + size2.Z * 0.18
local blocked = workspace:Raycast(
	Vector3.new(cf2.Position.X, doorY, frontZ + 8),
	Vector3.new(0, 0, -probe), rq
)
if blocked then
	warn(string.format("[건물] 문이 %s 에 막혀 있다 (%.1f 앞)", blocked.Instance.Name,
		frontZ + 8 - blocked.Position.Z))
else
	print("[건물] 가운데 문으로 광선이 통과한다. 드나들 수 있다")
end

print(string.format("[건물] 파트 %d개 / 색 %d가지 / 크기 %.0f x %.0f x %.0f",
	done, n, size2.X, size2.Y, size2.Z))
print(string.format("[건물] 자리 (%d, %.1f, %d) 방향 %d도 / 땅 %.1f..%.1f", X, bot, Z, YAW, lo, hi))
print("[건물] 색 입히고 앉혔다")
