-- 시간 예산 점검(2026-10-11): 광장 → 기능 건물 문 · 길드 · 동문 · 계류탑, PathfindingService 로 실제 걷는 길이를 잰다.
-- 걷기 16 스터드/초. 결과 → recv/pathtime.txt
local HS = game:GetService("HttpService")
local PFS = game:GetService("PathfindingService")
local town = workspace.Schneereich["마을"]
local CX, CZ = -4933.0, -3818.0
local rp = RaycastParams.new()
rp.RespectCanCollide = true

local function ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -600, 0), rp)
	return hit and hit.Position.Y or 60
end

local function find(name)
	for _, d in ipairs(town:GetDescendants()) do
		if d:IsA("Model") and d.Name == name then
			return d
		end
	end
end

-- 문 앞(로컬 -Z 로 앞면 깊이 + 3)
local TARGETS = {
	{ "대장간", "Gray_Smithy", 18 },
	{ "강화소", "Gray_Enhance", 16 },
	{ "은행", "Gray_Bank", 18 },
	{ "여관", "Gray_Inn", 18 },
	{ "물약상점", "Gray_Potion", 16 },
	{ "병원", "Gray_Hospital", 18 },
	{ "잡화점", "Gray_General", 16 },
	{ "마구간(여관 뜰)", "Gray_Yard_Inn", 9 },
	{ "노점(잡화점 뜰)", "Gray_Yard_General", 10 },
	{ "지하 경매장 정자(북동 바깥)", "Casino_Gate", 16 },
	{ "길드(기물군 본부)", "Figuren_HQ", 44 },
	{ "동문(필드) 안쪽", "City_Gate", -12 },
	{ "계류탑(비행선) 앞", "Mooring_Mast", -8 },
}

local start = Vector3.new(CX, ground(CX, CZ + 22) + 3, CZ + 22) -- 시계탑 남쪽 광장
local lines = {}
for _, t in ipairs(TARGETS) do
	local m = find(t[2])
	if not m then
		lines[#lines + 1] = t[1] .. ": 모델 없음"
		continue
	end
	local p = m:GetPivot():PointToWorldSpace(Vector3.new(0, 0, -t[3]))
	local goal = Vector3.new(p.X, ground(p.X, p.Z) + 3, p.Z)
	local path = PFS:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4 })
	local ok, err = pcall(function()
		path:ComputeAsync(start, goal)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		lines[#lines + 1] = string.format("%s: 길 못 찾음 (%s) 직선 %.0f", t[1], ok and tostring(path.Status) or tostring(err), (goal - start).Magnitude)
		continue
	end
	local wps = path:GetWaypoints()
	local len = 0
	for i = 2, #wps do
		len += (wps[i].Position - wps[i - 1].Position).Magnitude
	end
	lines[#lines + 1] = string.format("%s: 걷는 길 %.0f (직선 %.0f) → 걷기 %.1f 초 · 달리기 %.1f 초", t[1], len, (goal - start).Magnitude, len / 16, len / 24)
end
HS:PostAsync("http://127.0.0.1:34999/pathtime", table.concat(lines, "\n"))
