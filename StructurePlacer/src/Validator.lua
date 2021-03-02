local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")

local Validator = {}

function Validator:IsPartOOB(part)
	return not CollectionService:HasTag(part, "Hitbox") and PhysicsService:CollisionGroupsAreCollidable("Default", PhysicsService:GetCollisionGroupName(part.CollisionGroupId))
end

local function void()end
local position, size = Vector3.new(), Vector3.new()
local region = Region3.new()
local partsInRange = {}

local collider = Instance.new("Part")
collider.Name = "Collider"
collider.Transparency = 1
--collider.CanCollide = false
collider.Anchored = true
collider.Touched:Connect(void)

PhysicsService:SetPartCollisionGroup(collider, "PlacementCollisionGroup")

collider.Parent = workspace.CurrentCamera

function Validator:Collides(part, ignoreDescendantsInstances, useCollisionTag, passRegion3Check)
	if not passRegion3Check then
		position, size = part.Position, part.Size

		region = Region3.new(position - size/2, position + size/2)
		--region:ExpandToGrid(4)
		
		partsInRange = workspace:FindPartsInRegion3WithIgnoreList(region, ignoreDescendantsInstances, 1)[1]
		if not partsInRange then
			return
		end
	end

	if useCollisionTag then
		if not CollectionService:HasTag(part, "PlacerCollision") then
			return false
		end
	end

	collider.Size = part.Size
	workspace:BulkMoveTo({collider}, {part.CFrame}, Enum.BulkMoveMode.FireCFrameChanged)
	local touching = collider:GetTouchingParts()
	if touching[1] then
		local ignore = false
		for _, touchingPart in ipairs(touching) do
			for _, instance in ipairs(ignoreDescendantsInstances) do
				if instance:IsAncestorOf(touchingPart) then
					ignore = true
					break
				end
			end

			if ignore then
				ignore = false
				continue
			end

			if self:IsPartOOB(touchingPart) then
				return true
			end
		end
	end

	return false
end

function Validator:ModelCollides(model, ignoreDescendantsInstances)
	if ignoreDescendantsInstances then
		table.insert(ignoreDescendantsInstances, model)
		table.insert(ignoreDescendantsInstances, workspace.CurrentCamera)
		table.insert(ignoreDescendantsInstances, workspace:WaitForChild("Effects"))
	else
		ignoreDescendantsInstances = {model, workspace:WaitForChild("Effects"), workspace.CurrentCamera}
	end
	
	local reparents = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if CollectionService:HasTag(descendant, "Effect") then
			reparents[descendant] = descendant.Parent
			descendant.Parent = workspace.CurrentCamera
		end
	end
	local cframe, size = model:GetBoundingBox()
	for descendant, parent in pairs(reparents) do
		descendant.Parent = parent
	end
	local position = cframe.Position
	
	local region = Region3.new(position - size/2, position + size/2)
	--region:ExpandToGrid(4)

	local reparent
	local parent
	if not model:IsDescendantOf(workspace) then
		parent = model.Parent
		model.Parent = workspace.CurrentCamera
		reparent = true
	end

	local partsInRange = workspace:FindPartsInRegion3WithIgnoreList(region, ignoreDescendantsInstances, 1)[1]
	if partsInRange then
		local useCollisionTag = CollectionService:HasTag(model, "PlacerCollision")
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				if self:Collides(part, ignoreDescendantsInstances, useCollisionTag, true) then
					if reparent then
						model.Parent = parent
					end
					return true
				end
			end
		end
	end

	if reparent then
		model.Parent = parent
	end
	return false
end

return Validator