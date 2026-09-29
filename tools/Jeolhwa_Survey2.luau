--!nocheck
-- Jeolhwa_Survey2.luau — Surface 구조와 평원 위 물체 목록. 바꾸지 않는다
local out = {}
local function say(s) out[#out + 1] = s end
pcall(function()
	local function walk(inst, depth)
		for _, c in ipairs(inst:GetChildren()) do
			if c:IsA("Folder") or c:IsA("Model") then
				say(string.rep("  ", depth) .. c.Name .. " [" .. c.ClassName .. "] " .. #c:GetDescendants())
				if depth < 2 then walk(c, depth + 1) end
			end
		end
	end
	walk(workspace.Surface, 0)
	for _, svc in ipairs({ game.ServerStorage, game.ReplicatedStorage }) do
		for _, c in ipairs(svc:GetChildren()) do
			say(svc.Name .. "/" .. c.Name .. " [" .. c.ClassName .. "]")
		end
	end
	for _, d in ipairs(game:GetDescendants()) do
		local ok, n = pcall(function() return d.Name end)
		if ok and (string.find(n, "Jeolhwa") or string.find(n, "절화") or string.find(n, "Palace") or string.find(n, "Plaza")) then
			say("FOUND " .. d:GetFullName() .. " [" .. d.ClassName .. "]")
		end
	end
	-- 평원 경계 안 파트를 무리별로 센다. 땅 G_평원 은 뺀다
	local G = workspace.Surface.World["G_평원"]
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { G }
	local parts = workspace:GetPartBoundsInBox(CFrame.new(220, 50, 466), Vector3.new(1850, 200, 1092), op)
	local groups = {}
	for _, p in ipairs(parts) do
		local a = p
		while a.Parent and a.Parent.Parent and a.Parent.Parent ~= workspace.Surface and a.Parent ~= workspace do a = a.Parent end
		local k = a:GetFullName()
		local g = groups[k] or { n = 0, x0 = 1e9, x1 = -1e9, z0 = 1e9, z1 = -1e9 }
		g.n = g.n + 1
		g.x0 = math.min(g.x0, p.Position.X); g.x1 = math.max(g.x1, p.Position.X)
		g.z0 = math.min(g.z0, p.Position.Z); g.z1 = math.max(g.z1, p.Position.Z)
		groups[k] = g
	end
	for k, g in pairs(groups) do
		say(string.format("IN %s n=%d x %.0f..%.0f z %.0f..%.0f", k, g.n, g.x0, g.x1, g.z0, g.z1))
	end
end)
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
local ok, err = pcall(function() HS:PostAsync("http://127.0.0.1:34999/survey2", table.concat(out, "\n")) end)
HS.HttpEnabled = was
print("[조사2] 전송", ok, err)
