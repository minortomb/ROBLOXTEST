-- Simple chase-and-attack AI loop for one zombie instance. No pathfinding:
-- the arena is an open blockout, so periodic Humanoid:MoveTo toward the
-- nearest living squad member is enough for a prototype. Ranged/DoT/jump
-- behaviours are handled per AttackType from GameConfig.ZombieTypes.

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ZombieAI = {}

local TICK_INTERVAL = 0.4

local function getNearestTarget(root, getAliveTargets)
	local nearest, nearestDist = nil, math.huge
	for _, target in ipairs(getAliveTargets()) do
		local dist = (target.RootPart.Position - root.Position).Magnitude
		if dist < nearestDist then
			nearest, nearestDist = target, dist
		end
	end
	return nearest, nearestDist
end

local function applySplashDamage(position, radius, damage, getAliveTargets)
	for _, target in ipairs(getAliveTargets()) do
		if (target.RootPart.Position - position).Magnitude <= radius then
			target.Humanoid:TakeDamage(damage)
		end
	end
end

local function doRangedAttack(model, root, zombieType, damage, target, getAliveTargets)
	local spit = Instance.new("Part")
	spit.Shape = Enum.PartType.Ball
	spit.Size = Vector3.new(1, 1, 1)
	spit.Color = zombieType.Color
	spit.Material = Enum.Material.Neon
	spit.Anchored = true
	spit.CanCollide = false
	spit.Position = root.Position + Vector3.new(0, 1, 0)
	spit.Parent = workspace

	local targetPosition = target.RootPart.Position
	local distance = (targetPosition - spit.Position).Magnitude
	local travelTime = math.clamp(distance / zombieType.ProjectileSpeed, 0.15, 1.5)

	local tween = TweenService:Create(spit, TweenInfo.new(travelTime, Enum.EasingStyle.Linear), {
		Position = targetPosition + Vector3.new(0, 2, 0),
	})
	tween:Play()
	Debris:AddItem(spit, travelTime + 0.1)

	task.delay(travelTime, function()
		if model.Parent then
			applySplashDamage(targetPosition, zombieType.SplashRadius, damage, getAliveTargets)
		end
	end)
end

local function applyDot(humanoid, dotDamage, dotDuration)
	local ticks = math.max(1, math.floor(dotDuration))
	task.spawn(function()
		for _ = 1, ticks do
			task.wait(1)
			if humanoid.Health <= 0 then
				return
			end
			humanoid:TakeDamage(dotDamage)
		end
	end)
end

function ZombieAI.Start(model, zombieType, getAliveTargets)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	if not humanoid or not root then
		return
	end

	local damage = model:GetAttribute("Damage") or zombieType.Damage
	local lastAttackTime = 0
	local lastJumpTime = 0

	task.spawn(function()
		while model.Parent and humanoid.Health > 0 do
			local target, distance = getNearestTarget(root, getAliveTargets)

			if target then
				local ok = pcall(function()
					humanoid:MoveTo(target.RootPart.Position)
				end)
				if not ok then
					break
				end

				local now = os.clock()

				if zombieType.AttackType == "jump_melee" and now - lastJumpTime >= zombieType.JumpInterval and distance > zombieType.AttackRange then
					lastJumpTime = now
					local direction = (target.RootPart.Position - root.Position)
					direction = Vector3.new(direction.X, 0, direction.Z)
					if direction.Magnitude > 0 then
						direction = direction.Unit
					end
					root.AssemblyLinearVelocity = direction * 24 + zombieType.JumpImpulse
				end

				if distance <= zombieType.AttackRange and now - lastAttackTime >= zombieType.AttackCooldown then
					lastAttackTime = now

					if zombieType.AttackType == "melee" then
						target.Humanoid:TakeDamage(damage)
					elseif zombieType.AttackType == "melee_dot" then
						target.Humanoid:TakeDamage(damage)
						applyDot(target.Humanoid, zombieType.DotDamage, zombieType.DotDuration)
					elseif zombieType.AttackType == "ranged" then
						doRangedAttack(model, root, zombieType, damage, target, getAliveTargets)
					elseif zombieType.AttackType == "jump_melee" then
						target.Humanoid:TakeDamage(damage)
					end
				end
			end

			task.wait(TICK_INTERVAL)
		end
	end)
end

return ZombieAI
