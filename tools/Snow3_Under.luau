--!nocheck
--[[
	Snow3_Under.luau — 2026-10-09. 설원 지하 굴(편집 모드, StudioJobs). 자료 tools/snow3_under.py → Snow3_Under_data.luau:
	  python tools/snow3_under.py && sed '/--@@DATA@@/r tools/Snow3_Under_data.luau' tools/Snow3_Under.luau > tools/swamp/_under_run.luau && bash tools/job.sh tools/swamp/_under_run.luau
	먼저 Snow3_Build(땅 구멍 HOLES 가 있는 땅)를 돌려 둘 것. Surface.R_설원3_지하 만 지우고 새로.
	  - 구멍 기둥 자리 지형(물 -26~-3.5, 모래 -28)을 공기로 비운다(구멍 안에 바닷물이 보이지 않게)
	  - Floor 바닥 · Ceil 천장 · Wall 벽 · Step 블록 계단 · ShaftWall 구멍 둘레 · Ledge 구멍 디딤
	  - Secret 비밀벽(벽과 같은 색, 속성 Secret) · Breakable 금이 간 벽(조금 다른 색 + 양쪽 면 금, 속성 Breakable)
	  - 불빛: 얼음 결정(네온) + PointLight
	보고: /snow3under
]]
local HS = game:GetService("HttpService")
local RGB = Color3.fromRGB
local M = Enum.Material

--@@DATA@@

local SKIN = {
	Floor = { RGB(78, 84, 92), M.Slate },
	Ceil = { RGB(58, 62, 70), M.Slate },
	Wall = { RGB(70, 75, 84), M.Slate },
	Step = { RGB(88, 95, 104), M.Slate },
	ShaftWall = { RGB(70, 75, 84), M.Slate },
	Ledge = { RGB(100, 108, 110), M.Slate },
	Secret = { RGB(70, 75, 84), M.Slate },
	Breakable = { RGB(96, 92, 88), M.Slate },
}
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

local ok, err = pcall(function()
	local S = workspace.Surface
	local old = S:FindFirstChild("R_설원3_지하")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "R_설원3_지하"
	local folders = {}
	local function folder(kind)
		if not folders[kind] then
			local f = Instance.new("Folder")
			f.Name = kind
			f.Parent = root
			folders[kind] = f
		end
		return folders[kind]
	end
	-- 구멍 기둥 지형 비우기
	for _, s in SHAFTS do
		local x0, x1, z0, z1 = s[2], s[3], s[4], s[5]
		local y0, y1 = -44, s[6] + 10
		workspace.Terrain:FillBlock(CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Vector3.new(x1 - x0 + 8, y1 - y0, z1 - z0 + 8), M.Air)
	end
	local n = 0
	for i, p in PARTS do
		local kind, x0, x1, z0, z1, y0, y1, name = p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8]
		local skin = SKIN[kind]
		local part = Instance.new("Part")
		part.Name = if name ~= "" then name else kind .. i
		part.Anchored = true
		part.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
		-- 같은 높이 겹침 깜박임 방지: 계단·디딤만 번호마다 0~0.06 낮춤
		local dy = if kind == "Step" or kind == "Ledge" then -(i % 4) * 0.02 else 0
		part.CFrame = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2 + dy, (z0 + z1) / 2)
		part.Color, part.Material = skin[1], skin[2]
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if kind == "Secret" then
			part:SetAttribute("Secret", true) -- 히든 보스 방 문(열리는 장치는 다음 단계)
		elseif kind == "Breakable" then
			part:SetAttribute("Breakable", true) -- 케이브 쪽 금이 간 벽(부수는 장치는 다음 단계)
			-- 넓은 두 면에 금(검은 얇은 판 몇 줄) — 넓은 면 방향을 골라 붙인다
			local thinX = (x1 - x0) < (z1 - z0)
			for k, c in { { 0.2, 0.15, 0.55, 18 }, { -0.1, 0.45, 0.4, -30 }, { 0.3, 0.7, 0.35, 12 }, { -0.25, 0.3, 0.3, 50 } } do
				for _, sgn in { -1, 1 } do
					local crack = Instance.new("Part")
					crack.Name = "금"
					crack.Anchored = true
					crack.CanCollide = false
					crack.Color, crack.Material = RGB(28, 26, 26), M.Slate
					local h = (y1 - y0)
					local yy = y0 + h * c[2] + 30
					local along = c[1] * (if thinX then (z1 - z0) else (x1 - x0))
					if thinX then
						crack.Size = Vector3.new(0.3, 1.2, (z1 - z0) * c[3])
						crack.CFrame = CFrame.new(if sgn < 0 then x0 - 0.1 else x1 + 0.1, yy, (z0 + z1) / 2 + along) * CFrame.Angles(math.rad(c[4]), 0, 0)
					else
						crack.Size = Vector3.new((x1 - x0) * c[3], 1.2, 0.3)
						crack.CFrame = CFrame.new((x0 + x1) / 2 + along, yy, if sgn < 0 then z0 - 0.1 else z1 + 0.1) * CFrame.Angles(0, 0, math.rad(c[4]))
					end
					crack.Parent = part
				end
			end
		end
		part.Parent = folder(kind)
		n += 1
	end
	for i, l in LIGHTS do
		local c = Instance.new("Part")
		c.Name = "얼음등" .. i
		c.Anchored = true
		c.CanCollide = false
		c.Size = Vector3.new(3, 7, 3)
		c.CFrame = CFrame.new(l[1], l[2] - 6.5, l[3]) * CFrame.Angles(0, math.rad(i * 37), math.rad(8))
		c.Color, c.Material = RGB(170, 215, 255), M.Neon
		local light = Instance.new("PointLight")
		light.Range = 60
		light.Brightness = 1.6
		light.Color = RGB(170, 210, 255)
		light.Parent = c
		c.Parent = folder("Lights")
	end
	root.Parent = S
	say("지하: 상자 %d · 구멍 %d · 불빛 %d", n, #SHAFTS, #LIGHTS)
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/snow3under", table.concat(lines, "\n"))
