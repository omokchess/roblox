local root = workspace.Surface["Swamp2_늪지대"]
for _, m in ipairs(root:GetDescendants()) do
	if m:IsA("Model") and m:GetAttribute("Asset") == "StiltHouseA" then
		local piv = m:GetPivot()
		local p = piv:PointToWorldSpace(Vector3.new(11.9, 11.0, 11.0))
		workspace.CurrentCamera.CFrame = CFrame.lookAt(p + piv:VectorToWorldSpace(Vector3.new(-4, 0.5, 4)), p)
		break
	end
end
