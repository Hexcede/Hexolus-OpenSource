local PiperPlacer = {}

function PiperPlacer.new(model)
	local Placer = {}
	Placer.Model = model
	Placer.Rotation = 0
	
	local endEvent = Instance.new("BindableEvent")
	Placer.Ended = endEvent.Event
	Placer.Valid = false
	
	local previousPosition, previousNormal, previousCenter
	function Placer:Update(position, normal, center)
		previousPosition, previousNormal, previousCenter = position, normal, center
		self.Valid = true

	end

	function Placer:Add(...)
		self:Update(...)
		if self.Valid then
			self:Cancel(true)
		end
	end
	
	function Placer:Rotate(amount)
		self.Rotation = (self.Rotation + amount) % 360
		
		if previousPosition and previousNormal and previousCenter then
			Placer:Update(previousPosition, previousNormal, previousCenter)
		end
	end
	
	function Placer:Cancel(didPlace)
		if endEvent then
			local event = endEvent
			endEvent = nil
			
			event:Fire(didPlace)
			event:Destroy()
		end
	end
	
	return Placer
end

return PiperPlacer