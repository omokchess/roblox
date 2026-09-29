local root = workspace.Surface["Swamp2_늪지대"]
for _, m in ipairs(root:GetDescendants()) do
	if m:IsA("Model") and m:GetAttribute("Asset") == "Watchtower" then
		local piv = m:GetPivot()
		local p = piv:PointToWorldSpace(Vector3.new(6.1, 39.0, 6.1))
		workspace.CurrentCamera.CFrame = CFrame.lookAt(p + piv:VectorToWorldSpace(Vector3.new(5, 1.5, 5)), p)
		break
	end
end
