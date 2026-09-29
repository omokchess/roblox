--!nocheck
--[[
	Probe_Geothermal.luau — 지반을 광선으로 훑어 ASCII 높이 지도를 출력한다.

	맵을 손으로 꾸미기 전에 **어디가 뭍이고 높이가 얼마인지 먼저 재려고** 만들었다.
	칸 하나가 높이/10 을 가리키는 글자다 ('.' 은 바다, B=11 이면 110~119).

	읽는 법: 커맨드 바에 붙여 실행 → 출력창 클릭 → Ctrl+A, Ctrl+C →
	클립보드를 읽으면 지도가 통째로 나온다. 스크린샷으로 읽지 말 것.

	R 의 한 줄은 { 이름, x0, x1, x간격, z0, z1, z간격 } 이다. 볼 곳만 적어 쓴다.
]]

local Z = workspace.Surface["Zone_화산"]
local out = {}
local function scan(f, path)
	local lo, hi, cnt = 1e9, -1e9, 0
	for _, d in ipairs(f:GetDescendants()) do
		if d:IsA("BasePart") then
			lo = math.min(lo, d.Position.Y - d.Size.Y / 2)
			hi = math.max(hi, d.Position.Y + d.Size.Y / 2)
			cnt = cnt + 1
		end
	end
	if cnt > 0 then
		out[#out + 1] = string.format("%-22s %3d  바닥%7.1f  꼭대기%7.1f", path, cnt, lo, hi)
	end
end
for _, a in ipairs(Z:GetChildren()) do
	scan(a, a.Name)
	for _, b in ipairs(a:GetChildren()) do
		if b:IsA("Folder") then
			scan(b, "   " .. b.Name)
		end
	end
end
print(table.concat(out, "\n"))
