--!nocheck
-- Snow_WalkModels.luau — 2026-11-08 마을 모델 상자(snow_walkwidth.py 가 자리 이름을 붙일 때 씀)(이름 · 폴더 · 가운데 · 크기 · yaw) → /walk_models
local HS = game:GetService("HttpService")
local town = workspace.Schneereich["마을"]
local out = {}
for _, f in town:GetChildren() do
	for _, m in f:GetDescendants() do
		if m:IsA("Model") and m.Parent and (m.Parent == f or m.Parent.Parent == f) then
			local ok, cf, sz = pcall(function() return m:GetBoundingBox() end)
			if ok and sz.Magnitude > 6 then
				local piv = m:GetPivot()
				local _, yaw = piv:ToOrientation()
				table.insert(out, string.format("%s\t%s\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%.0f", f.Name, m.Name, cf.X, cf.Y, cf.Z, sz.X, sz.Y, sz.Z, math.deg(yaw)))
			end
		end
	end
end
HS:PostAsync("http://127.0.0.1:34999/walk_models", table.concat(out, "\n"))
