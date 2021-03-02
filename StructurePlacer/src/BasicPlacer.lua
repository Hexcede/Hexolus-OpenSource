local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Validator = require(script.Parent:WaitForChild("Validator"))

local BasicPlacer = {}

function BasicPlacer.new(model)
	local Placer = {}
	Placer.Model = model
	Placer.Rotation = 0
	
	local endEvent = Instance.new("BindableEvent")
	local validatedEvent = Instance.new("BindableEvent")

	Placer.Ended = endEvent.Event
	Placer.Validated = validatedEvent.Event
	Placer.Valid = false

	local prevValidity
	local function setValid(self, valid)
		self.Valid = valid

		if prevValidity ~= valid then
			validatedEvent:Fire(valid)
		end
		prevValidity = valid

		return valid
	end
	
	local previousPosition, previousNormal, previousCenter
	function Placer:Update(position, normal, center)
		previousPosition, previousNormal, previousCenter = position, normal, center
		
		-- Placer animation
		-- if RunService:IsClient() then
		-- 	position += normal * -0.15
		-- end
		position += normal * 0.15
		
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
		
		local centerPosition = position + normal * size.Y/2
		
		local centerOrientation = CFrame.lookAt(Vector3.new(), normal)
		centerOrientation = CFrame.fromMatrix(centerOrientation.Position, centerOrientation.RightVector, centerOrientation.LookVector, centerOrientation.UpVector)
		
		local rotationCFrame = CFrame.fromAxisAngle(normal, math.rad(self.Rotation))
		
		local x, y, z = centerOrientation:ToOrientation()
		local xRot, yRot, zRot = rotationCFrame:ToOrientation()
		
		local newCFrame = CFrame.fromOrientation(x + xRot, y + yRot, z + zRot) + centerPosition
		
		local primaryPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		model.PrimaryPart = primaryPart
		
		if not primaryPart then
			return
		end

		if primaryPart.AssemblyRootPart then
			primaryPart = primaryPart.AssemblyRootPart
		end
		
		primaryPart.Anchored = true
		
		local difference = cframe:ToObjectSpace(primaryPart.CFrame)
		workspace:BulkMoveTo({primaryPart}, {newCFrame * difference}, Enum.BulkMoveMode.FireCFrameChanged)

		return setValid(self, not Validator:ModelCollides(model))
	end

	function Placer:Add(...)
		local valid = self:Update(...)
		warn(valid)
		if valid then
			self:Cancel(true)
		end
		return valid
	end
	
	function Placer:Rotate(amount)
		self.Rotation = (self.Rotation + amount) % 360
		
		if previousPosition and previousNormal and previousCenter then
			Placer:Update(previousPosition, previousNormal, previousCenter)
		end
	end
	
	function Placer:Cancel(didPlace)
		if endEvent then
			didPlace = didPlace and self.Valid

			local event = endEvent
			endEvent = nil
			
			event:Fire(didPlace)
			event:Destroy()

			validatedEvent:Destroy()
		end
	end
	
	return Placer
end

return BasicPlacer