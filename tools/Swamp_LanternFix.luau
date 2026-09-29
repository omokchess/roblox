--!nocheck
--[[
	Swamp_LanternFix.luau — 늪지대 키트 랜턴 중 **허공에 뜬 것**을 받친다. (2026-09-28)

	원본 에셋(참고 프로젝트 swamplib)의 "홀로 선 랜턴"(hang·bracket 없이 light=True)은
	난간 기둥·난간대 위 1스터드쯤 허공에 떠 있다. 메시는 하나로 합쳐져 있어 랜턴만 옮길 수 없으므로,
	그 아래를 **받침 기둥 + 쇠 받침판**으로 채운다. 좌표는 원본 부품표(parts json)에서 잰 값을 손으로 옮겼다.

	  랜턴 밑면 = 유리 원기둥 중심 − 0.735 (밑판 −0.62, 유리 중심 +0.11)
	  받침판 두께 0.08, 윗면은 랜턴 밑면 0.005 아래(같은 높이 면이 겹치지 않게)
	  이어 올리는 기둥은 0.40 — 난간 기둥(0.45)보다 가늘어 옆면이 겹치지 않는다

	자리는 모두 키트 로컬(= 모델 피벗 기준, 로블록스 좌표). 배율은 모델 GetScale 을 곱한다.
	각 모델 안 Folder "LanternFix" 에 넣는다 — 다시 돌리면 지우고 새로 세운다(되돌리기: 그 폴더 삭제).
	보고: /lanternfix
]]
local root = workspace.Surface["Swamp2_늪지대"]

-- 한 받침: 랜턴 유리 중심 L, 기둥 중심(x,z)·바닥 높이·굵기, 발판(foot) 여부
local STANDS = {
	Longhouse = {
		{ L = Vector3.new(-23.6, 12.31, 17.6), post = { -23.6, 17.6 }, base = 10.552, w = 0.40 },
		{ L = Vector3.new(23.6, 12.31, 17.6), post = { 23.6, 17.6 }, base = 10.553, w = 0.40 },
		{ L = Vector3.new(23.6, 12.31, -17.6), post = { 23.6, -17.6 }, base = 10.554, w = 0.40 },
		{ L = Vector3.new(-23.6, 12.31, -17.6), post = { -23.6, -17.6 }, base = 10.551, w = 0.40 },
	},
	-- 랜턴이 난간 기둥 모서리에서 (−0.3, −0.2) 비켜 있다 → 기둥은 난간 기둥 위, 받침판이 둘을 덮는다
	StiltHouseA = {
		{ L = Vector3.new(11.9, 11.71, 11.0), post = { 12.2, 11.2 }, base = 10.553, w = 0.40 },
	},
	-- 난간대(폭 0.24) 끝 위. 기둥은 난간대 안쪽으로 0.15
	StiltHouseB = {
		{ L = Vector3.new(14.4, 21.91, 4.0), post = { 14.4, 3.85 }, base = 19.99, w = 0.36 },
	},
	StiltHouseB2 = {
		{ L = Vector3.new(14.4, 21.91, -6.0), post = { 14.4, -6.15 }, base = 19.99, w = 0.36 },
		-- 통 옆 허공(통 중심에서 1.49 떨어짐, 통 반지름 1.09) → 바닥 판자(7.034)부터 세우는 등 기둥
		{ L = Vector3.new(-10.6, 11.71, 9.6), post = { -10.6, 9.6 }, base = 7.034, w = 0.34, foot = true, collide = true },
	},
}

--[[
	망루는 다르다: 원본 랜턴 두 개가 **지붕 기둥(0.7) 한가운데에 박혀** 있다(뚜껑·밑판 테만 삐져나옴).
	그래서 받침이 아니라, 그 기둥 안쪽 면(탑 가운데 쪽 대각선)에 까치발을 달고 **키트의 진짜 랜턴 메시**
	(BoardwalkJunction 의 랜턴: 사슬 0.3 짜리 한 개)를 복제해 매단다. 불빛 받침(LightAnchor)도 새 랜턴으로 옮긴다.
	  랜턴 거리 d = 기둥 모서리(0.495) + 랜턴 반지름(0.48) + 틈 0.12 ≈ 1.1 (대각선 방향)
	  사슬 꼭대기 = 유리 중심 + 1.29 → 팔 밑면
]]
local BRACKETS = {
	Watchtower = {
		{ post = Vector3.new(6.1, 39.61, 6.1), inward = Vector3.new(-1, 0, -1).Unit },
		{ post = Vector3.new(-6.1, 39.61, -6.1), inward = Vector3.new(1, 0, 1).Unit },
	},
}
local BRACKET_D = 1.1

local PLATE = 0.08
local CAP = 0.6 -- 받침판 한 변(랜턴 밑판 지름 0.92 보다 작게: 랜턴 밑에 숨은 받침으로 읽힌다)

local function look(model, suffix)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("MeshPart") and d.Name:sub(-#suffix) == suffix then
			return d
		end
	end
end

local function part(parent, name, size, cf, src, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CanQuery = collide == true
	p.Material = src and src.Material or Enum.Material.Wood
	p.MaterialVariant = src and src.MaterialVariant or ""
	p.Color = src and src.Color or Color3.fromRGB(70, 50, 36)
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local kitJunction = game:GetService("ServerStorage").SwampKit.BoardwalkJunction
local srcIron = kitJunction:FindFirstChild("BoardwalkJunction__iron", true)
local srcGlow = kitJunction:FindFirstChild("BoardwalkJunction__glow_lantern", true)
local IRON_ABOVE_GLOW = srcIron.Position.Y - srcGlow.Position.Y -- 0.28

-- 두 점을 잇는 각재(로컬 좌표). 굵기 t, 폭 w.
local function beamBetween(folder, piv, s, a, b, t, w, src)
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, b) -- 길이 방향 = −Z
	part(folder, "LanternBracket", Vector3.new(w, t, (b - a).Magnitude) * s, piv * (CFrame.new(mid * s) * cf.Rotation), src, false)
end

local out, made, models = {}, 0, {}
for _, m in ipairs(root:GetDescendants()) do
	local a = m:IsA("Model") and m:GetAttribute("Asset")
	local brackets = a and BRACKETS[a]
	if brackets then
		local old = m:FindFirstChild("LanternFix")
		if old then
			old:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "LanternFix"
		local wood = look(m, "__wood_dark")
		local piv, s = m:GetPivot(), m:GetScale()
		for _, br in ipairs(brackets) do
			local G = br.post + br.inward * BRACKET_D -- 새 랜턴 유리 중심(로컬)
			local armY = G.Y + 1.29 + 0.12 -- 팔 중심(팔 밑면 = 사슬 꼭대기)
			-- 팔: 기둥 속에서 시작해 랜턴 축을 0.15 지나간다
			beamBetween(folder, piv, s, Vector3.new(br.post.X, armY, br.post.Z), Vector3.new(G.X, armY, G.Z) + br.inward * 0.15, 0.24, 0.22, wood)
			-- 까치발: 기둥 면 아래에서 팔 가운데로
			local lo = br.post + br.inward * 0.3
			local hi = br.post + br.inward * 0.8
			beamBetween(folder, piv, s, Vector3.new(lo.X, armY - 0.85, lo.Z), Vector3.new(hi.X, armY - 0.08, hi.Z), 0.14, 0.14, wood)
			-- 랜턴: 키트 메시 복제
			local glow = srcGlow:Clone()
			glow.Size = srcGlow.Size * s
			glow.CFrame = piv * CFrame.new(G * s)
			glow.Anchored = true
			glow.Parent = folder
			local iron = srcIron:Clone()
			iron.Size = srcIron.Size * s
			iron.CFrame = piv * CFrame.new((G + Vector3.new(0, IRON_ABOVE_GLOW, 0)) * s)
			iron.Anchored = true
			iron.Parent = folder
			-- 기둥 속 불빛을 새 랜턴으로
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") and d.Name == "LightAnchor" then
					local l = piv:PointToObjectSpace(d.Position) / s
					if Vector3.new(l.X - br.post.X, 0, l.Z - br.post.Z).Magnitude < 1.0 then
						d.CFrame = piv * CFrame.new(G * s)
						out[#out + 1] = string.format("%s 불빛 옮김 (%.1f,%.1f)", a, G.X, G.Z)
					end
				end
			end
			made += 1
		end
		folder.Parent = m
		models[a] = (models[a] or 0) + 1
	end
	local list = a and STANDS[a]
	if list then
		local old = m:FindFirstChild("LanternFix")
		if old then
			old:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "LanternFix"
		local wood = look(m, "__wood_dark")
		local iron = look(m, "__iron")
		local piv, s = m:GetPivot(), m:GetScale()
		for _, st in ipairs(list) do
			local bottom = st.L.Y - 0.735 - 0.005 -- 받침판 윗면
			local plateLo = bottom - PLATE
			local px, pz = st.post[1], st.post[2]
			local base = st.base
			-- 발판(등 기둥만): 판자 위 0.14
			if st.foot then
				part(folder, "LanternStandFoot", Vector3.new(0.8, 0.14, 0.8) * s,
					piv * CFrame.new(Vector3.new(px, base + 0.07, pz) * s), wood, st.collide)
				base += 0.14
			end
			local h = plateLo - base
			assert(h > 0.05, a .. " 받침 높이가 음수: " .. h)
			part(folder, "LanternStandPost", Vector3.new(st.w, h, st.w) * s,
				piv * CFrame.new(Vector3.new(px, base + h / 2, pz) * s), wood, st.collide)
			-- 받침판: 기둥 중심과 랜턴 중심을 같이 덮는다
			local cx, cz = (px + st.L.X) / 2, (pz + st.L.Z) / 2
			local sx = CAP + math.abs(px - st.L.X)
			local sz = CAP + math.abs(pz - st.L.Z)
			part(folder, "LanternStandPlate", Vector3.new(sx, PLATE, sz) * s,
				piv * CFrame.new(Vector3.new(cx, plateLo + PLATE / 2, cz) * s), iron, false)
			made += 1
		end
		folder.Parent = m
		models[a] = (models[a] or 0) + 1
	end
end
for k, v in pairs(models) do
	out[#out + 1] = string.format("%s ×%d", k, v)
end
table.sort(out)
table.insert(out, 1, string.format("받침 %d개 세움", made))
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/lanternfix", table.concat(out, "\n"))
print("lanternfix", out[1])
