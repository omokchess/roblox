--!nocheck
--[[
	Sanctuary_Revert.luau — 2026-09-27. Sanctuary_Build(백자+청화 리메이크)를 되돌린다 → recv/sancrevert.txt
	사용자가 "성역은 부서진 유적 느낌, 단색으로 원래 색감 그대로" 라고 해서 새 양식을 걷어낸다.
	  - Surface.Sanctuary_탑의성역 지움
	  - ServerStorage.탑의성역_옛것 의 Ruins_·Fill_·Struct_탑의성역 을 Surface 로 되돌림
	  - World.G_탑의성역 땅 조각을 OrigColor/OrigMat 속성대로 되칠하고 속성을 지움
]]
local SS = game:GetService("ServerStorage")
local S = workspace.Surface
local out = {}
local new = S:FindFirstChild("Sanctuary_탑의성역")
if new then
	new:Destroy()
	out[#out + 1] = "새 성역 지움"
end
local bak = SS:FindFirstChild("탑의성역_옛것")
if bak then
	for _, f in ipairs(bak:GetChildren()) do
		assert(not S:FindFirstChild(f.Name), "Surface 에 이미 " .. f.Name .. " 가 있다")
		f.Parent = S
		out[#out + 1] = "되돌림 " .. f.Name
	end
	if #bak:GetChildren() == 0 then
		bak:Destroy()
	end
end
local n = 0
for _, p in ipairs(S.World["G_탑의성역"]:GetChildren()) do
	local c, m = p:GetAttribute("OrigColor"), p:GetAttribute("OrigMat")
	if c and m then
		p.Color = c
		p.Material = Enum.Material[m]
		p:SetAttribute("OrigColor", nil)
		p:SetAttribute("OrigMat", nil)
		n += 1
	end
end
out[#out + 1] = "땅 조각 되칠 " .. n
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/sancrevert", table.concat(out, "\n"))
print("sancrevert", table.concat(out, ", "))
