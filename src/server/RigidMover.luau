--!strict
--[[
	RigidMover — 파트 묶음을 서버가 끄는 비행선·승강기용 도우미.
	서 있거나 앉은 캐릭터가 같이 실려 가도록, 움직이는 동안만 묶음 전체를 비고정(Unanchored)으로 풀고
	안내 파트(고정, 보이지 않음)를 AlignPosition/AlignOrientation(Rigidity)으로 따라가게 한다.
	서 있을 땐 전부 고정. 파트는 root 에 WeldConstraint 로 붙인다(root 도 parts 에 넣어도 된다).
]]

local RigidMover = {}
RigidMover.__index = RigidMover

export type Mover = typeof(setmetatable(
	{} :: {
		root: BasePart,
		parts: { BasePart },
		extras: { BasePart },
		guide: BasePart,
		pos: AlignPosition,
		ori: AlignOrientation,
	},
	RigidMover
))

-- extras: 용접은 안 하고 고정/비고정만 같이 바꿀 파트(문짝 등 따로 움직이는 것)
function RigidMover.new(root: BasePart, parts: { BasePart }, extras: { BasePart }?): Mover
	local all = {}
	for _, part in parts do
		if part ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
		table.insert(all, part)
	end
	if not table.find(all, root) then
		table.insert(all, root)
	end

	local guide = Instance.new("Part")
	guide.Name = "MoverGuide"
	guide.Size = Vector3.one
	guide.Transparency = 1
	guide.Anchored = true
	guide.CanCollide = false
	guide.CanQuery = false
	guide.CanTouch = false
	guide.CFrame = root.CFrame
	guide.Parent = root

	local a0 = Instance.new("Attachment")
	a0.Name = "MoverAttachment"
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Parent = guide

	local pos = Instance.new("AlignPosition")
	pos.Mode = Enum.PositionAlignmentMode.TwoAttachment
	pos.Attachment0 = a0
	pos.Attachment1 = a1
	pos.RigidityEnabled = true
	pos.Enabled = false
	pos.Parent = root
	local ori = Instance.new("AlignOrientation")
	ori.Mode = Enum.OrientationAlignmentMode.TwoAttachment
	ori.Attachment0 = a0
	ori.Attachment1 = a1
	ori.RigidityEnabled = true
	ori.Enabled = false
	ori.Parent = root

	local self = setmetatable(
		{ root = root, parts = all, extras = extras or {}, guide = guide, pos = pos, ori = ori },
		RigidMover
	)
	self:SetAnchored(true)
	return self
end

function RigidMover.SetAnchored(self: Mover, anchored: boolean)
	for _, part in self.parts do
		part.Anchored = anchored
	end
	for _, part in self.extras do
		part.Anchored = anchored
	end
end

-- 움직이기 시작(현재 자리에서). 이후 Move 로 목표를 갱신
function RigidMover.Begin(self: Mover)
	self.guide.CFrame = self.root.CFrame
	self.pos.Enabled = true
	self.ori.Enabled = true
	self:SetAnchored(false)
	pcall(function()
		self.root:SetNetworkOwner(nil) -- 서버가 끈다(손님 물리 소유 금지)
	end)
end

function RigidMover.Move(self: Mover, cf: CFrame)
	self.guide.CFrame = cf
end

-- 끝: 마지막 자리 cf 로 놓고 고정
function RigidMover.End(self: Mover, cf: CFrame)
	self.guide.CFrame = cf
	self.pos.Enabled = false
	self.ori.Enabled = false
	self:SetAnchored(true)
	self.root.AssemblyLinearVelocity = Vector3.zero
	self.root.AssemblyAngularVelocity = Vector3.zero
end

return RigidMover
