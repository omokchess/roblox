--!nocheck
--[[
	Snow_Town3_MoveKeep_Undo.luau — Snow_Town3_MoveKeep 되돌리기. (2026-11-23, 프로그래밍 부서)
	ServerStorage.Snow_KeepMove_Backup 으로: KeepMoveMade 속성이 붙은 땅 상자(새로 만든 조각·메운 상자)를 지우고,
	백업해 둔 원본 Land 상자를 제자리(Parent)로 돌려놓고, Casino_Gate 를 OrigPivot 로 되돌린다. 끝나면 백업 폴더를 지운다.
	순서: bash tools/job.sh tools/Snow_Town3_MoveKeep_Undo.luau → 보고 /keepmove
]]
local report = {}
local function say(fmt, ...)
	report[#report + 1] = string.format(fmt, ...)
end
local okRun, errRun = pcall(function()
	local SS = game:GetService("ServerStorage")
	local bk = SS:FindFirstChild("Snow_KeepMove_Backup")
	if not bk then
		say("백업(ServerStorage.Snow_KeepMove_Backup)이 없다 — 되돌릴 것 없음")
		return
	end
	local G = assert(workspace:FindFirstChild("Surface") and workspace.Surface:FindFirstChild("R_설원3"), "Surface.R_설원3 이 없다")
	-- 1. 복구할 원본이 모두 제자리(Parent)를 갖는지 먼저 확인(하나라도 없으면 아무것도 안 함)
	local jobs = {}
	for _, f in ipairs(bk:GetChildren()) do
		local c, pv = f:FindFirstChild("Part"), f:FindFirstChild("Parent")
		if c and pv then
			if not (pv.Value and pv.Value:IsDescendantOf(workspace)) then
				say("멈춤: %s 의 원래 부모가 사라졌다. 아무것도 안 바꿨다", f.Name)
				return
			end
			jobs[#jobs + 1] = { c = c, parent = pv.Value }
		end
	end
	-- 2. 새로 만든 것 지우기
	local nDel = 0
	for _, p in ipairs(G:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("KeepMoveMade") then
			p:Destroy()
			nDel += 1
		end
	end
	-- 3. 원본 되돌리기
	for _, j in ipairs(jobs) do
		local c = j.c
		c.Name = c:GetAttribute("OrigName") or c.Name
		c:SetAttribute("OrigName", nil)
		c.Parent = j.parent
	end
	-- 4. Gate
	local gv = bk:FindFirstChild("Gate")
	local gate = gv and gv.Value
	if gate then
		local cf = gate:GetAttribute("OrigPivot")
		if typeof(cf) == "CFrame" then
			gate:PivotTo(cf)
			gate:SetAttribute("OrigPivot", nil)
			say("Casino_Gate 를 OrigPivot 로 되돌림")
		else
			say("OrigPivot 속성이 없다 — Gate 는 안 움직임")
		end
	else
		say("백업에 Gate 가 없다 — Gate 는 안 움직임")
	end
	bk:Destroy()
	say("되돌림: 새 상자 %d 개 삭제, 원본 Land 상자 %d 개 복구, 백업 폴더 삭제", nDel, #jobs)
end)
if not okRun then
	say("ERR %s", tostring(errRun))
end
print(table.concat(report, "\n"))
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/keepmove", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
