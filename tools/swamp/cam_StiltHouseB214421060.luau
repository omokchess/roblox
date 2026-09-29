local root = workspace.Surface["Swamp2_늪지대"]
for _, m in ipairs(root:GetDescendants()) do
	if m:IsA("Model") and m:GetAttribute("Asset") == "StiltHouseB2" then
		local piv = m:GetPivot()
		local p = piv:PointToWorldSpace(Vector3.new(14.4, 21.0, -6.0))
		workspace.CurrentCamera.CFrame = CFrame.lookAt(p + piv:VectorToWorldSpace(Vector3.new(5, 0.5, 4)), p)
		break
	end
end
