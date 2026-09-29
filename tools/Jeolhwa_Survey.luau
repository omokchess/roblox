--!nocheck
-- Jeolhwa_Survey.luau — 절화 자리 조사. 아무것도 바꾸지 않고 REPORT 만 남긴다
local out = {}
local function say(s) out[#out + 1] = s end
pcall(function()
	for _, c in ipairs(workspace:GetChildren()) do
		if not c:IsA("Terrain") and not c:IsA("Camera") then
			local n = #c:GetDescendants()
			local ok, cf, sz = pcall(function() return c:GetBoundingBox() end)
			if c:IsA("Model") and ok then
				say(string.format("%s[%s] n=%d c=(%.0f,%.0f,%.0f) s=(%.0f,%.0f,%.0f)", c.Name, c.ClassName, n, cf.X, cf.Y, cf.Z, sz.X, sz.Y, sz.Z))
			else
				say(string.format("%s[%s] n=%d", c.Name, c.ClassName, n))
			end
		end
	end
	local G = workspace.Surface.World["G_평원"]
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { G }
	local rpa = RaycastParams.new()
	rpa.FilterType = Enum.RaycastFilterType.Exclude
	rpa.FilterDescendantsInstances = {}
	-- 평원 전체 60 간격 격자. 땅 높이와, 땅보다 위에 뭔가 있으면 그 이름
	for z = -80, 1012, 60 do
		local row = { string.format("z%5d:", z) }
		for x = -705, 1145, 60 do
			local h = workspace:Raycast(Vector3.new(x, 3000, z), Vector3.new(0, -6000, 0), rp)
			local a = workspace:Raycast(Vector3.new(x, 3000, z), Vector3.new(0, -6000, 0), rpa)
			if not h then
				row[#row + 1] = "  ~~"
			else
				local tag = ""
				if a and a.Position.Y > h.Position.Y + 1 then
					local top = a.Instance
					while top.Parent and top.Parent ~= workspace and top.Parent.Parent ~= workspace do top = top.Parent end
					tag = string.sub(top.Name, 1, 2)
				end
				row[#row + 1] = string.format("%4.0f%s", h.Position.Y, tag)
			end
		end
		say(table.concat(row, " "))
	end
end)
local v = Instance.new("StringValue")
v.Name = "REPORT Survey"
v.Value = table.concat(out, "\n")
v.Parent = workspace
-- 로컬로 보고서만 보내고 HTTP 설정은 원래대로 돌린다
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
local ok, err = pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/survey", v.Value)
end)
HS.HttpEnabled = was
print("[조사] 전송", ok, err)
