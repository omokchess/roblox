--!nocheck
--[[
	Plains_RampSteps.luau — 2026-10-04. 평원 오르막(매끈한 풀 쐐기 WedgePart)을 바위 턱 비탈로 바꾼다(편집 모드, StudioJobs).
	사용자(사막 계단 보고): "경사진 길들, 계단식으로 하든 해서 자연스럽게 풍경이랑 녹이자 … 계단도 형태를 그냥 지형처럼
	올라갈 수 있게 ㄱㄱ. 이건 평원도 마찬가지야"
	Surface.R_평원*/Ramps 의 WedgePart 마다(로컬 +Z 쪽이 높다): 낮은 끝 땅 → 높은 끝까지 턱(높이 ≤ 2, 깊이·폭·옆 위치 엇갈림, 풀 윗면 +
	바위 옆) + 양옆 무너진 비탈 턱 셋 + 돌덩이. 쐐기는 지우고 같은 폴더(Ramps)에 둔다. 쐐기의 FillLift(단 따라 올린 높이)는
	새 부품마다 옮겨 적어 Plains_Fill 을 다시 돌려도 맞게 내려놓고 다시 올린다.
	다시 지을 때: Plains_Build 가 쐐기를 새로 만들므로 Plains_Build 뒤(Reseat 등 다음)에 이것을 다시 돌린 뒤 Plains_Fill.
	보고: /plainsramps
]]
local HS = game:GetService("HttpService")
local RGB = Color3.fromRGB
local GRASS, ROCK, ROCK2 = RGB(117, 151, 83), RGB(132, 130, 124), RGB(118, 116, 111)

local function part(name, size, cf, color, mat, parent, lift)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if lift then
		p:SetAttribute("FillLift", lift)
	end
	p.Parent = parent
	return p
end

-- 바위 옆 + 풀 윗판(1.2). frame = 오르는 방향을 -Z(LookVector)로 둔 기준(높이는 월드 y)
local function ledge(name, frame, along0, along1, side0, side1, top, bottom, parent, lift, rock)
	local h = top - bottom
	local mid = frame * CFrame.new((side0 + side1) / 2, 0, -(along0 + along1) / 2)
	local p = mid.Position
	local rot = mid - p
	part(name, Vector3.new(side1 - side0, h - 1.2, along1 - along0), CFrame.new(p.X, bottom + (h - 1.2) / 2, p.Z) * rot, rock, Enum.Material.Slate, parent, lift)
	part(name .. "_풀", Vector3.new(side1 - side0, 1.2, along1 - along0), CFrame.new(p.X, top - 0.6, p.Z) * rot, GRASS, Enum.Material.Grass, parent, lift)
end

local RISE = { 1.4, 2.0, 1.1, 1.8, 1.5, 1.2, 1.9 }
local RUN = { 1.2, 0.8, 1.4, 0.9, 1.1, 1.3 }
local SHIFT = { 0, 0.8, -0.6, 0.4, -0.9, 0.5, -0.3 }
local TALUS = { { 0.45, 0.75, 4, 10 }, { 0.7, 0.45, 9, 7 }, { 0.9, 0.2, 14, 6 } }

local lines = {}
local ok, err = pcall(function()
	local converted = 0
	for _, f in workspace.Surface:GetChildren() do
		local ramps = f.Name:match("^R_평원") and f:FindFirstChild("Ramps")
		for _, w in ramps and ramps:GetChildren() or {} do
			if not w:IsA("WedgePart") then
				continue
			end
			local cf, size = w.CFrame, w.Size
			local lift = w:GetAttribute("FillLift")
			local up = (cf:VectorToWorldSpace(Vector3.new(0, 0, 1)) * Vector3.new(1, 0, 1)).Unit -- 높은 쪽(수평)
			local base = cf.Position.Y - size.Y / 2
			local lo, hi = base + 2, base + size.Y -- 쐐기는 낮은 땅 2 아래에서 시작했다
			local run, width = size.Z, size.X
			local lowEnd = cf.Position - up * (run / 2)
			-- 기준: 낮은 끝 가운데, -Z(LookVector) = 오르는 쪽
			local frame = CFrame.lookAt(Vector3.new(lowEnd.X, 0, lowEnd.Z), Vector3.new(lowEnd.X, 0, lowEnd.Z) + up)
			local steps, total = {}, 0
			while total < hi - lo - 0.01 do
				local r = math.min(RISE[(#steps % #RISE) + 1], hi - lo - total)
				total += r
				table.insert(steps, total)
			end
			local n = #steps
			local runs, sum = {}, 0
			for k = 1, n do
				runs[k] = RUN[(k % #RUN) + 1]
				sum += runs[k]
			end
			local acc = 0
			local tag = w.Name
			for k = 1, n do
				local depth = run * runs[k] / sum
				local s0 = acc
				acc += depth
				local jog = SHIFT[(k % #SHIFT) + 1] * math.min(7, width * 0.4)
				local w0, w1 = -width / 2 + jog - (k % 3) * 2.0, width / 2 + jog + ((k + 1) % 3) * 2.0
				ledge(string.format("%s_Ledge%d", tag, k), frame, s0, s0 + depth + 0.6, w0, w1, lo + steps[k], lo - 4, ramps, lift, if k % 2 == 0 then ROCK2 else ROCK)
				if k % 2 == 0 then
					local side = if (k // 2) % 2 == 0 then w0 - 2.2 else w1 + 2.2
					local at = frame * CFrame.new(side, 0, -(s0 + depth / 2))
					part(string.format("%s_Stone%d", tag, k), Vector3.new(3.6, 3, 3.2), CFrame.new(at.X, lo + steps[k] + 0.6, at.Z) * CFrame.Angles(0, math.rad(k * 23), 0), ROCK, Enum.Material.Slate, ramps, lift)
				end
			end
			for t, tl in TALUS do
				local len = run * tl[1]
				local top = lo + (hi - lo) * tl[2]
				for side = -1, 1, 2 do
					local edge = side * (width / 2 + tl[3] - (t - 1) * 1.5)
					local c0, c1 = math.min(edge, edge - side * tl[4]), math.max(edge, edge - side * tl[4])
					ledge(string.format("%s_Talus%d_%d", tag, t, side), frame, run - len, run, c0, c1, top, lo - 4, ramps, lift, if t % 2 == 0 then ROCK2 else ROCK)
				end
			end
			w:Destroy()
			converted += 1
		end
	end
	table.insert(lines, "바꾼 쐐기 " .. converted)
end)
HS:PostAsync("http://127.0.0.1:34999/plainsramps", tostring(ok) .. " " .. tostring(err) .. "\n" .. table.concat(lines, "\n"))
