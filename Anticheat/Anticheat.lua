--[[
	[Hexolus Anticheat]
	 Author: Hexcede
	 Updated: 1/14/2020
	 Built for game version: 1.6.2-TA
	 Description:
	   Server-only movement checking & prevention of bad Roblox behaviours
	 Todo:
	   Use Velocity change event to update the player's maximum speed until they slow down
	   Improve flight detection prevention method (The current ground placement is extremely undesirable)
	 Todo (Non movement):
	   Prevent dropping of non CanBeDropped tools
	   Prevent deletion of Humanoid object by the client
	   Prevent undesirable Humanoid state behaviour
	   Prevent multi-tooling
	   Prevent usage of body parts as nuclear warheads against other players (Make all non-connected character body parts server owned)
--]]

local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalLinker = ReplicatedStorage:WaitForChild("LocalLinker", 1)
local Linker = LocalLinker and require(LocalLinker) or
	-- Code for running outside of Hexolus' environment
	{TrackConnection = function(connection)return connection end, GetService = function()end}

local Anticheat = {}
local DEBUG

Anticheat.ChecksEnabled = {
	Teleportation = true,
	Speed = true,
	Noclip = true,
	VerticalSpeeds = true,
	
	-- Currently fairly unstable, enabled in Hexolus' test place, but should be used cautiously
	-- Most applicable to parkour games, do not apply to PVP games as it will often mess up your players
	Flight = LocalLinker and true or false
}

Anticheat.Thresholds = {
	Acceleration = 1, -- Maximum vertical acceleration above expected
	Speed = 1, -- Maximum speed above expected
	VerticalSpeed = 1.5, -- Maximum vertical speed above expected
	VerticalSpeedCap = workspace.Gravity, -- Maximum vertical speed
	Teleportation = 2.5, -- Maximum teleport distance
	VerticalTeleportation = 2, -- Maximum teleport distance (vertical)
	GroundThreshold = 1, -- Distance from the ground to be considered on the ground
	FlightTimeThreshold = 1
}

local SMALL_DECIMAL = 1e-3
function Anticheat:TestPlayers(PlayerManager, delta)
	local function checkCast(results, root)
		if not results then
			return false
		end

		return results.Instance:CanCollideWith(root)
	end
	
	local function performCast(pos, dir, raycastParams, root)
		local results
		repeat
			results = workspace:Raycast(pos, dir, raycastParams)
			pos = results and results.Position + dir.Unit * 0.01
		until not pos or not results or checkCast(results, root)
		
		return results
	end
	
	local function dualCast(pos, dir, raycastParams, root)
		return performCast(pos, dir, raycastParams, root) or performCast(pos + dir, -dir, raycastParams, root)
	end
	
	local function resetData(playerData)
		local physicsData = {}
		
		playerData.PhysicsData = physicsData
		
		return physicsData
	end
	
	local reasons_DEBUG = {}
	for player, playerData in pairs(PlayerManager.Players) do
		coroutine.wrap(function()
			local reason_DEBUG = {}
			
			local physicsData = playerData.PhysicsData
			if not playerData.CharacterAddedEvent then
				playerData.CharacterAddedEvent = Linker:TrackConnection(player.CharacterAdded:Connect(function(character)
					physicsData = resetData(playerData)
					
					local activeHumanoidConnection_Death
					local activeHumanoidConnection_Seat
					local function trackHumanoid()
						if activeHumanoidConnection_Death then
							activeHumanoidConnection_Death:Disconnect()
						end
						
						local humanoid = character:FindFirstChildWhichIsA("Humanoid") or Instance.new("Humanoid", character)
						activeHumanoidConnection_Death = Linker:TrackConnection(humanoid.Died:Connect(function()
							physicsData = resetData(playerData)
						end))
						
						activeHumanoidConnection_Seat = Linker:TrackConnection(humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
							if humanoid.SeatPart then
								physicsData.Sitting = true
							else
								physicsData.Sitting = false
							end
						end))
					end
					
					character.ChildAdded:Connect(function(child)
						if child:IsA("Humanoid") then
							trackHumanoid()
						end
					end)
					
					trackHumanoid()
					
					-- An enormous thanks to grilme99 for letting me know that CFrame changed events fire when CFrame is set on the server					
					local rootPart = character.PrimaryPart or character:WaitForChild("HumanoidRootPart")
					rootPart:GetPropertyChangedSignal("CFrame"):Connect(function()
						local cframe = rootPart.CFrame
						
						physicsData.InitialCFrame = cframe
					end)
				end))
			end

			local character = physicsData and player.Character
			if character then
				if not physicsData.Sitting then
					local root = character.PrimaryPart
					
					-- Make sure they have a root
					if root then
						local updateJumpSpeed = false
						-- Positional checking
						do
							local flagForUpdate = false
							-- Don't check them if they're server-owned
							if root:GetNetworkOwner() ~= player then
								physicsData.InitialCFrame = root.CFrame
								physicsData.InitialVelocity = root.Velocity
								physicsData.Acceleration = root.Velocity - (physicsData.InitialVelocity or Vector3.new())
								return
							end
							
							-- Create raycast parameters for noclip, they'll reset upon respawn
							local raycastParams = physicsData and physicsData.RaycastParams or (function()
								local params = RaycastParams.new()

								params.FilterDescendantsInstances = {
									player.Character
								}
								params.IgnoreWater = true
								params.CollisionGroup = PhysicsService:GetCollisionGroupName(root.CollisionGroupId)
								params.FilterType = Enum.RaycastFilterType.Blacklist

								return params
							end)()
							
							-- Get their previous velocity
							local velocity = physicsData.InitialVelocity or root.Velocity
							-- Get only the horizontal component
							local horizontalVelocity = velocity * Vector3.new(1, 0, 1)
								-- Get only the vertical component
							local verticalSpeed = velocity.Y
							
							local updatedVelocity = velocity--horizontalVelocity + Vector3.new(0, verticalSpeed, 0)
							
							--local updatedVelocity = horizontalVelocity + Vector3.new(0, verticalSpeed, 0)
							
							-- Get the initial position of their character, and calculate the delta
							local initialPos = (physicsData.InitialCFrame and physicsData.InitialCFrame.p) or root.CFrame.p
							local localDelta = ((physicsData.InitTime and os.clock() - physicsData.InitTime) or 1)--delta)
							if localDelta == 0 then
								localDelta = delta
							end
							local realDiff = root.CFrame.p - initialPos
							
							-- If they had a previous speed
							if physicsData.InitialVelocity then
								--local expectedDiff = updatedVelocity * (localDelta * 2)
								local expectedDiff = updatedVelocity * (localDelta * 2)
								
								-- Check if they moved faster than expected
								local magFail = realDiff.Magnitude > (expectedDiff.Magnitude + self.Thresholds.Teleportation)

								-- General teleport check
								if Anticheat.ChecksEnabled.Teleportation then
									if magFail then
										table.insert(reason_DEBUG, "Teleport ("..realDiff.Magnitude.." studs, expected "..expectedDiff.Magnitude..")\n  Velocity: "..tostring(updatedVelocity).."\n  Delta: "..tostring(localDelta).."\n  IPos: "..tostring(initialPos).."\n  Pos: "..tostring(root.CFrame.p))
										
										-- Change their position to what was expected
										realDiff = realDiff.Unit * (expectedDiff.Magnitude + self.Thresholds.Teleportation)
										flagForUpdate = true
									end
								end
								
								-- On ground
								local _, charSize = character:GetBoundingBox()
								local height = charSize.Y
								
								local footDir = Vector3.new(0, -height/2 + 0.1, 0)
								local down = footDir + Vector3.new(0, -self.Thresholds.GroundThreshold, 0)
								local results = performCast(initialPos, down, raycastParams, root)
								
								if results then
									if not physicsData.OnGround then
										physicsData.OnGround = true
									end
								elseif physicsData.OnGround then
									physicsData.OnGround = false
									physicsData.LastOnGround = os.clock()
									updateJumpSpeed = true
									physicsData.JumpSpeed = root.Velocity.Y
								end

								-- Flight check
								if Anticheat.ChecksEnabled.Flight then
									if not physicsData.OnGround and root.Velocity.Y >= 0  then
										if physicsData.LastOnGround then
											local g = workspace.Gravity / (root.AssemblyMass or root.Mass)
											local v = physicsData.JumpSpeed or 0
											local jumpTime = v / g
											
											local jumpingTime = os.clock() - physicsData.LastOnGround
											if jumpingTime > jumpTime + self.Thresholds.FlightTimeThreshold then
												physicsData.OnGround = true
												
												local results = performCast(initialPos, footDir + Vector3.new(0, -10000, 0), raycastParams, root)
												if results then
													table.insert(reason_DEBUG, "Flight (Jump time: "..jumpingTime.." Expected: "..jumpTime..")")
													local cf = root.CFrame
													realDiff = results.Position - (cf.p + footDir)
													flagForUpdate = true
													
													root.Velocity *= Vector3.new(1, 0, 1)
													root.Velocity -= Vector3.new(0, workspace.Gravity, 0)
												end
											end
										end
									end
								end
							end

							-- Noclip check
							-- Wouldn't it be so hot if we had Boxcasting for this so we can cast their whole root part? ("Yes!" https://devforum.roblox.com/t/worldroot-spherecast-in-engine-spherecasting/959899)
							if Anticheat.ChecksEnabled.Noclip then
								local results = performCast(initialPos, realDiff, raycastParams, root) or performCast(initialPos, -realDiff, raycastParams, root)--workspace:Raycast(initialPos, realDiff, raycastParams) or workspace:Raycast(initialPos, -realDiff, raycastParams)
								if results then
									table.insert(reason_DEBUG, "Noclip ("..results.Instance:GetFullName()..")")

									-- Move them back to where they came from
									local diff = results.Position - initialPos

									diff = diff - diff.Unit * 0.5 + results.Normal * 2

									realDiff = diff
									flagForUpdate = true
								end
							end
							
							if flagForUpdate then
								-- Calculate the reset CFrame
								local position = initialPos + realDiff
								local cframe = CFrame.new(position, position+root.CFrame.LookVector)
								
								-- Reset their location without firing extra events (much smoother)
								workspace:BulkMoveTo({root}, {cframe}, Enum.BulkMoveMode.FireCFrameChanged)
							end
						end
						
						-- Velocity checking
						do
							-- Get their humanoid
							local humanoid = character:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid", character)
							
							local flagForUpdate = false
							if humanoid then
								local horizontalVelocity = root.Velocity * Vector3.new(1, 0, 1)
								local verticalSpeed = root.Velocity.Y

								local previousVerticalSpeed = (physicsData.InitialVelocity and physicsData.InitialVelocity.Y) or 0

								local initialVelocity = horizontalVelocity + Vector3.new(0, verticalSpeed, 0)
								physicsData.Acceleration = initialVelocity - (physicsData.InitialVelocity or Vector3.new())

								-- Make it a pain for exploiters to set WalkSpeed and stuff by blasting them with property updates
								-- This makes their speed hacks inconsistent and helps enforce client physics updates by causing big fluctuations in speed
								humanoid.WalkSpeed += SMALL_DECIMAL
								humanoid.WalkSpeed -= SMALL_DECIMAL
								-- Causes a lot of issues
								--humanoid.Health += SMALL_DECIMAL
								--humanoid.MaxHealth += SMALL_DECIMAL
								--humanoid.Health -= SMALL_DECIMAL
								--humanoid.MaxHealth -= SMALL_DECIMAL
								humanoid.JumpPower += SMALL_DECIMAL
								humanoid.JumpPower -= SMALL_DECIMAL
								humanoid.JumpHeight += SMALL_DECIMAL
								humanoid.JumpHeight -= SMALL_DECIMAL
								humanoid.HipHeight += SMALL_DECIMAL
								humanoid.HipHeight -= SMALL_DECIMAL
								humanoid.MaxSlopeAngle += SMALL_DECIMAL
								humanoid.MaxSlopeAngle -= SMALL_DECIMAL

								local walkSpeed = humanoid.WalkSpeed
								local jumpPower = humanoid.JumpPower
								
								if Anticheat.ChecksEnabled.VerticalSpeeds then
									if verticalSpeed > (jumpPower + self.Thresholds.VerticalSpeed) then
										if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
											table.insert(reason_DEBUG, "Vert Jump ("..verticalSpeed.." sps)")
											
											-- Jump vertical speed
											verticalSpeed = math.min(verticalSpeed, (jumpPower + self.Thresholds.VerticalSpeed))
											flagForUpdate = true
										else
											-- Non-jump vertical speed
											if humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
												if verticalSpeed > self.Thresholds.VerticalSpeedCap then
													table.insert(reason_DEBUG, "Vert Nojump ("..verticalSpeed.." sps)")
													
													verticalSpeed = math.min(verticalSpeed, self.Thresholds.VerticalSpeedCap)
													flagForUpdate = true
												end
											end

											-- Vertical acceleration
											if physicsData.Acceleration and verticalSpeed > 0 and physicsData.Acceleration.Y > previousVerticalSpeed + self.Thresholds.Acceleration then
												table.insert(reason_DEBUG, "Vert Accel ("..tostring(physicsData.Acceleration).." sps^2)")
												
												verticalSpeed = verticalSpeed - physicsData.Acceleration.Y + self.Thresholds.Acceleration
												flagForUpdate = true
											end
										end
									end
								end

								-- Speed check
								if Anticheat.ChecksEnabled.Speed then
									if horizontalVelocity.Magnitude > (walkSpeed + self.Thresholds.Speed) then
										table.insert(reason_DEBUG, "Speed ("..horizontalVelocity.Magnitude.." sps)")
										
										horizontalVelocity = horizontalVelocity.Unit * (walkSpeed + self.Thresholds.Speed)
										flagForUpdate = true
									end
								end
								
								if updateJumpSpeed then
									physicsData.JumpSpeed = verticalSpeed
								end

								initialVelocity = horizontalVelocity + Vector3.new(0, verticalSpeed, 0)
								if physicsData.InitialVelocity then
									physicsData.Acceleration = initialVelocity - physicsData.InitialVelocity
								else
									physicsData.Acceleration = Vector3.new()
								end

								if flagForUpdate then
									root.Velocity = initialVelocity
								end
							end
						end
						
						physicsData.InitTime = os.clock()
						physicsData.InitialVelocity = root.Velocity
						physicsData.InitialCFrame = root.CFrame
					end
				end
			end
			
			if DEBUG then
				if #reason_DEBUG > 0 then
					table.insert(reasons_DEBUG, table.concat({tostring(player)..":", table.concat(reason_DEBUG, "\n")}, " "))
				end
			end
		end)()
	end
	
	if DEBUG then
		if #reasons_DEBUG > 0 then
			warn("[Hexolus Anticheat] Summary of detections:\n  ", table.concat(reasons_DEBUG, "\n  "))
		end
	end
end

function Anticheat:Start()
	local PlayerManager = Linker:GetService("PlayerManager")
	
	-- Code for running outside of Hexolus' environment
	if not PlayerManager then
		local players = {}
		PlayerManager = {Players = players}
		
		local Players = game:GetService("Players")
		
		local function setupPlayer(player)
			players[player] = {}
		end
		
		for _, player in ipairs(Players:GetPlayers()) do
			setupPlayer(player)
		end
		Players.PlayerAdded:Connect(setupPlayer)
	end

	self:Stop()
	
	self.Heartbeat = Linker:TrackConnection(RunService.Heartbeat:Connect(function(delta)
		self:TestPlayers(PlayerManager, delta)
	end))
end

function Anticheat:Stop()
	if self.Heartbeat then
		self.Heartbeat:Disconnect()
	end
	if self.Stepped then
		self.Stepped:Disconnect()
	end
end

return function()
	if Linker.Flags then
		DEBUG = Linker.Flags.DEBUG
		
		if DEBUG then
			warn("[Hexolus Anticheat] Running in DEBUG mode.")
			
			if not LocalLinker then
				warn("[Hexolus Anticheat] Running outside of a Hexolus environment.")
			end
		end
	end
	
	Anticheat:Start()
	return Anticheat
end
