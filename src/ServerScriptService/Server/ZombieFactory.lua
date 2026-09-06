-- Builds a minimal blocky NPC rig for a zombie type. No external assets are
-- used: a single rigid HumanoidRootPart carries a Humanoid so pathing,
-- health, and Humanoid.Died all work normally, plus a welded Head part for
-- a small headshot-damage bonus in WeaponServer.

local PhysicsService = game:GetService("PhysicsService")

local ZombieFactory = {}

local COLLISION_GROUP = "Zombies"
pcall(function()
	PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)
end)

function ZombieFactory.Create(zombieType, difficulty)
	local model = Instance.new("Model")
	model.Name = zombieType.Id

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = zombieType.Size
	root.Color = zombieType.Color
	root.Material = Enum.Material.SmoothPlastic
	root.Anchored = false
	root.CanCollide = true
	root.CollisionGroup = COLLISION_GROUP
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(zombieType.Size.X * 0.8, zombieType.Size.X * 0.8, zombieType.Size.X * 0.8)
	head.Color = zombieType.Color
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = false
	head.CanCollide = false
	head.Position = root.Position + Vector3.new(0, zombieType.Size.Y / 2 + head.Size.Y / 2, 0)
	head.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.MaxHealth = zombieType.Health * difficulty.ZombieHealthMult
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = zombieType.WalkSpeed
	humanoid.HipHeight = 0
	humanoid.DisplayName = zombieType.Name
	humanoid.BreakJointsOnDeath = true
	humanoid.Parent = model

	model.PrimaryPart = root
	model:SetAttribute("ZombieType", zombieType.Id)
	model:SetAttribute("Damage", zombieType.Damage * difficulty.ZombieDamageMult)
	model:SetAttribute("Reward", math.floor(zombieType.Reward * difficulty.RewardMult))

	return model
end

return ZombieFactory
