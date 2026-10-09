--!nocheck
--[[
	Forest_OldKit.luau — 2026-10-09. 옛 숲 나무(사용자: "옛날에 쓰던 나무 레퍼런스로 거목들 엄청 만들어서 숲처럼")를 틀로 뽑는다.
	옛 나무 = ServerStorage.TerrainBackup.Forest_R.Flora 의 낱 파트, 이름 "For_<종류><번호>_<조각>" 이 한 그루.
	골라 둔 그루(PICK, 손으로 — 돌산 밖 평지·폭 80 아래·높이 큰 것, 종류 고루)를 ServerStorage.ForestOldKit.Old_<번호> 모델로 복제:
	  원점 = 줄기 밑(줄기 T1 조각의 x·z, 그 자리 옛 땅 판(TerrainBackup.Forest_G) 윗면 높이). 원본은 그대로 둔다.
	보고: /forestoldkit
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")

-- 높이 순 조사(2026-10-09 oldtrees)에서 고른 것 + 종류 고루(S·X 는 아래에서 자동으로 둘씩)
local PICK = { "For_P422", "For_P171", "For_P331", "For_P249", "For_P283", "For_P525", "For_P228", "For_P453", "For_P251",
	"For_P440", "For_P2", "For_W56", "For_W166", "For_W213" }

local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

local ok, err = pcall(function()
	local B = SS.TerrainBackup
	local flora = B.Forest_R.Flora
	local groups = {}
	for _, p in flora:GetChildren() do
		local key = p:IsA("BasePart") and p.Name:match("^(For_%a+%d+)_")
		if key then
			groups[key] = groups[key] or {}
			table.insert(groups[key], p)
		end
	end
	-- S·X 종류: 폭 80 아래·돌산(-1610,523 반경 420) 밖에서 파트 많은 것 둘씩
	for _, kind in { "S", "X" } do
		local cands = {}
		for key, parts in groups do
			if key:match("^For_" .. kind .. "%d+$") then
				local lo, hi = Vector3.new(1e9, 0, 1e9), Vector3.new(-1e9, 0, -1e9)
				for _, p in parts do
					lo, hi = lo:Min(p.Position), hi:Max(p.Position)
				end
				local w = math.max(hi.X - lo.X, hi.Z - lo.Z)
				local c = (lo + hi) / 2
				if w < 80 and (Vector2.new(c.X, c.Z) - Vector2.new(-1610, 523)).Magnitude > 420 then
					table.insert(cands, { key, #parts })
				end
			end
		end
		table.sort(cands, function(a, b)
			return a[2] > b[2]
		end)
		for i = 1, math.min(2, #cands) do
			table.insert(PICK, cands[i][1])
		end
	end
	-- 옛 땅 판 윗면
	local tiles = {}
	for _, d in B.Forest_G:GetDescendants() do
		if d:IsA("BasePart") then
			tiles[#tiles + 1] = d
		end
	end
	local function groundAt(x, z)
		local best = nil
		for _, t in tiles do
			local lp = t.CFrame:PointToObjectSpace(Vector3.new(x, t.Position.Y, z))
			if math.abs(lp.X) <= t.Size.X / 2 and math.abs(lp.Z) <= t.Size.Z / 2 then
				local top = t.Position.Y + t.Size.Y / 2
				if not best or top > best then
					best = top
				end
			end
		end
		return best
	end
	local root = SS:FindFirstChild("ForestOldKit")
	if root then
		root:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "ForestOldKit"
	root.Parent = SS
	for _, key in PICK do
		local parts = groups[key]
		if not parts then
			say("없음 %s", key)
			continue
		end
		local trunk
		for _, p in parts do
			if p.Name == key .. "_T1" then
				trunk = p
			end
		end
		if not trunk then
			for _, p in parts do
				if p.Material == Enum.Material.Wood and (not trunk or p.Position.Y < trunk.Position.Y) then
					trunk = p
				end
			end
		end
		local gx, gz = trunk.Position.X, trunk.Position.Z
		local gy = groundAt(gx, gz) or 4.7
		local origin = CFrame.new(gx, gy, gz)
		local m = Instance.new("Model")
		m.Name = "Old_" .. key:sub(5)
		local hiY = -1e9
		for _, p in parts do
			local c = p:Clone()
			c.CFrame = origin:ToObjectSpace(p.CFrame)
			c.Anchored = true
			c.Parent = m
			hiY = math.max(hiY, c.Position.Y + c.Size.Y / 2)
		end
		m.Parent = root
		local cf, size = m:GetBoundingBox()
		say("%s: 파트 %d, 높이 %.0f, 폭 %.0f×%.0f, 땅 %.1f, 가운데 어긋남 %.1f,%.1f", m.Name, #parts, hiY, size.X, size.Z, gy, cf.X, cf.Z)
	end
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/forestoldkit", table.concat(lines, "\n"))
