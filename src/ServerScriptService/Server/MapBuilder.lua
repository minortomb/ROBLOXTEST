-- Procedurally blocks out the two areas the prototype needs: a lobby (with
-- a difficulty vote area) and a walled arena with weapon stalls, ammo pads
-- and chokepoint cover, matching design doc section 5 requirements
-- (visible purchase points, evenly distributed ammo, limited attack lanes).
-- Everything is generated in code so the project has no external asset
-- dependencies and can be opened straight from this repository.

local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)

local MapBuilder = {}

local LOBBY_CENTER = Vector3.new(0, 0, 0)
local ARENA_CENTER = Vector3.new(0, 0, 500)

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		p[key] = value
	end
	return p
end

function MapBuilder.BuildAll()
	local data = {
		ArenaPlayerSpawnPoints = {},
		ZombieSpawnPoints = {},
		ShopStalls = {},
		AmmoPads = {},
	}

	----------------------------------------------------------------
	-- Lobby
	----------------------------------------------------------------
	local lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "Lobby"
	lobbyFolder.Parent = workspace

	local lobbyFloor = Instance.new("SpawnLocation")
	lobbyFloor.Name = "LobbyFloor"
	lobbyFloor.Anchored = true
	lobbyFloor.CanCollide = true
	lobbyFloor.Neutral = true
	lobbyFloor.Duration = 0
	lobbyFloor.Size = Vector3.new(60, 2, 60)
	lobbyFloor.Position = LOBBY_CENTER
	lobbyFloor.Color = Color3.fromRGB(120, 120, 130)
	lobbyFloor.Material = Enum.Material.Concrete
	lobbyFloor.Parent = lobbyFolder

	local startStation = part({
		Name = "GameStartStation",
		Size = Vector3.new(6, 4, 1),
		Position = LOBBY_CENTER + Vector3.new(0, 1 + 2, -20),
		Color = Color3.fromRGB(40, 130, 200),
		Material = Enum.Material.Neon,
		Parent = lobbyFolder,
	})
	data.StartStation = startStation

	data.LobbySpawnCFrame = CFrame.new(LOBBY_CENTER + Vector3.new(0, 3, 0))

	----------------------------------------------------------------
	-- Arena shell
	----------------------------------------------------------------
	local arenaFolder = Instance.new("Folder")
	arenaFolder.Name = "Arena"
	arenaFolder.Parent = workspace

	local arenaSize = Vector3.new(140, 2, 160)
	part({
		Name = "ArenaFloor",
		Size = arenaSize,
		Position = ARENA_CENTER,
		Color = Color3.fromRGB(90, 100, 80),
		Material = Enum.Material.Ground,
		Parent = arenaFolder,
	})

	local halfX, halfZ = arenaSize.X / 2, arenaSize.Z / 2
	local wallHeight = 14
	local wallThickness = 2
	local wallColor = Color3.fromRGB(70, 70, 75)

	local function wall(sizeXZ, offset)
		part({
			Name = "ArenaWall",
			Size = Vector3.new(sizeXZ.X, wallHeight, sizeXZ.Z),
			Position = ARENA_CENTER + offset + Vector3.new(0, wallHeight / 2, 0),
			Color = wallColor,
			Material = Enum.Material.Slate,
			Parent = arenaFolder,
		})
	end

	-- Perimeter with gaps at the midpoints of each side for zombie spawns.
	wall(Vector3.new(halfX - 10, wallThickness), Vector3.new(-halfX / 2 - 5, 0, -halfZ))
	wall(Vector3.new(halfX - 10, wallThickness), Vector3.new(halfX / 2 + 5, 0, -halfZ))
	wall(Vector3.new(halfX - 10, wallThickness), Vector3.new(-halfX / 2 - 5, 0, halfZ))
	wall(Vector3.new(halfX - 10, wallThickness), Vector3.new(halfX / 2 + 5, 0, halfZ))
	wall(Vector3.new(wallThickness, halfZ - 10), Vector3.new(-halfX, 0, -halfZ / 2 - 5))
	wall(Vector3.new(wallThickness, halfZ - 10), Vector3.new(-halfX, 0, halfZ / 2 + 5))
	wall(Vector3.new(wallThickness, halfZ - 10), Vector3.new(halfX, 0, -halfZ / 2 - 5))
	wall(Vector3.new(wallThickness, halfZ - 10), Vector3.new(halfX, 0, halfZ / 2 + 5))

	-- Interior chokepoint cover blocks (limited attack lanes, per section 5).
	local coverPositions = {
		Vector3.new(-30, 0, -20),
		Vector3.new(30, 0, -20),
		Vector3.new(-30, 0, 40),
		Vector3.new(30, 0, 40),
	}
	for _, pos in ipairs(coverPositions) do
		part({
			Name = "CoverBlock",
			Size = Vector3.new(8, 5, 3),
			Position = ARENA_CENTER + pos + Vector3.new(0, 2.5, 0),
			Color = Color3.fromRGB(110, 90, 60),
			Material = Enum.Material.WoodPlanks,
			Parent = arenaFolder,
		})
	end

	----------------------------------------------------------------
	-- Player spawn points (defensive huddle near the centre of the arena)
	----------------------------------------------------------------
	local spawnRing = {
		Vector3.new(-4, 0, 0),
		Vector3.new(4, 0, 0),
		Vector3.new(-4, 0, 6),
		Vector3.new(4, 0, 6),
		Vector3.new(-8, 0, 3),
		Vector3.new(8, 0, 3),
		Vector3.new(-4, 0, -6),
		Vector3.new(4, 0, -6),
	}
	for _, offset in ipairs(spawnRing) do
		table.insert(data.ArenaPlayerSpawnPoints, CFrame.new(ARENA_CENTER + offset + Vector3.new(0, 4, 0)))
	end

	----------------------------------------------------------------
	-- Zombie spawn points: just outside each perimeter gap.
	----------------------------------------------------------------
	local zombieOffsets = {
		Vector3.new(0, 0, -halfZ - 5),
		Vector3.new(0, 0, halfZ + 5),
		Vector3.new(-halfX - 5, 0, 0),
		Vector3.new(halfX - 5, 0, 0),
		Vector3.new(-25, 0, -halfZ - 5),
		Vector3.new(25, 0, -halfZ - 5),
		Vector3.new(-25, 0, halfZ + 5),
		Vector3.new(25, 0, halfZ + 5),
	}
	for _, offset in ipairs(zombieOffsets) do
		table.insert(data.ZombieSpawnPoints, ARENA_CENTER + offset + Vector3.new(0, 4, 0))
	end

	----------------------------------------------------------------
	-- Weapon shop stalls: fixed, visible from a distance (Neon markers).
	----------------------------------------------------------------
	local stallLayout = {
		{ WeaponId = "Shotgun", Offset = Vector3.new(-45, 0, -55) },
		{ WeaponId = "SMG", Offset = Vector3.new(45, 0, -55) },
		{ WeaponId = "Sniper", Offset = Vector3.new(0, 0, -65) },
	}
	for _, stallInfo in ipairs(stallLayout) do
		local weapon = GameConfig.GetWeapon(stallInfo.WeaponId)
		local stallPart = part({
			Name = "Shop_" .. stallInfo.WeaponId,
			Size = Vector3.new(5, 6, 2),
			Position = ARENA_CENTER + stallInfo.Offset + Vector3.new(0, 3, 0),
			Color = Color3.fromRGB(200, 170, 40),
			Material = Enum.Material.Neon,
			Parent = arenaFolder,
		})
		stallPart:SetAttribute("WeaponId", weapon.Id)

		local buyPrompt = Instance.new("ProximityPrompt")
		buyPrompt.Name = "BuyPrompt"
		buyPrompt.ActionText = "Купить " .. weapon.Name .. " (" .. weapon.Price .. ")"
		buyPrompt.ObjectText = "Оружейный магазин"
		buyPrompt.HoldDuration = 0.3
		buyPrompt.MaxActivationDistance = 10
		buyPrompt.Parent = stallPart

		local restockPrompt = Instance.new("ProximityPrompt")
		restockPrompt.Name = "RestockPrompt"
		restockPrompt.ActionText = "Купить патроны (" .. weapon.AmmoRestockPrice .. ")"
		restockPrompt.ObjectText = weapon.Name
		restockPrompt.HoldDuration = 0.3
		restockPrompt.MaxActivationDistance = 10
		restockPrompt.UIOffset = Vector2.new(0, 40)
		restockPrompt.Parent = stallPart

		table.insert(data.ShopStalls, {
			WeaponId = weapon.Id,
			Part = stallPart,
			BuyPrompt = buyPrompt,
			RestockPrompt = restockPrompt,
		})
	end

	----------------------------------------------------------------
	-- Ammo pads: free, evenly distributed pickups (section 5 & 9).
	----------------------------------------------------------------
	local padOffsets = {
		Vector3.new(-50, 0, 0),
		Vector3.new(50, 0, 0),
		Vector3.new(-50, 0, 55),
		Vector3.new(50, 0, 55),
	}
	for i, offset in ipairs(padOffsets) do
		local pad = part({
			Name = "AmmoPad" .. i,
			Size = Vector3.new(4, 0.5, 4),
			Position = ARENA_CENTER + offset + Vector3.new(0, 0.25, 0),
			Color = Color3.fromRGB(40, 200, 90),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = arenaFolder,
		})
		table.insert(data.AmmoPads, pad)
	end

	MapBuilder.Data = data
	return data
end

return MapBuilder
