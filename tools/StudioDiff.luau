--!nocheck
-- StudioDiff.luau — sync.json 목록의 Studio 스크립트 Source 를 저장소 파일과 견줘 다른 것만 보낸다. (2026-09-29)
-- Studio 안에서 (어시스턴트 등이) 고친 스크립트를 저장소로 되가져오려고 쓴다. 보고: /studiodiff, 다른 파일은 /studiosrc_<경로>
local HS = game:GetService("HttpService")
local out = {}
local ok, err = pcall(function()
	local list = HS:JSONDecode(HS:GetAsync("http://127.0.0.1:35001/tools/sync.json", true))
	local same, diff, missing = 0, 0, 0
	for _, it in ipairs(list) do
		local node = game:GetService(it.path[1])
		for i = 2, #it.path do
			node = node and node:FindFirstChild(it.path[i])
		end
		if not node then
			missing += 1
			out[#out + 1] = "없음 " .. it.file
		else
			local repo = HS:GetAsync("http://127.0.0.1:35001/" .. it.file, true):gsub("\r\n", "\n")
			local src = node.Source:gsub("\r\n", "\n")
			if repo == src then
				same += 1
			else
				diff += 1
				out[#out + 1] = "다름 " .. it.file .. " " .. node:GetFullName()
				HS:PostAsync("http://127.0.0.1:34999/studiosrc_" .. it.file:gsub("/", "__"), src)
			end
		end
	end
	table.insert(out, 1, string.format("같음 %d 다름 %d 없음 %d", same, diff, missing))
end)
if not ok then
	out[#out + 1] = "ERR " .. tostring(err)
end
HS:PostAsync("http://127.0.0.1:34999/studiodiff", table.concat(out, "\n"))
