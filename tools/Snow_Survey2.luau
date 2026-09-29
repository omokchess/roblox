--!nocheck
-- 2026-09-26 설원 도시 자리 측량. Zone_설원 지물 자리와 반경, 10 간격 높이(정수) 두 구역
local out = {}
local function say(f, ...)
	out[#out + 1] = string.format(f, ...)
end
local ok, err = pcall(function()
	local S = workspace.Surface
	local Z = S["Zone_설원"]
	for _, f in ipairs(Z:GetChildren()) do
		for _, m in ipairs(f:GetChildren()) do
			local cf, size
			if m:IsA("Model") then
				cf, size = m:GetBoundingBox()
			elseif m:IsA("BasePart") then
				cf, size = m.CFrame, m.Size
			elseif m:IsA("Folder") then
				local parts = {}
				for _, p in ipairs(m:GetDescendants()) do
					if p:IsA("BasePart") then
						parts[#parts + 1] = p
					end
				end
				if #parts > 0 then
					local x0, x1, z0, z1, y1 = 1e9, -1e9, 1e9, -1e9, -1e9
					for _, p in ipairs(parts) do
						x0 = math.min(x0, p.Position.X - p.Size.X / 2)
						x1 = math.max(x1, p.Position.X + p.Size.X / 2)
						z0 = math.min(z0, p.Position.Z - p.Size.Z / 2)
						z1 = math.max(z1, p.Position.Z + p.Size.Z / 2)
						y1 = math.max(y1, p.Position.Y + p.Size.Y / 2)
					end
					cf = CFrame.new((x0 + x1) / 2, y1, (z0 + z1) / 2)
					size = Vector3.new(x1 - x0, 0, z1 - z0)
				end
			end
			if cf then
				say("OBJ %s %s %.0f %.0f %.0f %.0f %.0f", f.Name, m.Name, cf.X, cf.Z, size.X, size.Z, cf.Y + size.Y / 2)
			end
		end
	end
	local G = S.World["G_설원"]
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { G }
	local function grid(tag, x0, x1, z0, z1, st)
		say("GRID %s %d %d %d %d %d", tag, x0, x1, z0, z1, st)
		for z = z0, z1, st do
			local row = {}
			for x = x0, x1, st do
				local h = workspace:Raycast(Vector3.new(x, 800, z), Vector3.new(0, -1600, 0), rp)
				row[#row + 1] = h and tostring(math.floor(h.Position.Y + 0.5)) or "x"
			end
			say("R %d %s", z, table.concat(row, " "))
		end
	end
	grid("W", -4960, -3960, -2920, -2420, 10)
	grid("E", -3500, -2900, -2900, -2400, 10)
	grid("B", -4000, -3500, -2760, -2400, 20)
end)
if not ok then
	say("ERR %s", tostring(err))
end
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/snow2", table.concat(out, "\n"))
end)
HS.HttpEnabled = was
print("snow2", #out)
