--!nocheck
--[[
	Islands_TrimTreesInRock.luau — 바위에 박힌 나무를 걷어낸다.

	봉우리는 지반을 깐 뒤에 쌓는다. 그래서 이미 서 있던 나무를 바위가 삼킨다.
	줄기만 반쯤 튀어나온 나무가 숲 곳곳에 생긴다.

	**올려서 바위 위에 다시 세우지 않는다.** 화강암 돔은 숲을 뚫고 나온 맨바위이고
	거기 나무가 서 있으면 돔이라는 게 읽히지 않는다. 그냥 지운다.

	판정은 두 가지다.
	  하나, 발밑을 찍었을 때 **제일 위에 있는 것이 바위면** 지운다.
	        바위 위에 얌전히 서 있는 나무는 묻힌 깊이가 0이라 깊이만 봐서는 안 잡힌다.
	  둘, 바위 표면이 밑동보다 한참 위면 바위 속에 들어간 것이다. 지운다.

	깊이는 **위에서 아래로** 쏴서 잰다. 밑동에서 위로 쏘면 안 된다.
	로블록스 광선은 시작점이 이미 블록 안이면 그 블록을 못 잡기 때문에,
	깊이 묻힌 나무일수록 검출이 안 되는 검사가 된다. 실제로 그래서 0그루가 나왔다.
	위에서 내려 찍은 바위 표면이 밑동보다 높으면 그 나무는 바위 속에 있다.
	한 그루를 반만 지우면 잎만 공중에 남으므로 반드시 통째로 지운다.

	Islands_Mountains.luau 뒤에 실행한다. 되돌리려면 Ctrl+Z.
]]

local RAY_FROM = 900
local RAY_LEN = 1600
local BURY = 24 -- 밑동이 바위 속으로 이만큼 이상 들어가 있으면 묻힌 것으로 본다

local mtn = workspace.Surface:FindFirstChild("Mountains")
assert(mtn, "Mountains 가 없다. Islands_Mountains.luau 를 먼저 돌려라")

-- 바위만 보는 광선
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { mtn }

-- 바위와 지반을 같이 보는 광선. 둘 중 무엇이 위에 있는지 가린다
local rq = RaycastParams.new()
rq.FilterType = Enum.RaycastFilterType.Include
rq.FilterDescendantsInstances = { mtn, workspace.Surface.World }

local R = workspace.Surface["R_숲"]
local killed, kparts, kept = 0, 0, 0

for _, fold in ipairs(R:GetChildren()) do
	local grp = {}
	for _, p in ipairs(fold:GetChildren()) do
		local id = p:IsA("BasePart") and p.Name:match("^For_([^_]+)_")
		if id then
			local g = grp[id]
			if not g then
				g = { n = 0, sx = 0, sz = 0, mny = 1e9, list = {} }
				grp[id] = g
			end
			g.n += 1
			g.sx += p.Position.X
			g.sz += p.Position.Z
			g.mny = math.min(g.mny, p.Position.Y)
			g.list[#g.list + 1] = p
		end
	end

	for id, g in pairs(grp) do
		-- 거목은 랜드마크다. 봉우리와 겹쳐도 남긴다
		if id ~= "Elder" then
			local cx, cz = g.sx / g.n, g.sz / g.n
			local from = Vector3.new(cx, RAY_FROM, cz)
			local dir = Vector3.new(0, -RAY_LEN, 0)
			-- 발밑에서 제일 위에 있는 것이 바위인가
			local surf = workspace:Raycast(from, dir, rq)
			local onRock = surf and surf.Instance:IsDescendantOf(mtn)
			-- 바위 표면이 밑동보다 한참 위인가
			local down = workspace:Raycast(from, dir, rp)
			local buried = down and (down.Position.Y - g.mny) > BURY
			if onRock or buried then
				for _, p in ipairs(g.list) do
					p:Destroy()
					kparts += 1
				end
				killed += 1
			else
				kept += 1
			end
		end
	end
	task.wait()
end

print(string.format("[TrimTrees] 묻힌 %d그루 %d파트 제거 / %d그루 유지", killed, kparts, kept))
