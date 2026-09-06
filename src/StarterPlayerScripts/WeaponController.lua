-- Client-side input for the currently equipped weapon. Only ever sends
-- "where did I aim" to the server (WeaponServer.lua); all damage and ammo
-- bookkeeping is decided server-side.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local Remotes = require(ReplicatedStorage.Modules.Remotes)

local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local WeaponController = {}

local currentTool = nil
local mouseHeld = false
local hookedTools = setmetatable({}, { __mode = "k" })

local function drawTracer(origin, hitPosition)
	local distance = (hitPosition - origin).Magnitude
	local tracer = Instance.new("Part")
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 240, 150)
	tracer.Size = Vector3.new(0.08, 0.08, distance)
	tracer.CFrame = CFrame.new(origin, hitPosition) * CFrame.new(0, 0, -distance / 2)
	tracer.Parent = workspace
	Debris:AddItem(tracer, 0.05)
end

local function fireOnce(tool)
	local weaponId = tool:GetAttribute("WeaponId")
	local weapon = GameConfig.GetWeapon(weaponId)
	if not weapon then
		return
	end

	if not weapon.Infinite and (tool:GetAttribute("ClipAmmo") or 0) <= 0 then
		Remotes.RequestReload:FireServer(weaponId)
		return
	end

	local mouse = LocalPlayer:GetMouse()
	local origin = camera.CFrame.Position
	local targetPoint = mouse.Hit and mouse.Hit.Position or (origin + camera.CFrame.LookVector * 300)
	local direction = (targetPoint - origin)
	if direction.Magnitude < 0.01 then
		return
	end
	direction = direction.Unit

	drawTracer(origin, origin + direction * 300)
	Remotes.FireWeapon:FireServer(origin, direction, weaponId)
end

local function fireLoop(tool)
	while mouseHeld and currentTool == tool and tool.Parent do
		fireOnce(tool)
		local weapon = GameConfig.GetWeapon(tool:GetAttribute("WeaponId"))
		task.wait(weapon and weapon.FireRate or 0.3)
	end
end

local function hookTool(tool)
	if hookedTools[tool] then
		return
	end
	hookedTools[tool] = true

	tool.Equipped:Connect(function()
		currentTool = tool
	end)
	tool.Unequipped:Connect(function()
		if currentTool == tool then
			currentTool = nil
		end
	end)
end

local function hookExistingTools(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") then
			hookTool(child)
		end
	end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			hookTool(child)
		end
	end)
end

function WeaponController.Init()
	local backpack = LocalPlayer:WaitForChild("Backpack")
	hookExistingTools(backpack)

	local function onCharacterAdded(character)
		hookExistingTools(character)
	end
	LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
	if LocalPlayer.Character then
		onCharacterAdded(LocalPlayer.Character)
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if not currentTool then
			return
		end
		mouseHeld = true
		local weapon = GameConfig.GetWeapon(currentTool:GetAttribute("WeaponId"))
		if weapon and weapon.Automatic then
			task.spawn(fireLoop, currentTool)
		else
			fireOnce(currentTool)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			mouseHeld = false
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R and currentTool then
			Remotes.RequestReload:FireServer(currentTool:GetAttribute("WeaponId"))
		end
	end)
end

return WeaponController
