--!nocheck
--[[
	Jeolhwa_Nudge.luau — 절화를 남쪽으로 밀 수 있는 만큼 민다.

	평원 섬은 남쪽 끝에서 폭이 좁아진다. z=2800 줄은 육지가 x -1200..2000 뿐인데
	절화는 폭이 2,564 다. 그냥 밀면 동쪽 절반이 바다로 나간다.

	그래서 **얼마나 밀 수 있는지 눈대중으로 정하지 않는다.**
	후보 이동량마다 모든 부재 자리를 광선으로 찍어 육지를 벗어나는 개수를 세고,
	하나도 안 벗어나는 가장 큰 값을 골라 그만큼만 민다.

	ALLOW 를 0 보다 크게 두면 그만큼은 바다로 나가도 눈감는다.
	가장자리 나무 몇 그루 때문에 도성 전체가 못 움직이는 것을 막으려는 것이다.
	그 경우 나간 부재는 목록으로 찍어 준다.

	되돌리려면 Ctrl+Z.
]]

local STEP = 50 -- 후보 간격
local MAX = 900 -- 여기까지 시험한다
local ALLOW = 0 -- 바다로 나가도 눈감을 부재 수

local R = workspace.Surface["R_평원"]
local G = workspace.Surface.World["G_평원"]

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { G }

-- 부재 자리를 한 번만 모아 둔다. 후보마다 다시 훑으면 느리다
local pts, parts = {}, {}
for _, f in ipairs(R:GetChildren()) do
	for _, p in ipairs(f:GetChildren()) do
		if p:IsA("BasePart") then
			parts[#parts + 1] = p
			pts[#pts + 1] = Vector2.new(p.Position.X, p.Position.Z)
		end
	end
end
assert(#parts > 500, "절화 부재가 " .. #parts .. "개뿐이다")

local function offCount(dz, stopAt)
	local off = 0
	for i = 1, #pts do
		local v = pts[i]
		if not workspace:Raycast(Vector3.new(v.X, 900, v.Y + dz), Vector3.new(0, -1600, 0), rp) then
			off += 1
			if stopAt and off > stopAt then
				return off
			end
		end
	end
	return off
end

local base = offCount(0)
print(string.format("[Nudge] 부재 %d개 / 지금 바다 위에 있는 것 %d개", #parts, base))

local best, bestOff = 0, base
for dz = STEP, MAX, STEP do
	local off = offCount(dz, base + ALLOW)
	print(string.format("  +%d -> 바다 %d", dz, off))
	if off <= base + ALLOW then
		best, bestOff = dz, off
	else
		break -- 한 번 넘어가면 더 밀어도 나아지지 않는다
	end
	task.wait()
end

assert(best > 0, "남쪽으로 단 " .. STEP .. " 도 못 민다. 이미 끝까지 내려와 있다")

local v = Vector3.new(0, 0, best)
for _, p in ipairs(parts) do
	p.CFrame = p.CFrame + v
end

local mnx, mxx, mnz, mxz = 1e9, -1e9, 1e9, -1e9
for _, p in ipairs(parts) do
	mnx, mxx = math.min(mnx, p.Position.X), math.max(mxx, p.Position.X)
	mnz, mxz = math.min(mnz, p.Position.Z), math.max(mxz, p.Position.Z)
end

print(
	string.format(
		"[Nudge] 남쪽으로 %d 이동 (바다 %d개) / 새 범위 x %d..%d (%d) z %d..%d (%d)",
		best,
		bestOff,
		mnx,
		mxx,
		mxx - mnx,
		mnz,
		mxz,
		mxz - mnz
	)
)
print(string.format("[Nudge] 외문 (1000, %d)", 1200 + best))
