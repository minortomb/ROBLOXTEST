-- Shared RemoteEvent registry. Safe to require from both server and client:
-- the server creates the events on first require, clients just wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENT_NAMES = {
	"RequestStartGame", -- client -> server: {difficultyId}
	"FireWeapon", -- client -> server: {origin, direction, weaponId}
	"RequestReload", -- client -> server: {weaponId}
	"GameStateChanged", -- server -> client: {phase, payload}
	"Notify", -- server -> client: {text, kind}
}

local Remotes = {}

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder then
	if RunService:IsServer() then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	else
		folder = ReplicatedStorage:WaitForChild("Remotes")
	end
end

for _, eventName in ipairs(EVENT_NAMES) do
	local event = folder:FindFirstChild(eventName)
	if not event then
		if RunService:IsServer() then
			event = Instance.new("RemoteEvent")
			event.Name = eventName
			event.Parent = folder
		else
			event = folder:WaitForChild(eventName)
		end
	end
	Remotes[eventName] = event
end

return Remotes
