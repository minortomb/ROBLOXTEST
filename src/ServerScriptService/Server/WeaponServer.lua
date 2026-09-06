-- Server-authoritative hit validation (design doc section 13: all damage
-- and economy logic runs on the server to avoid cheating). Clients only
-- send where they aimed; this module decides whether that shot is legal
-- and what it hit.

local Players = game:GetService("Players")
local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)
local Remotes = require(game:GetService("ReplicatedStorage").Modules.Remotes)

local WeaponServer = {}

local MAX_RANGE = 350
-- Generous tolerance: the client sends its camera position as the shot
-- origin, and default third-person zoom can put the camera well away from
-- HumanoidRootPart. This is a coarse sanity check, not real anti-cheat.
local MAX_ORIGIN_DRIFT = 60
local HEADSHOT_MULTIPLIER = 2

local lastFireTime = {} -- [player] = { [weaponId] = os.clock() }

local function findEquippedTool(character, weaponId)
	for _, instance in ipairs(character:GetChildren()) do
		if instance:IsA("Tool") and instance:GetAttribute("WeaponId") == weaponId then
			return instance
		end
	end
	return nil
end

local function isZombieModel(model)
	return model ~= nil and model:GetAttribute("ZombieType") ~= nil
end

local function fireSingleRay(origin, direction, ignoreList)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList
	return workspace:Raycast(origin, direction * MAX_RANGE, params)
end

local function spreadDirection(baseDirection, spreadDegrees)
	if spreadDegrees <= 0 then
		return baseDirection
	end
	local randomAngleX = math.rad((math.random() - 0.5) * 2 * spreadDegrees)
	local randomAngleY = math.rad((math.random() - 0.5) * 2 * spreadDegrees)
	local cframe = CFrame.new(Vector3.new(), baseDirection) * CFrame.Angles(randomAngleY, randomAngleX, 0)
	return cframe.LookVector
end

local function handleFireWeapon(player, origin, direction, weaponId)
	local weapon = GameConfig.GetWeapon(weaponId)
	if not weapon or typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	if direction.Magnitude < 0.01 then
		return
	end
	direction = direction.Unit

	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end

	if (origin - rootPart.Position).Magnitude > MAX_ORIGIN_DRIFT then
		return
	end

	local tool = findEquippedTool(character, weaponId)
	if not tool then
		return
	end

	lastFireTime[player] = lastFireTime[player] or {}
	local now = os.clock()
	local lastTime = lastFireTime[player][weaponId] or 0
	if now - lastTime < weapon.FireRate - 0.02 then
		return
	end

	if not weapon.Infinite then
		local clipAmmo = tool:GetAttribute("ClipAmmo") or 0
		if clipAmmo <= 0 then
			return
		end
		tool:SetAttribute("ClipAmmo", clipAmmo - 1)
	end

	lastFireTime[player][weaponId] = now

	local ignoreList = { character }
	for _ = 1, weapon.Pellets do
		local pelletDirection = spreadDirection(direction, weapon.Spread)
		local result = fireSingleRay(origin, pelletDirection, ignoreList)
		if result and result.Instance then
			local hitPart = result.Instance
			local model = hitPart:FindFirstAncestorOfClass("Model")
			if isZombieModel(model) then
				local zombieHumanoid = model:FindFirstChildOfClass("Humanoid")
				if zombieHumanoid and zombieHumanoid.Health > 0 then
					local damage = weapon.Damage
					if hitPart.Name == "Head" then
						damage *= HEADSHOT_MULTIPLIER
					end
					model:SetAttribute("LastDamagerUserId", player.UserId)
					zombieHumanoid:TakeDamage(damage)
				end
			end
		end
	end
end

local function handleReload(player, weaponId)
	local weapon = GameConfig.GetWeapon(weaponId)
	local character = player.Character
	if not weapon or not character or weapon.Infinite then
		return
	end
	local tool = findEquippedTool(character, weaponId)
	if not tool then
		return
	end
	local clipAmmo = tool:GetAttribute("ClipAmmo") or 0
	local reserveAmmo = tool:GetAttribute("ReserveAmmo") or 0
	local needed = weapon.ClipSize - clipAmmo
	if needed <= 0 or reserveAmmo <= 0 then
		return
	end
	local amount = math.min(needed, reserveAmmo)
	tool:SetAttribute("ClipAmmo", clipAmmo + amount)
	tool:SetAttribute("ReserveAmmo", reserveAmmo - amount)
end

function WeaponServer.Init()
	Remotes.FireWeapon.OnServerEvent:Connect(handleFireWeapon)
	Remotes.RequestReload.OnServerEvent:Connect(handleReload)

	Players.PlayerRemoving:Connect(function(player)
		lastFireTime[player] = nil
	end)
end

return WeaponServer
