--!nocheck
--[[
	Plains_WallSettle.luau — 2026-10-03. 평원 평탄화 뒤 절화 담 토막 높이를 다시 맞춘다(편집 모드, StudioJobs).

	Plains_Reseat 는 물건마다 제 밑 옛 타일 높이로 옮겨서, 한 줄로 이어진 담 토막끼리 0.5~3.6 씩 엇갈렸다
	(사용자 2026-10-03 "엇갈려있는 벽 수정"). 새 땅은 평평하니 담·울타리·담 대문·궁 바깥 문은 토막마다
	밑면(Foundation·LevelFoundation 빼고 가장 낮은 켜)을 바로 밑 땅에 붙인다. 받침(LevelFoundation)은 모델 안이라 땅속으로 같이 내려간다.
	행각(정전 둘레)은 Plains_CourtSettle 몫이다. Plains_Reseat 를 다시 돌리면 이것도 다시 돌릴 것. 보고: /wallsettle
]]
local HS = game:GetService("HttpService")
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

-- 밑면을 땅에 붙일 틀(이름 앞부분)과 그 폴더. 궁 정전 안 문(Gate_Hall, 정전 Gate_Main)은 행각 줄이라 뺀다
local function wanted(m: Model): boolean
	local n = m.Name
	if n:match("^Wall_%a+") or n:match("^Fence_%a+") or n:match("^Gate_Palace") then
		return true
	end
	return n:match("^Gate_Main") ~= nil and m.Parent.Name ~= "정전"
end

local ok, err = pcall(function()
	local terrain = {}
	for _, region in { "R_평원북", "R_평원동", "R_평원중" } do
		local f = workspace.Surface:FindFirstChild(region)
		for _, sub in { "Land", "Cliffs", "Masses", "Ramps", "Sand" } do
			local x = f and f:FindFirstChild(sub)
			if x then
				table.insert(terrain, x)
			end
		end
	end
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = terrain

	local moved, maxd = 0, 0
	for _, m in workspace.Jeolhwa:GetDescendants() do
		if m:IsA("Model") and not m.Parent:IsA("Model") and wanted(m) then
			local lo = math.huge
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") and p.Name ~= "Foundation" and p.Name ~= "LevelFoundation" then
					local cf, s = p.CFrame, p.Size
					local hy = math.abs(cf.RightVector.Y) * s.X / 2 + math.abs(cf.UpVector.Y) * s.Y / 2 + math.abs(cf.LookVector.Y) * s.Z / 2
					lo = math.min(lo, cf.Y - hy)
				end
			end
			local pv = m:GetPivot()
			local r = workspace:Raycast(Vector3.new(pv.X, 300, pv.Z), Vector3.new(0, -500, 0), ray)
			if r and lo < math.huge then
				local dy = r.Position.Y - lo
				if math.abs(dy) > 0.01 then
					m:PivotTo(pv + Vector3.new(0, dy, 0))
					moved += 1
					maxd = math.max(maxd, math.abs(dy))
				end
			end
		end
	end
	say("담·울타리·문 %d 토막 옮김(가장 크게 %.2f)", moved, maxd)
end)
HS:PostAsync("http://127.0.0.1:34999/wallsettle", tostring(ok) .. " " .. tostring(err) .. "\n" .. table.concat(lines, "\n"))
