--!nocheck
--[[
	Islands_Ramps.luau — 손으로 찍은 자리에만 오르는 길을 놓는다.

	**앞선 방식은 폐기했다.** 섬 전체를 격자로 훑어 단차가 나오는 곳마다
	돌을 끼워 넣었더니 길이 아니라 자갈밭이 됐고, 1만 개가 깔렸다.
	일부는 아래층 땅을 파고들어 천장이 됐다.

	그래서 두 가지를 바꿨다.

	1. **자리는 사람이 정한다.** 아래 RAMPS 에 적힌 선분에만 길이 생긴다.
	   실측해 보니 숲에서 못 오르는 턱은 전부 거목 대지 둘레 700 안에 몰려 있었다.
	   섬을 훑을 이유가 없다.

	2. **디딤돌은 얇은 판이 아니라 기둥이다.** 디딤면에서 아래 지면까지 내려 붙인다.
	   얇게 놓으면 밑이 비어 천장이 된다. 기둥이면 그럴 수가 없다.

	사람이 만든 계단이 아니라 자연석이므로 나무를 쓰지 않는다.
	색과 재질은 출발점 지면에서 그대로 가져온다.

	되돌리기: workspace.Surface.Ramps:Destroy()
]]

-- 길 하나 = 아래에서 위로 가는 선분. 높이는 양 끝의 실제 지면을 재서 쓴다.
-- 꺾인 길은 선분을 이어 붙이면 된다.
local RAMPS = {
	-- 거목 언덕으로 오르는 남북 두 길. 대각선에는 작은 노두가 박혀 있어서
	-- 남북 축만 비어 있다. 한쪽만 두면 반대편에서 온 사람이 섬을 반 바퀴 돌아야 한다.
	{ name = "거목북", x1 = -4800, z1 = 150, x2 = -4790, z2 = 1430, w = 150 },
	{ name = "거목남", x1 = -4800, z1 = 3050, x2 = -4790, z2 = 1780, w = 150 },
}

local RISE = 11 -- 한 단의 최대 높이. 뛰지 않고 걸어서 오를 수 있어야 한다
local DEPTH_MIN = 14 -- 기둥 최소 깊이
local RAY_FROM = 900
local RAY_LEN = 1800

local S = workspace.Surface
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = S:FindFirstChild("Mountains") and { S.World, S.Mountains } or { S.World }

local function groundAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, RAY_FROM, z), Vector3.new(0, -RAY_LEN, 0), rp)
	return hit and hit.Position.Y or nil, hit and hit.Instance or nil
end

local old = S:FindFirstChild("Ramps")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Ramps"
root.Parent = S

local rng = Random.new(5150)
local total, report = 0, {}

for _, r in ipairs(RAMPS) do
	local y1, i1 = groundAt(r.x1, r.z1)
	local y2 = groundAt(r.x2, r.z2)
	assert(y1 and y2, r.name .. " 의 양 끝 중 하나가 허공이다. 좌표를 확인해라")

	local fold = Instance.new("Folder")
	fold.Name = "R_" .. r.name
	fold.Parent = root

	local lo, hi = math.min(y1, y2), math.max(y1, y2)
	local n = math.max(math.ceil((hi - lo) / RISE), 3)
	local made = 0

	-- 진행 방향의 직각 방향. 길 폭만큼 옆으로 벌린다
	local dx, dz = r.x2 - r.x1, r.z2 - r.z1
	local len = math.sqrt(dx * dx + dz * dz)
	local nx, nz = -dz / len, dx / len
	local lanes = math.max(math.floor(r.w / 70), 2)

	for i = 0, n do
		local t = i / n
		local cy = y1 + (y2 - y1) * t
		for j = 0, lanes - 1 do
			local off = (j - (lanes - 1) / 2) * (r.w / lanes)
			local px = r.x1 + dx * t + nx * off + rng:NextNumber(-8, 8)
			local pz = r.z1 + dz * t + nz * off + rng:NextNumber(-8, 8)

			-- 디딤면 밑이 어디까지 비어 있는지 재서 거기까지 기둥을 내린다.
			-- 이걸 안 하면 얇은 판이 공중에 남아 아래층의 천장이 된다
			local under = groundAt(px, pz)
			local top = cy + rng:NextNumber(-1.5, 1.5)
			local depth = math.max(top - (under or (top - 40)), DEPTH_MIN)

			local p = Instance.new("Part")
			p.Name = string.format("Rmp_%s_%d_%d", r.name, math.floor(px), math.floor(pz))
			p.Anchored = true
			p.Size = Vector3.new(r.w / lanes * rng:NextNumber(0.95, 1.25), depth, 90 * rng:NextNumber(0.85, 1.15))
			p.CFrame = CFrame.new(px, top - depth / 2, pz) * CFrame.Angles(0, rng:NextNumber(-0.35, 0.35), 0)
			p.Color = (i1 and i1.Color or Color3.fromRGB(140, 138, 130))
				:Lerp(Color3.fromRGB(0, 0, 0), rng:NextNumber(0, 0.12))
			p.Material = i1 and i1.Material or Enum.Material.Rock
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Parent = fold
			made += 1
			total += 1
		end
		task.wait()
	end

	report[#report + 1] = string.format("%s %d단 %d개 (%d->%d)", r.name, n, made, math.floor(y1), math.floor(y2))
end

assert(total > 0, "길을 하나도 안 놓았다")
print(string.format("[Ramps] %d개", total))
print("[Ramps] " .. table.concat(report, " / "))
