local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)

local WeaponFactory = {}

-- -1 is used as the wire-friendly sentinel for "infinite reserve ammo"
-- (math.huge round-trips awkwardly through some attribute consumers).
WeaponFactory.INFINITE_AMMO = -1

function WeaponFactory.CreateTool(weaponId)
	local weapon = GameConfig.GetWeapon(weaponId)
	assert(weapon, "Unknown weapon id: " .. tostring(weaponId))

	local tool = Instance.new("Tool")
	tool.Name = weapon.Name
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 1, 2)
	handle.Color = Color3.fromRGB(45, 45, 50)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Parent = tool

	tool:SetAttribute("WeaponId", weapon.Id)
	tool:SetAttribute("ClipAmmo", weapon.ClipSize)
	tool:SetAttribute(
		"ReserveAmmo",
		weapon.Infinite and WeaponFactory.INFINITE_AMMO or weapon.MaxReserve
	)

	return tool
end

return WeaponFactory
