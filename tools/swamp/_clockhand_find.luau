--!nocheck
-- 기물군 본부 시계 바늘(ClockHand_Minute·ClockHand_Hour·ClockPin) 어디 남았는지 조사. 읽기 전용(2026-11-23).
-- bash tools/job.sh tools/swamp/_clockhand_find.luau → 보고 /clockhand
local report = {}
local function say(fmt, ...)
	report[#report + 1] = string.format(fmt, ...)
end
local okRun, errRun = pcall(function()
	local roots = { workspace, game:GetService("ServerStorage"), game:GetService("ReplicatedStorage"), game:GetService("Lighting"), game:GetService("StarterPack"), game:GetService("ServerScriptService") }
	local n = 0
	for _, r in ipairs(roots) do
		for _, d in ipairs(r:GetDescendants()) do
			if d.Name:find("ClockHand") or d.Name == "ClockPin" then
				n += 1
				if n <= 40 then
					say("발견 %s (%s)", d:GetFullName(), d.ClassName)
				end
			end
		end
	end
	say("이름에 ClockHand/ClockPin 이 든 것 모두 %d 개", n)
	local town = workspace:FindFirstChild("Schneereich") and workspace.Schneereich:FindFirstChild("마을")
	local gear = town and town:FindFirstChild("톱니")
	if gear then
		local names = {}
		for _, c in ipairs(gear:GetChildren()) do
			names[#names + 1] = c.Name
		end
		say("마을.톱니 아래 %d 개: %s", #names, table.concat(names, ", "))
	else
		say("마을.톱니 폴더가 없다")
	end
	local bk = game:GetService("ServerStorage"):FindFirstChild("Snow_Town2_Backup")
	if bk then
		local names = {}
		for _, c in ipairs(bk:GetChildren()) do
			names[#names + 1] = c.Name
		end
		say("Snow_Town2_Backup 아래: %s", table.concat(names, ", "))
	else
		say("ServerStorage.Snow_Town2_Backup 없음")
	end
	for _, nm in ipairs({ "Snow_Town3_Backup", "Snow_KeepMove_Backup" }) do
		say("ServerStorage.%s %s", nm, game:GetService("ServerStorage"):FindFirstChild(nm) and "있음" or "없음")
	end
	-- 태그 SnowGear 모델 중 시계 바늘 비슷한 것
	local CS = game:GetService("CollectionService")
	local g = 0
	for _, m in ipairs(CS:GetTagged("SnowGear")) do
		g += 1
		if m.Name:find("Clock") then
			say("SnowGear 태그: %s", m:GetFullName())
		end
	end
	say("SnowGear 태그 모델 %d 개", g)
	local hq = town and town:FindFirstChild("체스판") and town["체스판"]:FindFirstChild("Figuren_HQ")
	say("Figuren_HQ %s", hq and string.format("있음 (%.0f, %.1f, %.0f)", hq:GetPivot().X, hq:GetPivot().Y, hq:GetPivot().Z) or "없음")
end)
if not okRun then
	say("ERR %s", tostring(errRun))
end
print(table.concat(report, "\n"))
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/clockhand", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
