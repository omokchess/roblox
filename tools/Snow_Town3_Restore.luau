--!nocheck
--[[
	Snow_Town3_Restore.luau — 설원 마을 3판을 되돌린다. (2026-11-14)
	Workspace.Schneereich.마을.Town3 를 지우고, ServerStorage.Snow_Town2_Backup 의 것을 제자리(마을 폴더)로 돌려놓는다.
	  - 폴더째 옮겨 둔 것: 마을 아래로(같은 이름 폴더가 이미 있으면 안으로 합친다)
	  - 일부만 옮겨 둔 폴더(돌·체스판·톱니): 마을 아래 같은 이름 폴더(없으면 새로)에 원래 이름으로 돌려놓는다
	백업 폴더는 비면 지운다. 도는 법: bash tools/job.sh tools/Snow_Town3_Restore.luau   보고: /snowtown3restore
]]
local report = {}
local function say(fmt, ...)
	report[#report + 1] = string.format(fmt, ...)
end

local ok, err = pcall(function()
	local SS = game:GetService("ServerStorage")
	local town = assert(workspace:FindFirstChild("Schneereich") and workspace.Schneereich:FindFirstChild("마을"), "Schneereich.마을 이 없다")
	local backup = assert(SS:FindFirstChild("Snow_Town2_Backup"), "ServerStorage.Snow_Town2_Backup 이 없다 — 되돌릴 것이 없다")
	local t3 = town:FindFirstChild("Town3")
	if t3 then
		t3:Destroy() -- 3판 결과물만 지운다
		say("Town3 폴더 지움")
	end
	local function restoreInto(inst, dest)
		local name = inst:GetAttribute("SnowOrigName") or inst.Name
		local same = dest:FindFirstChild(name)
		if same and same:IsA("Folder") and inst:IsA("Folder") then
			-- 같은 이름 폴더가 이미 있으면 안으로 합친다
			for _, c in ipairs(inst:GetChildren()) do
				restoreInto(c, same)
			end
			inst:Destroy() -- 비어 버린 백업 껍데기
			return
		end
		inst.Name = name
		if same then
			inst.Name = name .. "_복원"
		end
		inst:SetAttribute("SnowOrigName", nil)
		inst:SetAttribute("SnowOrigParent", nil)
		inst.Parent = dest
	end
	local nWhole, nPart = 0, 0
	for _, c in ipairs(backup:GetChildren()) do
		if c:GetAttribute("SnowPartialOf") then
			local name = c:GetAttribute("SnowPartialOf")
			local dest = town:FindFirstChild(name)
			if not dest then
				dest = Instance.new("Folder")
				dest.Name = name
				dest.Parent = town
			end
			for _, k in ipairs(c:GetChildren()) do
				local n = k:GetAttribute("SnowOrigName") or k.Name
				k.Name = n
				k:SetAttribute("SnowOrigName", nil)
				k.Parent = dest
				nPart += 1
			end
			c:Destroy() -- 비어 버린 보관함
		else
			restoreInto(c, town)
			nWhole += 1
		end
	end
	say("복원: 폴더째 %d, 일부 폴더 안 %d 개", nWhole, nPart)
	if #backup:GetChildren() == 0 then
		backup:Destroy()
		say("백업 폴더 비어서 지움")
	end
end)
if not ok then
	say("ERR %s", tostring(err))
end
print(table.concat(report, "\n"))
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/snowtown3restore", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
