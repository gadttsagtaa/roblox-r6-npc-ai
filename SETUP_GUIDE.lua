--[[
	Advanced NPC Pathfinding & Brain System - Setup Guide
	
	INSTALLATION INSTRUCTIONS:
	========================
	
	1. Copy NPCBrain.lua into ServerScriptService or as a ModuleScript
	2. Copy NPCController.lua into your R6 NPC character as a Script
	3. Make sure NPCBrain is accessible to NPCController (in same folder or use require)
	4. Customize the CONFIG section below for your game
	
	KEY FEATURES:
	=============
	✓ Real-time player detection with raycasting (line of sight)
	✓ Advanced pathfinding with obstacle avoidance
	✓ Dynamic walk/run animation switching based on player detection
	✓ State machine (IDLE, PATROLLING, PURSUING, STUCK)
	✓ Automatic stuck detection and recovery
	✓ Smooth path interpolation
	✓ Configurable detection range and speeds
	✓ Multi-waypoint patrol system
	✓ Performance optimized
	
	CONFIGURATION:
	===============
]]

-- CUSTOMIZE THESE VALUES FOR YOUR GAME
local CONFIG = {
	-- Detection
	DETECTION_RANGE = 100,                    -- How far the NPC can see (studs)
	DETECTION_UPDATE_INTERVAL = 0.5,          -- How often to scan for players (seconds)
	
	-- Movement
	WALK_SPEED = 20,                          -- Speed when not chasing
	RUN_SPEED = 40,                           -- Speed when chasing a player
	STOPPING_DISTANCE = 5,                    -- How close to get to target
	
	-- Animations (Your IDs)
	WALK_ANIMATION = 112795495877676,         -- Walk animation ID
	RUN_ANIMATION = 113023472048096,          -- Run animation ID
	ANIMATION_SPEED = 1,                      -- Animation playback speed
	
	-- Pathfinding
	PATHFINDING_UPDATE_INTERVAL = 1,          -- Recalculate path every N seconds
	RAYCAST_DISTANCE = 50,                    -- Distance for obstacle raycasting
	AVOIDANCE_DISTANCE = 15,                  -- How far to avoid obstacles
	
	-- Stuck Detection
	STUCK_CHECK_DISTANCE = 2,                 -- Distance threshold to detect being stuck
	STUCK_RECOVERY_TIME = 3,                  -- Seconds before attempting to unstuck
}

--[[
	ANIMATION IDs:
	Your animations:
	- Walk: 112795495877676
	- Run:  113023472048096
	
	To find other animation IDs:
	1. Search Roblox animation library
	2. Look at animation assets in Studio
	3. Copy the ID number (without rbxassetid://)
]]

--[[
	PATROL WAYPOINTS:
	The NPC will automatically patrol between random waypoints.
	You can customize GeneratePatrolWaypoints() in NPCBrain.lua to:
	
	1. Define fixed waypoints:
	   function NPCBrain:GeneratePatrolWaypoints()
	       local waypoints = {}
	       table.insert(waypoints, Vector3.new(0, 5, 0))      -- X, Y, Z
	       table.insert(waypoints, Vector3.new(50, 5, 0))
	       table.insert(waypoints, Vector3.new(50, 5, 50))
	       table.insert(waypoints, Vector3.new(0, 5, 50))
	       return waypoints
	   end
	
	2. Or keep the random generation for more organic patrol
]]

--[[
	BEHAVIOR MODES:
	===============
	
	IDLE:
	- NPC stands still
	- Actively scanning for players
	- Will switch to PURSUING if player detected
	
	PATROLLING:
	- NPC walks between waypoints
	- Uses WALK_SPEED
	- Plays WALK_ANIMATION
	- Switches to PURSUING if player detected
	
	PURSUING:
	- NPC runs toward last seen player
	- Uses RUN_SPEED
	- Plays RUN_ANIMATION
	- Uses pathfinding to navigate around obstacles
	- Returns to PATROLLING if player not visible for 5 seconds
	
	STUCK:
	- NPC detected it's not moving
	- Will strafe and try different directions
	- Automatically returns to PATROLLING after 3 seconds
]]

--[[
	ADVANCED FEATURES:
	==================
	
	1. LINE OF SIGHT:
	   The NPC uses raycasting to check if it can actually see the player
	   (not just within range). This creates more realistic detection.
	   
	2. OBSTACLE AVOIDANCE:
	   When moving, the NPC raycasts ahead and steers around obstacles
	   dynamically instead of walking into walls.
	   
	3. SMOOTH PATHFINDING:
	   Paths are generated with multiple waypoints and smoothed for
	   natural-looking movement instead of instant teleporting.
	   
	4. STATE MACHINE:
	   Behavior changes based on what's happening:
	   - Sees player? Chase them
	   - Lost them? Remember last position and move there
	   - Stuck? Try random directions
	   - Nothing? Patrol waypoints
	   
	5. PERFORMANCE OPTIMIZATION:
	   - Detection only runs every 0.5 seconds (not every frame)
	   - Pathfinding recalculates every 1 second
	   - Stuck checking every 1 second
	   - Uses efficient raycasting instead of expensive loops
]]

--[[
	HOW TO USE IN YOUR GAME:
	=======================
	
	STEP 1: Create your R6 NPC character in the workspace
	
	STEP 2: Place NPCBrain.lua as a ModuleScript inside the NPC or ServerScriptService
	   Example structure:
	   - Workspace
	     - MyNPC (Model/R6 Character)
	       - NPCController (Script) ← Place here
	       - NPCBrain (ModuleScript) ← Place here
	
	STEP 3: Update the require path in NPCController.lua if needed
	   Default: local NPCBrain = require(script:WaitForChild("NPCBrain"))
	
	STEP 4: Run the game - the NPC should start patrolling and detect players!
	
	TROUBLESHOOTING:
	================
	
	NPC not moving?
	- Check Humanoid.Health > 0
	- Verify WalkSpeed is set (default 20)
	- Make sure there's space to move (not blocked by parts)
	
	Animations not playing?
	- Verify animation IDs are correct
	- Check animation exists in Roblox library
	- Ensure Animate script isn't overriding animations
	
	NPC not detecting players?
	- Increase DETECTION_RANGE if needed
	- Check if players are within range
	- Verify line of sight (raycasting might be blocked)
	
	NPC stuck in corners?
	- Adjust AVOIDANCE_DISTANCE higher
	- Increase STUCK_CHECK_DISTANCE threshold
	- Make sure no terrain issues block movement
	
	CUSTOMIZATION EXAMPLES:
	=======================
	
	Make NPC faster:
	CONFIG.RUN_SPEED = 60
	CONFIG.WALK_SPEED = 30
	
	Increase detection range:
	CONFIG.DETECTION_RANGE = 200
	
	Make NPC more aggressive (chase longer):
	Change the 5 second timeout in UpdateState() to a higher value
	
	Add more waypoints:
	Modify GeneratePatrolWaypoints() to add more Vector3.new() points
	
	Change animation speeds:
	CONFIG.ANIMATION_SPEED = 1.5  -- 50% faster
]]
