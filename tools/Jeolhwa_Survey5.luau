--!nocheck
-- 2026-09-26 재배치 전 현황. Jeolhwa 폴더 전체, 틀 크기, 평원 경계, 스폰
local out = {}
local function say(f, ...) out[#out + 1] = string.format(f, ...) end
local ok, err = pcall(function()
	for _, c in ipairs(workspace:GetChildren()) do
		say("WS %s [%s] n=%d", c.Name, c.ClassName, #c:GetChildren())
	end
	local J = workspace:FindFirstChild("Jeolhwa")
	if J then
		for _, f in ipairs(J:GetChildren()) do
			say("J/%s [%s] n=%d", f.Name, f.ClassName, #f:GetChildren())
		end
		for _, fname in ipairs({ "Palace", "Features", "Trees" }) do
			local f = J:FindFirstChild(fname)
			if f then
				for _, m in ipairs(f:GetChildren()) do
					if m:IsA("Model") then
						local p = m:GetPivot()
						local _, yaw = p:ToOrientation()
						say("%s %s (%.1f,%.1f,%.1f) yaw %.0f", fname, m.Name, p.X, p.Y, p.Z, math.deg(yaw))
					else
						say("%s %s [%s]", fname, m.Name, m.ClassName)
					end
				end
			end
		end
		local P = J:FindFirstChild("Plots")
		if P then
			for _, plot in ipairs(P:GetChildren()) do
				local cf, sz = plot:IsA("Model") and plot:GetBoundingBox() or nil, nil
				local main
				for _, m in ipairs(plot:GetChildren()) do
					if m:IsA("Model") and m.Name:match("^Building_") then main = m end
				end
				if main then
					local p = main:GetPivot()
					local _, yaw = p:ToOrientation()
					say("Plot %s main %s (%.1f,%.1f,%.1f) yaw %.0f kids %d", plot.Name, main.Name, p.X, p.Y, p.Z, math.deg(yaw), #plot:GetChildren())
				else
					say("Plot %s kids %d", plot.Name, #plot:GetChildren())
				end
			end
		end
		local R = J:FindFirstChild("Roads")
		if R then for _, r in ipairs(R:GetChildren()) do say("Road %s n=%d", r.Name, #r:GetChildren()) end end
	end
	local kit = game:GetService("ServerStorage"):FindFirstChild("JeolhwaKit")
	if kit then
		for _, m in ipairs(kit:GetChildren()) do
			local cf, s = m:GetBoundingBox()
			say("Kit %s %.1fx%.1fx%.1f parts=%d", m.Name, s.X, s.Y, s.Z, #m:GetDescendants())
		end
	end
	local G = workspace.Surface.World:FindFirstChild("G_평원")
	if G then
		local cf, s = G:GetBoundingBox()
		say("G_평원 center (%.0f,%.0f,%.0f) size %.0fx%.0fx%.0f n=%d", cf.X, cf.Y, cf.Z, s.X, s.Y, s.Z, #G:GetDescendants())
	end
	for _, c in ipairs(workspace.Surface:GetChildren()) do say("Surface/%s n=%d", c.Name, #c:GetChildren()) end
	local R = workspace.Surface:FindFirstChild("R_평원")
	if R then for _, c in ipairs(R:GetChildren()) do say("R_평원/%s [%s] n=%d", c.Name, c.ClassName, #c:GetDescendants()) end end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") then say("Spawn %s (%.0f,%.0f,%.0f)", d:GetFullName(), d.Position.X, d.Position.Y, d.Position.Z) end
	end
end)
if not ok then say("ERR %s", tostring(err)) end
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
local okp, e2 = pcall(function() HS:PostAsync("http://127.0.0.1:34999/survey5", table.concat(out, "\n")) end)
HS.HttpEnabled = was
print("survey5 lines", #out, okp, e2)
