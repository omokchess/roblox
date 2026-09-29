--!nocheck
--[[
	Islands_ElderCanopy.luau — 거목 잎을 더 채운다.

	잎이 90장뿐이라 줄기가 다 비쳐 보인다. 성긴 게 아니라 벗겨져 보인다.

	새 잎을 새로 디자인하지 않는다. **지금 달린 잎을 복제해서 빈 자리에 끼운다.**
	크기도 색도 재질도 원본에서 그대로 가져오므로 결이 달라지지 않는다.

	자리는 기존 잎이 이루는 덩어리 안에서 뽑는다. 겉껍질 쪽에 몰리게 해서
	속이 꽉 찬 공이 아니라 수관으로 읽히게 한다.

	이름을 For_Elder_ 로 붙이므로 Islands_PlaceElder 가 거목을 옮길 때 같이 따라간다.
	되돌리기: 이름이 For_Elder_Fill 로 시작하는 파트만 지우면 된다.
]]

local ADD = 190 -- 더 달 잎 개수
local SHELL = 0.55 -- 이 비율 바깥쪽에 몰아 넣는다. 0 이면 속까지 꽉 찬다

local R = workspace.Surface["R_숲"]
local flora = R.Flora

-- 기존 잎 모으기. 채워 넣은 잎은 원본으로 다시 쓰지 않는다
local src = {}
local mnx, mxx, mny, mxy, mnz, mxz = 1e9, -1e9, 1e9, -1e9, 1e9, -1e9
for _, p in ipairs(flora:GetChildren()) do
	if p:IsA("BasePart") and p.Name:match("^For_Elder") and not p.Name:match("^For_Elder_Fill") then
		src[#src + 1] = p
		mnx, mxx = math.min(mnx, p.Position.X), math.max(mxx, p.Position.X)
		mny, mxy = math.min(mny, p.Position.Y), math.max(mxy, p.Position.Y)
		mnz, mxz = math.min(mnz, p.Position.Z), math.max(mxz, p.Position.Z)
	end
end
assert(#src > 20, "원본 잎이 " .. #src .. "장뿐이다. 이름 규칙을 확인해라")

-- 이미 채워 넣은 것이 있으면 지우고 다시 한다. 두 번 돌려도 두 배가 되지 않는다
local old = 0
for _, p in ipairs(flora:GetChildren()) do
	if p.Name:match("^For_Elder_Fill") then
		p:Destroy()
		old += 1
	end
end

local cx, cy, cz = (mnx + mxx) / 2, (mny + mxy) / 2, (mnz + mxz) / 2
local rx, ry, rz = (mxx - mnx) / 2, (mxy - mny) / 2, (mxz - mnz) / 2

local rng = Random.new(31415)
local made = 0

for i = 1, ADD do
	-- 구면에서 방향을 고르게 뽑는다. 각도를 균등하게 뽑으면 극에 몰린다
	local u = rng:NextNumber(-1, 1)
	local th = rng:NextNumber(0, math.pi * 2)
	local s = math.sqrt(1 - u * u)
	local dx, dy, dz = s * math.cos(th), u, s * math.sin(th)

	-- 겉껍질 쪽에 몰리게. 속까지 균등하게 채우면 잎덩이가 아니라 공이 된다
	local f = SHELL + (1 - SHELL) * rng:NextNumber() ^ 0.5
	local px = cx + dx * rx * f
	local py = cy + dy * ry * f * 0.9
	local pz = cz + dz * rz * f

	local o = src[rng:NextInteger(1, #src)]
	local p = o:Clone()
	p.Name = string.format("For_Elder_Fill%d", i)
	p.Size = o.Size * rng:NextNumber(0.75, 1.35)
	p.CFrame = CFrame.new(px, py, pz)
		* CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.35, 0.35))
	-- 같은 색이 반복되면 덩어리로 뭉쳐 보인다. 명암만 살짝 흔든다
	local tint = (rng:NextNumber() < 0.5) and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
	p.Color = o.Color:Lerp(tint, rng:NextNumber(0, 0.14))
	p.Anchored = true
	p.Parent = flora
	made += 1
end

print(
	string.format(
		"[ElderCanopy] 원본 %d장 + 새로 %d장 (이전 채움 %d장 제거) / 수관 지름 %d x %d x %d",
		#src,
		made,
		old,
		rx * 2,
		ry * 2,
		rz * 2
	)
)
