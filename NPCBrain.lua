--[[
	Advanced R6 NPC AI System
	Features:
	- Intelligent pathfinding with obstacle avoidance
	- Player detection and tracking
	- Dynamic animation switching (walk/run)
	- State machine for behavior management
	- Smooth movement interpolation
]]

local NPCBrain = {}
NPCBrain.__index = NPCBrain

-- Configuration
local CONFIG = {
	DETECTION_RANGE = 100,
	DETECTION_UPDATE_INTERVAL = 0.5,
	PATHFINDING_UPDATE_INTERVAL = 1,
	WALK_SPEED = 20,
	RUN_SPEED = 40,
	WALK_ANIMATION = 112795495877676,
	RUN_ANIMATION = 113023472048096,
	ANIMATION_SPEED = 1,
	STOPPING_DISTANCE = 5,
	RAYCAST_DISTANCE = 50,
	AVOIDANCE_DISTANCE = 15,
	CORNER_CHECK_DISTANCE = 10,
	PATH_RECALCULATION_THRESHOLD = 20
}

-- State enums
local STATE = {
	IDLE = "IDLE",
	PATROLLING = "PATROLLING",
	PURSUING = "PURSUING",
	FLEEING = "FLEEING",
	STUCK = "STUCK"
}

function NPCBrain.new(character)
	assert(character, "Character is required")
	assert(character:FindFirstChild("Humanoid"), "Character must have Humanoid")
	assert(character:FindFirstChild("HumanoidRootPart"), "Character must have HumanoidRootPart")
	
	local self = setmetatable({}, NPCBrain)
	
	self.character = character
	self.humanoid = character:FindFirstChild("Humanoid")
	self.rootPart = character:FindFirstChild("HumanoidRootPart")
	
	-- State management
	self.currentState = STATE.IDLE
	self.lastSeenPlayer = nil
	self.lastSeenPosition = nil
	self.targetPlayer = nil
	
	-- Movement
	self.currentPath = {}
	self.pathIndex = 1
	self.currentTarget = nil
	self.movementDirection = Vector3.new(0, 0, 0)
	self.lastPosition = self.rootPart.Position
	
	-- Timers
	self.detectionTimer = 0
	self.pathfindingTimer = 0
	self.stuckTimer = 0
	self.animationTimer = 0
	self.lastUpdateTime = tick()
	
	-- Animation tracking
	self.currentAnimationTrack = nil
	self.isRunning = false
	
	-- Physics
	self.velocity = Vector3.new(0, 0, 0)
	self.stuckThreshold = 0.5
	self.stuckCheckDistance = 2
	
	-- Patrol waypoints (customize these)
	self.patrolWaypoints = self:GeneratePatrolWaypoints()
	self.currentWaypointIndex = 1
	
	-- Setup animation humanoid
	self.humanoid.Parent = character
	
	return self
end

function NPCBrain:GeneratePatrolWaypoints()
	-- Generates random patrol points in the workspace
	local waypoints = {}
	local spawnPos = self.rootPart.Position
	
	for i = 1, 5 do
		local randomOffset = Vector3.new(
			math.random(-50, 50),
			0,
			math.random(-50, 50)
		)
		table.insert(waypoints, spawnPos + randomOffset)
	end
	
	return waypoints
end

function NPCBrain:Update(deltaTime)
	self.detectionTimer = self.detectionTimer + deltaTime
	self.pathfindingTimer = self.pathfindingTimer + deltaTime
	self.stuckTimer = self.stuckTimer + deltaTime
	self.animationTimer = self.animationTimer + deltaTime
	
	-- Update detection
	if self.detectionTimer >= CONFIG.DETECTION_UPDATE_INTERVAL then
		self:DetectPlayers()
		self.detectionTimer = 0
	end
	
	-- Update pathfinding
	if self.pathfindingTimer >= CONFIG.PATHFINDING_UPDATE_INTERVAL then
		self:UpdatePathfinding()
		self.pathfindingTimer = 0
	end
	
	-- Check if stuck
	if self.stuckTimer >= 1 then
		self:CheckIfStuck()
		self.stuckTimer = 0
	end
	
	-- Update state machine
	self:UpdateState()
	
	-- Move towards target
	self:Move(deltaTime)
	
	-- Update animations
	self:UpdateAnimations()
end

function NPCBrain:DetectPlayers()
	local players = game:GetService("Players"):GetPlayers()
	self.targetPlayer = nil
	local closestDistance = CONFIG.DETECTION_RANGE
	
	for _, player in pairs(players) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local playerHumanoid = player.Character:FindFirstChild("Humanoid")
			if playerHumanoid and playerHumanoid.Health > 0 then
				local distance = (player.Character.HumanoidRootPart.Position - self.rootPart.Position).Magnitude
				
				if distance < closestDistance then
					-- Raycast to check line of sight
					if self:HasLineOfSight(player.Character.HumanoidRootPart.Position) then
						closestDistance = distance
						self.targetPlayer = player
						self.lastSeenPlayer = player
						self.lastSeenPosition = player.Character.HumanoidRootPart.Position
					end
				end
			end
		end
	end
end

function NPCBrain:HasLineOfSight(targetPosition)
	local rayOrigin = self.rootPart.Position + Vector3.new(0, 2, 0)
	local rayDirection = (targetPosition - rayOrigin).Unit * CONFIG.RAYCAST_DISTANCE
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {self.character}
	
	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	
	if result then
		local distance = (result.Position - rayOrigin).Magnitude
		local targetDistance = (targetPosition - rayOrigin).Magnitude
		return distance >= targetDistance
	end
	
	return true
end

function NPCBrain:UpdatePathfinding()
	if self.currentState == STATE.PURSUING and self.targetPlayer then
		local targetPos = self.targetPlayer.Character.HumanoidRootPart.Position
		self.currentTarget = targetPos
	elseif self.currentState == STATE.PATROLLING then
		local waypoint = self.patrolWaypoints[self.currentWaypointIndex]
		if waypoint then
			self.currentTarget = waypoint
			
			local distance = (self.rootPart.Position - waypoint).Magnitude
			if distance < CONFIG.STOPPING_DISTANCE then
				self.currentWaypointIndex = self.currentWaypointIndex + 1
				if self.currentWaypointIndex > #self.patrolWaypoints then
					self.currentWaypointIndex = 1
				end
			end
		end
	end
	
	-- Generate smooth path with obstacle avoidance
	if self.currentTarget then
		self.currentPath = self:GenerateSmoothPath(self.rootPart.Position, self.currentTarget)
		self.pathIndex = 1
	end
end

function NPCBrain:GenerateSmoothPath(startPos, endPos)
	local path = {startPos}
	local direction = (endPos - startPos).Unit
	local distance = (endPos - startPos).Magnitude
	
	-- Generate waypoints along the path
	local stepSize = CONFIG.CORNER_CHECK_DISTANCE
	for i = stepSize, distance, stepSize do
		local point = startPos + direction * i
		table.insert(path, point)
	end
	
	table.insert(path, endPos)
	
	-- Smooth the path with obstacle avoidance
	local smoothedPath = {}
	for i, waypoint in ipairs(path) do
		local avoidanceOffset = self:CalculateAvoidanceOffset(waypoint)
		table.insert(smoothedPath, waypoint + avoidanceOffset)
	end
	
	return smoothedPath
end

function NPCBrain:CalculateAvoidanceOffset(targetPos)
	local rayOrigin = self.rootPart.Position + Vector3.new(0, 2, 0)
	local rayDirection = (targetPos - rayOrigin).Unit * CONFIG.AVOIDANCE_DISTANCE
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {self.character}
	
	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	
	if result then
		-- Obstacle detected, calculate avoidance direction
		local normal = result.Normal
		local avoidanceDirection = Vector3.new(-normal.Z, 0, normal.X).Unit
		return avoidanceDirection * CONFIG.AVOIDANCE_DISTANCE
	end
	
	return Vector3.new(0, 0, 0)
end

function NPCBrain:UpdateState()
	if self.targetPlayer then
		self.currentState = STATE.PURSUING
	elseif self.lastSeenPosition and (tick() - (self.lastSeenTime or tick())) < 5 then
		-- Continue moving to last seen position
		self.currentState = STATE.PURSUING
	elseif self.currentState == STATE.STUCK then
		-- Try to unstuck
		if self.stuckTimer > 3 then
			self.currentState = STATE.PATROLLING
			self.stuckTimer = 0
		end
	else
		self.currentState = STATE.PATROLLING
	end
end

function NPCBrain:CheckIfStuck()
	local currentPos = self.rootPart.Position
	local distance = (currentPos - self.lastPosition).Magnitude
	
	if distance < self.stuckCheckDistance and self.currentState ~= STATE.IDLE then
		if self.currentState == STATE.STUCK then
			-- Try rotating and moving in different direction
			self:RandomWalk()
		else
			self.currentState = STATE.STUCK
		end
	end
	
	self.lastPosition = currentPos
end

function NPCBrain:RandomWalk()
	local randomAngle = math.rad(math.random(0, 360))
	local randomDirection = Vector3.new(
		math.cos(randomAngle),
		0,
		math.sin(randomAngle)
	).Unit
	
	self.movementDirection = randomDirection
	self.humanoid:MoveTo(self.rootPart.Position + randomDirection * 20)
end

function NPCBrain:Move(deltaTime)
	if not self.currentTarget or self.currentState == STATE.IDLE then
		self.humanoid:MoveTo(self.rootPart.Position)
		return
	end
	
	-- Get next waypoint
	local targetWaypoint = self.currentPath[self.pathIndex]
	
	if not targetWaypoint then
		self.humanoid:MoveTo(self.rootPart.Position)
		return
	end
	
	local distance = (self.rootPart.Position - targetWaypoint).Magnitude
	
	if distance < CONFIG.STOPPING_DISTANCE then
		self.pathIndex = self.pathIndex + 1
		if self.pathIndex > #self.currentPath then
			self.humanoid:MoveTo(self.rootPart.Position)
			return
		end
		targetWaypoint = self.currentPath[self.pathIndex]
	end
	
	-- Move towards waypoint
	local moveSpeed = self:ShouldRun() and CONFIG.RUN_SPEED or CONFIG.WALK_SPEED
	self.humanoid.WalkSpeed = moveSpeed
	self.humanoid:MoveTo(targetWaypoint)
	
	-- Calculate movement direction for animation blending
	self.movementDirection = (targetWaypoint - self.rootPart.Position).Unit
end

function NPCBrain:ShouldRun()
	return self.currentState == STATE.PURSUING and self.targetPlayer ~= nil
end

function NPCBrain:UpdateAnimations()
	local shouldRun = self:ShouldRun()
	
	if shouldRun ~= self.isRunning then
		self.isRunning = shouldRun
		self:PlayAnimation(shouldRun and CONFIG.RUN_ANIMATION or CONFIG.WALK_ANIMATION)
	end
end

function NPCBrain:PlayAnimation(animationId)
	-- Stop current animation
	if self.currentAnimationTrack then
		self.currentAnimationTrack:Stop()
	end
	
	-- Load and play new animation
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. tostring(animationId)
	
	self.currentAnimationTrack = self.humanoid:LoadAnimation(animation)
	self.currentAnimationTrack.Priority = Enum.AnimationPriority.Action
	self.currentAnimationTrack:Play()
	self.currentAnimationTrack:AdjustSpeed(CONFIG.ANIMATION_SPEED)
end

function NPCBrain:Destroy()
	if self.currentAnimationTrack then
		self.currentAnimationTrack:Stop()
	end
end

return NPCBrain
