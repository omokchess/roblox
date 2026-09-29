--!nocheck
--[[
	Islands_LiftForest.luau — 숲의 나무와 구조물을 새 지반 높이에 맞춘다.

	지반을 다시 깔면 지점마다 높이가 달라져서 나무가 묻히거나 뜬다.

	**왜 "제일 낮은 파트를 지면에 맞춘다"로 하면 안 되나**
	거목의 잎은 Flora 에 For_Elder_* 로 따로 있고 그 그룹에는 줄기가 없다.
	그러니 그 규칙을 쓰면 공중에 있어야 할 잎 90장이 통째로 땅바닥으로 떨어진다.
	실제로 그렇게 됐었다.

	그래서 **발밑이 아니라 지면이 얼마나 변했는지**로 옮긴다.
	파트마다 마지막으로 맞춘 지면 높이를 GY 특성에 적어 둔다.
	  - GY 가 없으면: 이미 제자리에 있는 것으로 보고 **옮기지 않고 값만 적는다**
	  - GY 가 있으면: (새 지면 - GY) 만큼 옮기고 값을 새로 적는다
	잎이든 뿌리든 같은 양만큼 움직이므로 나무가 분해되지 않는다. 몇 번 돌려도 같다.

	이름이 For_<번호>_ 형식인 파트만 건드린다. 반딧불이 방출기는 그래서 안 움직인다.
	광선이 아무것도 못 맞히면 바다로 나간 그루다. 지운다.
]]

local SINK = 2 -- 지면보다 이만큼 위를 기준으로 삼는다
local RAY_FROM = 900 -- 이 높이에서 아래로 쏜다. 어떤 봉우리보다 높다
local RAY_LEN = 1400

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Surface.World }

local R = workspace.Surface["R_숲"]
local seen, moved, stamped, killed, kparts, maxUp, maxDn = 0, 0, 0, 0, 0, 0, 0

for _, fold in ipairs(R:GetChildren()) do
	local grp = {}
	for _, p in ipairs(fold:GetChildren()) do
		local id = p:IsA("BasePart") and p.Name:match("^For_([^_]+)_")
		-- 거목은 바위 대지 위에 손으로 앉힌다. 지반을 따라 내려오면 안 된다
		if id and id ~= "Elder" then
			local g = grp[id]
			if not g then
				g = { n = 0, sx = 0, sz = 0, list = {} }
				grp[id] = g
			end
			g.n += 1
			g.sx += p.Position.X
			g.sz += p.Position.Z
			g.gy = g.gy or p:GetAttribute("GY")
			g.list[#g.list + 1] = p
		end
	end

	for _, g in pairs(grp) do
		seen += 1
		local cx, cz = g.sx / g.n, g.sz / g.n
		local hit = workspace:Raycast(Vector3.new(cx, RAY_FROM, cz), Vector3.new(0, -RAY_LEN, 0), params)

		if not hit then
			for _, p in ipairs(g.list) do
				p:Destroy()
				kparts += 1
			end
			killed += 1
		else
			local ground = hit.Position.Y + SINK
			if g.gy then
				local d = ground - g.gy
				if math.abs(d) > 0.5 then
					local v = Vector3.new(0, d, 0)
					for _, p in ipairs(g.list) do
						p.CFrame = p.CFrame + v
					end
					moved += 1
					maxUp = math.max(maxUp, d)
					maxDn = math.min(maxDn, d)
				end
			else
				stamped += 1
			end
			for _, p in ipairs(g.list) do
				p:SetAttribute("GY", ground)
			end
		end
	end
	task.wait()
end

assert(seen > 0, "For_<번호>_ 이름을 가진 그루를 하나도 못 찾았다. 이름 규칙을 확인해라")
print(
	string.format(
		"[LiftForest] %d그루 중 %d그루 이동 (위 %d / 아래 %d), %d그루 기준만 기록, %d그루 %d파트 제거",
		seen,
		moved,
		maxUp,
		maxDn,
		stamped,
		killed,
		kparts
	)
)
