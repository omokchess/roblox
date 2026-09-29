--!nocheck
--[[
	Jeolhwa_Face.luau — 절화를 탑의 성역 쪽으로 돌려 앉힌다.

	실측 결과 절화의 주축은 x=0 외문 → x=420 내문 → x=650 정전 순으로
	**동쪽으로** 이어진다. 즉 지금 절화는 서쪽을 보고 있다.
	부재는 전부 rotY = -90 이다.

	탑의 성역은 (1200, -4400) 으로 평원의 북쪽이다.
	외문을 축으로 **-90도** 돌리면 바라보는 방향이 -X 에서 -Z 로 바뀐다.
	정문이 북쪽을 보고 정전이 남쪽으로 물러난다. 궁의 진입 순서가 그대로 유지된다.

	돌린 뒤 외문이 (1000, 1200) 에 오도록 옮긴다. 이 자리는
	  - 도성 전체가 평원 섬 육지 안에 들어오고
	  - 북쪽 진입로가 성역을 정면으로 바라보며
	  - 남동쪽에서 시작하는 성벽 안에 넉넉히 들어간다

	**땅에 묻힌 옛 지반 부재는 지운다.** 섬을 다시 깔기 전에 쓰던
	Pln_Bedrock / Pln_Rock / Pln_Soil / Pln_Turf 는 지금 지반 아래에 깔려
	보이지도 않으면서 파트만 차지한다.

	**한 번만 실행한다.** 두 번 돌리면 180도가 된다.
	되돌리려면 Ctrl+Z.
]]

local PIVOT = Vector2.new(0, 1600) -- 외문. 회전축이자 옮길 기준점
local TARGET = Vector2.new(1000, 1200) -- 외문이 갈 자리
local TURN = -90 -- 도. -X 를 보던 것이 -Z 를 보게 된다

local DEAD = { Pln_Bedrock = true, Pln_Rock = true, Pln_Soil = true, Pln_Turf = true }

local R = workspace.Surface["R_평원"]

--=== 먼저 묻힌 옛 지반을 걷어낸다 ===--
local killed = 0
for _, f in ipairs(R:GetChildren()) do
	for _, p in ipairs(f:GetChildren()) do
		if p:IsA("BasePart") then
			local kind = p.Name:match("^([A-Za-z]+_[A-Za-z]+)") or ""
			if DEAD[kind] then
				p:Destroy()
				killed += 1
			end
		end
	end
end

--=== 회전 ===--
local rot = CFrame.Angles(0, math.rad(TURN), 0)
local pv = Vector3.new(PIVOT.X, 0, PIVOT.Y)
local shift = Vector3.new(TARGET.X - PIVOT.X, 0, TARGET.Y - PIVOT.Y)

local moved = 0
local mnx, mxx, mnz, mxz = 1e9, -1e9, 1e9, -1e9
for _, f in ipairs(R:GetChildren()) do
	for _, p in ipairs(f:GetChildren()) do
		if p:IsA("BasePart") then
			-- 축을 원점으로 옮겨 돌린 뒤 제자리로. 회전과 위치를 한 번에 처리한다
			local rel = p.CFrame - pv
			p.CFrame = (rot * rel) + pv + shift
			moved += 1
			mnx, mxx = math.min(mnx, p.Position.X), math.max(mxx, p.Position.X)
			mnz, mxz = math.min(mnz, p.Position.Z), math.max(mxz, p.Position.Z)
		end
	end
	task.wait()
end

--=== 자기검사 ===--
assert(moved > 1000, "옮긴 부재가 " .. moved .. "개뿐이다")

-- 돌아간 뒤에도 육지 위에 있어야 한다. 네 귀퉁이를 찍어 본다
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Surface.World["G_평원"] }
local off = 0
for _, c in ipairs({
	{ mnx, mnz },
	{ mxx, mnz },
	{ mnx, mxz },
	{ mxx, mxz },
	{ (mnx + mxx) / 2, (mnz + mxz) / 2 },
}) do
	if not workspace:Raycast(Vector3.new(c[1], 900, c[2]), Vector3.new(0, -1600, 0), rp) then
		off += 1
	end
end

print(
	string.format(
		"[JeolhwaFace] %d부재 회전 %d도 / 묻힌 옛 지반 %d개 제거 / 새 범위 x %d..%d (%d) z %d..%d (%d) / 바다로 나간 귀퉁이 %d",
		moved,
		TURN,
		killed,
		mnx,
		mxx,
		mxx - mnx,
		mnz,
		mxz,
		mxz - mnz,
		off
	)
)
print(string.format("[JeolhwaFace] 외문 %d,%d -> 정전은 여기서 남쪽으로 650", TARGET.X, TARGET.Y))
