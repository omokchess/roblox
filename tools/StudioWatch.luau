--!nocheck
-- StudioWatch.luau — 스크립트 Source 가 바뀌면(어시스턴트 편집 등) 수신기로 알린다. 15초마다, 10시간 동안. (2026-09-29)
-- 보고: /watch_<n> (바뀐 스크립트 이름들). 다시 돌리면 앞 감시는 _G.StudioWatchId 가 바뀌어 스스로 멈춘다
local HS = game:GetService("HttpService")
local id = HS:GenerateGUID(false)
_G.StudioWatchId = id
local roots = {
	game:GetService("ReplicatedStorage"),
	game:GetService("ServerScriptService"),
	game:GetService("StarterPlayer"),
	game:GetService("StarterGui"),
	workspace,
}
local function snap()
	local t = {}
	for _, r in ipairs(roots) do
		for _, d in ipairs(r:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				t[d] = d.Source
			end
		end
	end
	return t
end
task.spawn(function()
	local before = snap()
	local n = 0
	local t0 = os.clock()
	while _G.StudioWatchId == id and os.clock() - t0 < 36000 do
		task.wait(15)
		local now = snap()
		local changed = {}
		for d, s in pairs(now) do
			if before[d] ~= s then
				changed[#changed + 1] = d:GetFullName() .. (before[d] and "" or " (새로)")
			end
		end
		for d in pairs(before) do
			if now[d] == nil then
				changed[#changed + 1] = "(지워짐) " .. tostring(d.Name)
			end
		end
		if #changed > 0 then
			n += 1
			pcall(function()
				HS:PostAsync("http://127.0.0.1:34999/watch_" .. n, os.date("%H:%M:%S") .. "\n" .. table.concat(changed, "\n"))
			end)
		end
		before = now
	end
end)
HS:PostAsync("http://127.0.0.1:34999/watch_start", os.date("%H:%M:%S"))
