local out, count = {}, {}
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and not d:IsA("Terrain") then
		local top = d.Position.Y + d.Size.Y / 2
		if top < -3.5 and not d.Name:match("^Gb_") and not d.Name:match("^Gs_") then
			local key = d.Parent and d.Parent:GetFullName() or "?"
			count[key] = (count[key] or 0) + 1
		end
	end
end
for k, n in count do table.insert(out, k .. " " .. n) end
table.sort(out)
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/below", table.concat(out, "\n"))
