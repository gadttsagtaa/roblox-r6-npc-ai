--[[
	Main NPC Controller - Attach this script to your R6 NPC character
	This script manages the AI brain and runs the update loop
]]

local NPCBrain = require(script:WaitForChild("NPCBrain"))

-- Initialize the NPC brain
local npc = NPCBrain.new(script.Parent)

-- Main update loop
local lastUpdate = tick()
game:GetService("RunService").Heartbeat:Connect(function()
	local currentTime = tick()
	local deltaTime = currentTime - lastUpdate
	lastUpdate = currentTime
	
	if script.Parent:FindFirstChild("Humanoid") and script.Parent.Humanoid.Health > 0 then
		npc:Update(deltaTime)
	else
		npc:Destroy()
	end
end)

-- Cleanup on character death
script.Parent.Humanoid.Died:Connect(function()
	npc:Destroy()
	script:Destroy()
end)
