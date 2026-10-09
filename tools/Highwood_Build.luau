--!nocheck
--[[
	Highwood_Build.luau — 2026-10-09. 하이우드 1단계: 거대수 다섯·판·다리·나선 비탈(편집 모드, StudioJobs).
	상자는 tools/highwood_build.py 가 계산(배치 highwood_plan.py, 검사 0건) → Highwood_data.luau 를 --@@DATA@@ 자리에:
	  python tools/highwood_build.py && sed '/--@@DATA@@/r tools/Highwood_data.luau' tools/Highwood_Build.luau > tools/swamp/_hw_run.luau && bash tools/job.sh tools/swamp/_hw_run.luau
	Surface.R_하이우드 만 지우고 새로. 상자 = CFrame.new(가운데) * fromOrientation(rx, ry, rz)(파이썬 검사와 같은 순서).
	잎은 안 부딪힘·그림자 끔(마을이 너무 어두워지지 않게는 다음 단계에서 빛으로). 보고: /highwood
]]
local HS = game:GetService("HttpService")

--@@DATA@@

local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

local ok, err = pcall(function()
	local S = workspace.Surface
	local old = S:FindFirstChild("R_하이우드")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "R_하이우드"
	local folders = {}
	local function folderFor(group)
		local key = if group == "LeafA" or group == "LeafB" then "Leaves"
			elseif group == "Bark" or group == "Bark2" then "Trees"
			else "Walks"
		if not folders[key] then
			local f = Instance.new("Folder")
			f.Name = key
			f.Parent = root
			folders[key] = f
		end
		return folders[key]
	end
	local jitterN = 0
	for _, b in BOXES do
		local name, group = b[1], b[2]
		local skin = SKIN[group]
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = Vector3.new(b[6], b[7], b[8])
		jitterN += 1
		-- 큰 줄기·잎만 ±0.1 흔들기(깜박임). 걷는 판은 이음매가 벌어지지 않게 그대로
		local j = if group == "Bark" or group == "Bark2" or group == "LeafA" or group == "LeafB"
			then Vector3.new(if jitterN % 2 == 0 then 0.1 else -0.1, if jitterN % 4 < 2 then 0.1 else -0.1, if jitterN % 8 < 4 then 0.1 else -0.1)
			else Vector3.zero
		p.CFrame = CFrame.new(b[3], b[4], b[5]) * CFrame.fromOrientation(math.rad(b[9]), math.rad(b[10]), math.rad(b[11])) + j
		p.Color, p.Material = skin[1], skin[2]
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if group == "LeafA" or group == "LeafB" then
			p.CanCollide = false
			p.CanQuery = false
			p.CastShadow = false
		end
		if group == "Rope" then
			p.CanCollide = false
		end
		p.CanTouch = false
		p.Parent = folderFor(group)
	end
	root.Parent = S
	say("하이우드: 상자 %d", #BOXES)
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/highwood", table.concat(lines, "\n"))
