--!nocheck
-- 3판 점검. 받침돌이 높은 건물, 건물 발자국에 걸린 새 나무, 물에 잠긴 기단
local out = {}
local function say(f, ...)
	out[#out + 1] = string.format(f, ...)
end
local ok, err = pcall(function()
	local city = workspace.Jeolhwa
	-- 받침돌 높이 2 넘는 것
	for _, d in ipairs(city:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Foundation" and d.Size.Y > 2.5 then
			local m = d.Parent
			say("받침 %.1f  %s  (%.0f,%.0f)", d.Size.Y - 1, m:GetFullName():sub(18), d.Position.X, d.Position.Z)
		end
	end
	-- 새 나무 줄기가 건물 발자국 안에 섰는지
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { city["나무"], workspace.Surface, city["길"], city["논밭"], city["돌"], city["물"] }
	for _, t in ipairs(city["나무"]:GetChildren()) do
		local p = t:GetPivot().Position
		local hits = workspace:GetPartBoundsInBox(CFrame.new(p + Vector3.new(0, 12, 0)), Vector3.new(14, 20, 14), op)
		local seen = {}
		for _, h in ipairs(hits) do
			local m = h:FindFirstAncestorOfClass("Model")
			if m and not seen[m] then
				seen[m] = true
				say("나무 %s (%.0f,%.0f) 에 %s", t.Name, p.X, p.Z, m.Name)
			end
		end
	end
end)
if not ok then
	say("ERR %s", tostring(err))
end
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/check3", table.concat(out, "\n"))
end)
HS.HttpEnabled = was
print("check3", #out)
