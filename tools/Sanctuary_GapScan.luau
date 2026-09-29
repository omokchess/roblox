--!nocheck
--[[
	Sanctuary_GapScan.luau — 2026-09-27. 탑의 성역 찐빠 찾기 → recv/sancgap.txt

	1. 뜬 조각: 유적(Ruins_)·채움(Fill_) 파트 밑면을 5x5 로 훑어 어느 점도 아래 면과 0.3 안에 닿지 않으면 뜬 것. 일부러 띄운 떠 있는 바위(Floater)와 탑(Struct_)은 뺀다.
	2. 땅 구멍: 섬 안(모래 테두리 안)을 4 격자로 쏴서 아무것도 안 맞거나, 이웃보다 3 넘게 푹 꺼진 곳.
	3. 땅 조각 사이 틈: 이웃한 Gs 조각 높이 차가 1.5 넘는 턱 (지붕처럼 보이는 계단)
	결과는 종류별 목록과 좌표. _G.SancGaps 에 뜬 파트 목록을 남긴다.
]]
local S = workspace.Surface
local ruins, fill = S:FindFirstChild("Ruins_탑의성역"), S:FindFirstChild("Fill_탑의성역")
local G = S.World["G_탑의성역"]
local out = {}

local rpAll = RaycastParams.new()
rpAll.FilterType = Enum.RaycastFilterType.Include
rpAll.FilterDescendantsInstances = { G, ruins, fill }

-- 1. 뜬 조각
local floating = {}
local byKind = {}
for _, root in ipairs({ ruins, fill }) do
	for _, p in ipairs(root:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.9 and not p:FindFirstAncestor("Floater") then
			local cf, s = p.CFrame, p.Size / 2
			-- 가장 낮은 면의 네 귀. 파트가 기울어져 있어도 월드 아래쪽 면을 고른다
			local axes = { cf.RightVector * s.X, cf.UpVector * s.Y, cf.LookVector * s.Z }
			local downAxis, best = nil, 1e9
			for i, a in ipairs(axes) do
				for _, sg in ipairs({ -1, 1 }) do
					local y = (a * sg).Y
					if y < best then
						best, downAxis = y, { i, sg }
					end
				end
			end
			local n = axes[downAxis[1]] * downAxis[2]
			local o = {}
			for i, a in ipairs(axes) do
				if i ~= downAxis[1] then
					o[#o + 1] = a
				end
			end
			local c = cf.Position + n
			-- 밑면을 5x5 로 훑는다. 한 점이라도 아래 면과 0.3 안이면 받쳐진 것(인방은 기둥 머리에, 지붕은 기둥에 얹힌다).
			-- 광선은 그 점 50 위에서 쏜다. 땅에 비스듬히 박힌 덩이는 밑면이 땅 속이라 아래서 쏘면 아무것도 안 맞는다
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			rp.FilterDescendantsInstances = { p, S:FindFirstChild("Struct_탑의성역") }
			local supported, maxGap, nHit = false, 0, 0
			for i = -2, 2 do
				for j = -2, 2 do
					local q = c + o[1] * (i / 2.2) + o[2] * (j / 2.2)
					local h = workspace:Raycast(q + Vector3.new(0, 50, 0), Vector3.new(0, -120, 0), rp)
					if h then
						nHit += 1
						local gap = q.Y - h.Position.Y
						if gap < 0.3 then
							supported = true
						end
						maxGap = math.max(maxGap, gap)
					end
				end
			end
			local nFloat = (not supported and nHit > 0 and maxGap > 0.4) and 4 or 0
			if nFloat >= 3 then
				floating[#floating + 1] = { p = p, gap = maxGap }
				local k = p.Parent.Name .. ":" .. p.Name:gsub("[%d_%-]+$", "")
				byKind[k] = (byKind[k] or 0) + 1
			end
		end
	end
end
_G.SancGaps = floating
out[#out + 1] = string.format("== 뜬 조각 %d", #floating)
local keys = {}
for k in pairs(byKind) do
	keys[#keys + 1] = k
end
table.sort(keys, function(a, b)
	return byKind[a] > byKind[b]
end)
for _, k in ipairs(keys) do
	out[#out + 1] = string.format("  %4d %s", byKind[k], k)
end
table.sort(floating, function(a, b)
	return a.gap > b.gap
end)
for i = 1, math.min(40, #floating) do
	local f = floating[i]
	out[#out + 1] = string.format("  틈 %.1f %s @ %.0f %.0f %.0f", f.gap, f.p:GetFullName():gsub("^Workspace%.Surface%.", ""), f.p.Position.X,
		f.p.Position.Y, f.p.Position.Z)
end

-- 2. 땅 구멍
local rpG = RaycastParams.new()
rpG.FilterType = Enum.RaycastFilterType.Include
rpG.FilterDescendantsInstances = { G }
local X0, Z0, X1, Z1, ST = -380, -2240, 1180, -690, 4
local H = {}
for x = X0, X1, ST do
	H[x] = {}
	for z = Z0, Z1, ST do
		local h = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -300, 0), rpG)
		H[x][z] = h and h.Position.Y or false
	end
	if (x - X0) % 160 == 0 then
		task.wait()
	end
end
local holes = {}
for x = X0 + ST, X1 - ST, ST do
	for z = Z0 + ST, Z1 - ST, ST do
		local v = H[x][z]
		local nb = { H[x - ST][z], H[x + ST][z], H[x][z - ST], H[x][z + ST] }
		local ok, sum = 0, 0
		for _, w in ipairs(nb) do
			if w then
				ok += 1
				sum += w
			end
		end
		if ok == 4 and (not v or v < sum / 4 - 3) then
			holes[#holes + 1] = string.format("(%d, %d) %s 이웃 %.1f", x, z, v and string.format("%.1f", v) or "없음", sum / 4)
		end
	end
end
out[#out + 1] = string.format("== 땅 구멍 %d", #holes)
for i = 1, math.min(60, #holes) do
	out[#out + 1] = "  " .. holes[i]
end
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/sancgap", table.concat(out, "\n"))
print("sancgap", #floating, #holes)
