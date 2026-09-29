--!nocheck
--[[
	Jeolhwa_Refresh.luau — 2026-09-27. 놓인 절화 가게와 마당 살림을 새 틀로 갈아 끼운다.

	가게(Shop_Row5, Shop_Row3)는 좌판 물건을 뺀 새 틀(ServerStorage.JeolhwaKit, Jeolhwa_Kit2 로 갈라 넣은 것)로,
	마당 살림(Prop_Jangdok, Prop_Well, Prop_Haystack, Prop_Garden)은 새로 깎은 Yard_* 소품
	(ServerStorage.JeolhwaProps)으로 바꾼다. 같은 자리(피벗), 같은 이름·부모·속성, 옛 모델 안의 받침돌(Foundation)은
	새 모델로 옮겨 담는다. ServerStorage.JeolhwaKit 의 Prop_* 틀도 Yard_* 로 바꿔(옛 틀은 JeolhwaKit_OldProps 에)
	절화를 다시 지어도 새 것이 나오게 한다. 다시 돌려도 된다(늘 새 틀로 다시 바꾼다).
	가게 좌판 물건은 Jeolhwa_Interiors.luau 가 얹는다. 가게를 바꾼 뒤 Jeolhwa_GateFix.luau 를 다시 돌릴 것.
]]

local SS = game:GetService("ServerStorage")
local kit = assert(SS:FindFirstChild("JeolhwaKit"), "ServerStorage.JeolhwaKit 이 없다")
local props = assert(SS:FindFirstChild("JeolhwaProps"), "ServerStorage.JeolhwaProps 가 없다")
local root = assert(workspace:FindFirstChild("Jeolhwa"), "Workspace.Jeolhwa 가 없다")

local YARD = { Prop_Jangdok = "Yard_Jangdok", Prop_Well = "Yard_Well", Prop_Haystack = "Yard_Haystack", Prop_Garden = "Yard_Garden" }
local SHOPS = { Shop_Row5 = true, Shop_Row3 = true }

-- 틀 바꾸기
local bak = SS:FindFirstChild("JeolhwaKit_OldProps")
if not bak then
	bak = Instance.new("Folder")
	bak.Name = "JeolhwaKit_OldProps"
	bak.Parent = SS
end
for old, new in pairs(YARD) do
	local src = assert(props:FindFirstChild(new), "소품 틀이 없다: " .. new)
	local t = kit:FindFirstChild(old)
	if t then
		if t:GetAttribute("Yard") then
			t:Destroy()
		else
			t.Parent = bak
		end
	end
	local c = src:Clone()
	c.Name = old
	c:SetAttribute("Yard", true)
	c.Parent = kit
end

-- 놓인 것 바꾸기
local list = {}
local skip = root:FindFirstChild("안살림")
for _, m in ipairs(root:GetDescendants()) do
	if m:IsA("Model") and (SHOPS[m.Name] or YARD[m.Name]) and not (skip and m:IsDescendantOf(skip)) then
		list[#list + 1] = m
	end
end
local counts, moved = {}, 0
for _, m in ipairs(list) do
	local src = SHOPS[m.Name] and kit:FindFirstChild(m.Name) or props:FindFirstChild(YARD[m.Name])
	assert(src, "새 틀이 없다: " .. m.Name)
	local c = src:Clone()
	c.Name = m.Name
	c:PivotTo(m:GetPivot())
	for k, v in pairs(m:GetAttributes()) do
		if not k:match("^RBX_") then -- 가져오기 기록 같은 예약 속성은 스크립트가 못 쓴다
			c:SetAttribute(k, v)
		end
	end
	for _, ch in ipairs(m:GetChildren()) do
		if ch.Name == "Foundation" then
			ch.Parent = c
			moved += 1
		end
	end
	c.Parent = m.Parent
	m:Destroy()
	counts[c.Name] = (counts[c.Name] or 0) + 1
end
local parts = {}
for k, v in pairs(counts) do
	parts[#parts + 1] = k .. " " .. v
end
table.sort(parts)
print("refresh", table.concat(parts, ", "), "받침돌 옮김 " .. moved)
