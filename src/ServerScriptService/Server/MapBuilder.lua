-- Procedurally builds the two areas the prototype needs: a lobby and a
-- forest-themed arena (design doc section 5: "Лес" is one of the three
-- base map themes). The arena uses Roblox's real Terrain voxel system for
-- relief (rolling perimeter hills instead of flat walls) plus procedural
-- trees/boulders for decor, so there is still no external asset
-- dependency - everything is generated in code when the server starts.

local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)

local MapBuilder = {}

local LOBBY_CENTER = Vector3.new(0, 0, 0)
local ARENA_CENTER = Vector3.new(0, 0, 500)
-- Gameplay layout (spawns/shops/pads/cover below) is unchanged from the
-- first version; the footprint itself was enlarged so there is a generous
-- buffer of solid ground between the play area and the map's hard edge -
-- a chasing zombie (or a jumping one's velocity impulse) can no longer
-- reach open air by wandering past the perimeter hills.
local ARENA_SIZE = Vector3.new(220, 0, 240) -- Y unused, kept for X/Z footprint math
local HALF_X, HALF_Z = ARENA_SIZE.X / 2, ARENA_SIZE.Z / 2
local HILL_RADIUS = 14
local GROUND_MARGIN = 60 -- solid ground beyond the hill line, before the hard boundary wall
local BOUNDARY_WALL_HEIGHT = 100

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

-- Casts straight down against Terrain only, so trees/rocks/etc. placed
-- earlier in BuildAll never shadow later placements.
local function getGroundY(worldX, worldZ, fallbackY)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { workspace.Terrain }
	local result = workspace:Raycast(Vector3.new(worldX, 300, worldZ), Vector3.new(0, -600, 0), raycastParams)
	if result then
		return result.Position.Y
	end
	return fallbackY or 0
end

local function farEnoughFromAll(candidate, keepClearPoints)
	for _, entry in ipairs(keepClearPoints) do
		if (Vector3.new(candidate.X, 0, candidate.Z) - Vector3.new(entry.Position.X, 0, entry.Position.Z)).Magnitude
			< entry.Radius
		then
			return false
		end
	end
	return true
end

local function createTree(position)
	local model = Instance.new("Model")
	model.Name = "Tree"

	local trunkHeight = 6 + math.random() * 4
	local trunk = part({
		Name = "Trunk",
		Size = Vector3.new(1.1, trunkHeight, 1.1),
		CFrame = CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0)),
		Color = Color3.fromRGB(85, 60, 40),
		Material = Enum.Material.Wood,
		CanCollide = false,
		Parent = model,
	})

	local foliageSize = 7 + math.random() * 4
	part({
		Name = "Foliage",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(foliageSize, foliageSize, foliageSize),
		Position = position + Vector3.new(0, trunkHeight + foliageSize * 0.32, 0),
		Color = Color3.fromRGB(35 + math.random(0, 20), 85 + math.random(0, 25), 35 + math.random(0, 15)),
		Material = Enum.Material.LeafyGrass,
		CanCollide = false,
		Parent = model,
	})

	model.PrimaryPart = trunk
	return model
end

local function createBoulderCluster(position)
	local model = Instance.new("Model")
	model.Name = "Boulders"
	local rockColor = Color3.fromRGB(105, 105, 100)
	local offsets = {
		{ Vector3.new(0, 0, 0), Vector3.new(6, 4.5, 4) },
		{ Vector3.new(3, 0, 2), Vector3.new(4, 3, 3.5) },
		{ Vector3.new(-3, 0, -1.5), Vector3.new(3.5, 3.5, 3) },
	}
	local primary = nil
	for _, entry in ipairs(offsets) do
		local offset, size = entry[1], entry[2]
		local rock = part({
			Name = "Rock",
			Size = size,
			Position = position + offset + Vector3.new(0, size.Y / 2, 0),
			Color = rockColor,
			Material = Enum.Material.Rock,
			Parent = model,
		})
		primary = primary or rock
	end
	model.PrimaryPart = primary
	return model
end

local DIFFICULTY_COLORS = {
	Easy = Color3.fromRGB(70, 200, 90),
	Medium = Color3.fromRGB(230, 195, 40),
	Hard = Color3.fromRGB(230, 130, 30),
	Extreme = Color3.fromRGB(220, 45, 45),
}

local function formatMultiplier(mult)
	return string.format("x%.1f", mult)
end

local function formatCountMultiplier(mult)
	local percent = math.floor((mult - 1) * 100 + 0.5)
	if percent <= 0 then
		return "база"
	end
	return string.format("+%d%%", percent)
end

-- One difficulty-select portal: an arch you walk through, with a floating
-- label showing the name and the exact multipliers from GameConfig so the
-- label can never drift out of sync with the actual numbers. Touching the
-- glowing plane is wired up in GameManager.Init to start a run.
local function buildDifficultyPortal(difficulty, position)
	local color = DIFFICULTY_COLORS[difficulty.Id] or Color3.fromRGB(200, 200, 200)
	local archHeight, archWidth = 10, 6

	local model = Instance.new("Model")
	model.Name = "Portal_" .. difficulty.Id

	local function pillar(offsetX)
		part({
			Name = "Pillar",
			Size = Vector3.new(1, archHeight, 1),
			Position = position + Vector3.new(offsetX, archHeight / 2, 0),
			Color = Color3.fromRGB(55, 55, 60),
			Material = Enum.Material.Metal,
			Parent = model,
		})
	end
	pillar(-archWidth / 2)
	pillar(archWidth / 2)

	part({
		Name = "Lintel",
		Size = Vector3.new(archWidth + 1, 1, 1),
		Position = position + Vector3.new(0, archHeight, 0),
		Color = Color3.fromRGB(55, 55, 60),
		Material = Enum.Material.Metal,
		Parent = model,
	})

	local plane = part({
		Name = "PortalPlane",
		Size = Vector3.new(archWidth - 1, archHeight - 1, 0.3),
		Position = position + Vector3.new(0, (archHeight - 1) / 2, 0),
		Color = color,
		Material = Enum.Material.ForceField,
		Transparency = 0.35,
		CanCollide = false,
		Parent = model,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.new(0, 240, 0, 64)
	billboard.StudsOffset = Vector3.new(0, archHeight + 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Parent = plane

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 30)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 22
	nameLabel.TextColor3 = color
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.Text = difficulty.Name
	nameLabel.Parent = billboard

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Size = UDim2.new(1, 0, 0, 34)
	statsLabel.Position = UDim2.new(0, 0, 0, 28)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextSize = 14
	statsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	statsLabel.TextStrokeTransparency = 0.3
	statsLabel.TextWrapped = true
	statsLabel.Text = string.format(
		"Здоровье зомби %s | Урон %s\nКол-во зомби %s | Награда %s",
		formatMultiplier(difficulty.ZombieHealthMult),
		formatMultiplier(difficulty.ZombieDamageMult),
		formatCountMultiplier(difficulty.ZombieCountMult),
		formatMultiplier(difficulty.RewardMult)
	)
	statsLabel.Parent = billboard

	return model, plane
end

-- Invisible, solid walls right at the outer edge of the ground slab. The
-- hills alone are just gentle mounds (climbable), so this is the hard
-- guarantee that nothing - a chasing zombie, a Jumper's velocity impulse,
-- a player backing up - can ever walk or fly off the map into the void.
local function buildBoundaryWalls(halfX, halfZ)
	local function wallPart(size, position)
		part({
			Name = "BoundaryWall",
			Size = size,
			Position = position,
			Transparency = 1,
			Material = Enum.Material.SmoothPlastic,
			Parent = workspace,
		})
	end

	local midY = BOUNDARY_WALL_HEIGHT / 2 - 10
	wallPart(Vector3.new(halfX * 2 + 4, BOUNDARY_WALL_HEIGHT, 4), ARENA_CENTER + Vector3.new(0, midY, -halfZ - 2))
	wallPart(Vector3.new(halfX * 2 + 4, BOUNDARY_WALL_HEIGHT, 4), ARENA_CENTER + Vector3.new(0, midY, halfZ + 2))
	wallPart(Vector3.new(4, BOUNDARY_WALL_HEIGHT, halfZ * 2 + 4), ARENA_CENTER + Vector3.new(-halfX - 2, midY, 0))
	wallPart(Vector3.new(4, BOUNDARY_WALL_HEIGHT, halfZ * 2 + 4), ARENA_CENTER + Vector3.new(halfX + 2, midY, 0))
end

-- Places overlapping FillBall mounds along a line so the perimeter reads as
-- a rolling hill instead of a hard wall, with gaps left wherever a segment
-- simply isn't drawn (the zombie-lane openings).
local function buildHillLine(fromOffset, toOffset)
	local length = (toOffset - fromOffset).Magnitude
	local steps = math.max(1, math.floor(length / (HILL_RADIUS * 1.1)))
	for i = 0, steps do
		local point = fromOffset:Lerp(toOffset, i / steps)
		local center = ARENA_CENTER + point + Vector3.new(0, -HILL_RADIUS * 0.55, 0)
		workspace.Terrain:FillBall(center, HILL_RADIUS, Enum.Material.Grass)
	end
end

function MapBuilder.BuildAll()
	local data = {
		ArenaPlayerSpawnPoints = {},
		ZombieSpawnPoints = {},
		ShopStalls = {},
		AmmoPads = {},
		Portals = {},
	}

	----------------------------------------------------------------
	-- Lobby (simple room, not part of the map theme)
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

	-- Difficulty-select portals: one per GameConfig.Difficulties entry,
	-- spaced out in a row facing the spawn point. Walking into a portal's
	-- glowing plane starts a run at that difficulty (wired up in
	-- GameManager.Init against the returned Portals list).
	local portalSpacing = 12
	local portalRowStartX = -(#GameConfig.Difficulties - 1) * portalSpacing / 2
	for i, difficulty in ipairs(GameConfig.Difficulties) do
		local position = LOBBY_CENTER + Vector3.new(portalRowStartX + (i - 1) * portalSpacing, 1, -25)
		local portalModel, triggerPlane = buildDifficultyPortal(difficulty, position)
		portalModel.Parent = lobbyFolder
		table.insert(data.Portals, { DifficultyId = difficulty.Id, Part = triggerPlane })
	end

	data.LobbySpawnCFrame = CFrame.new(LOBBY_CENTER + Vector3.new(0, 3, 0))

	----------------------------------------------------------------
	-- Arena terrain: ground slab + rolling perimeter hills with gaps
	-- left open for zombie lanes (same lane layout as the old wall gaps).
	----------------------------------------------------------------
	local arenaFolder = Instance.new("Folder")
	arenaFolder.Name = "Arena"
	arenaFolder.Parent = workspace

	local groundThickness = 8
	local groundHalfX = HALF_X + HILL_RADIUS + GROUND_MARGIN
	local groundHalfZ = HALF_Z + HILL_RADIUS + GROUND_MARGIN
	workspace.Terrain:FillBlock(
		CFrame.new(ARENA_CENTER + Vector3.new(0, -groundThickness / 2, 0)),
		Vector3.new(groundHalfX * 2, groundThickness, groundHalfZ * 2),
		Enum.Material.Grass
	)

	-- North/south hill lines, gap in the middle for the centre lane.
	buildHillLine(Vector3.new(-HALF_X, 0, -HALF_Z), Vector3.new(-10, 0, -HALF_Z))
	buildHillLine(Vector3.new(10, 0, -HALF_Z), Vector3.new(HALF_X, 0, -HALF_Z))
	buildHillLine(Vector3.new(-HALF_X, 0, HALF_Z), Vector3.new(-10, 0, HALF_Z))
	buildHillLine(Vector3.new(10, 0, HALF_Z), Vector3.new(HALF_X, 0, HALF_Z))
	-- East/west hill lines, gap in the middle for the centre lane.
	buildHillLine(Vector3.new(-HALF_X, 0, -HALF_Z), Vector3.new(-HALF_X, 0, -10))
	buildHillLine(Vector3.new(-HALF_X, 0, 10), Vector3.new(-HALF_X, 0, HALF_Z))
	buildHillLine(Vector3.new(HALF_X, 0, -HALF_Z), Vector3.new(HALF_X, 0, -10))
	buildHillLine(Vector3.new(HALF_X, 0, 10), Vector3.new(HALF_X, 0, HALF_Z))

	buildBoundaryWalls(groundHalfX, groundHalfZ)

	local keepClear = {}

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
		local world = ARENA_CENTER + offset
		local groundY = getGroundY(world.X, world.Z)
		table.insert(data.ArenaPlayerSpawnPoints, CFrame.new(world.X, groundY + 4, world.Z))
	end
	table.insert(keepClear, { Position = ARENA_CENTER, Radius = 16 })

	----------------------------------------------------------------
	-- Zombie spawn points: just outside each perimeter gap (unblocked by
	-- hills, matching the lanes left open above).
	----------------------------------------------------------------
	local zombieOffsets = {
		Vector3.new(0, 0, -HALF_Z - 5),
		Vector3.new(0, 0, HALF_Z + 5),
		Vector3.new(-HALF_X - 5, 0, 0),
		Vector3.new(HALF_X + 5, 0, 0),
		Vector3.new(-25, 0, -HALF_Z - 5),
		Vector3.new(25, 0, -HALF_Z - 5),
		Vector3.new(-25, 0, HALF_Z + 5),
		Vector3.new(25, 0, HALF_Z + 5),
	}
	for _, offset in ipairs(zombieOffsets) do
		local world = ARENA_CENTER + offset
		local groundY = getGroundY(world.X, world.Z)
		table.insert(data.ZombieSpawnPoints, Vector3.new(world.X, groundY + 4, world.Z))
		table.insert(keepClear, { Position = world, Radius = 12 })
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
		local world = ARENA_CENTER + stallInfo.Offset
		local groundY = getGroundY(world.X, world.Z)
		local stallSize = Vector3.new(5, 6, 2)

		local stallPart = part({
			Name = "Shop_" .. stallInfo.WeaponId,
			Size = stallSize,
			Position = Vector3.new(world.X, groundY + stallSize.Y / 2, world.Z),
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
		table.insert(keepClear, { Position = world, Radius = 10 })
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
		local world = ARENA_CENTER + offset
		local groundY = getGroundY(world.X, world.Z)
		local pad = part({
			Name = "AmmoPad" .. i,
			Size = Vector3.new(4, 0.5, 4),
			Position = Vector3.new(world.X, groundY + 0.25, world.Z),
			Color = Color3.fromRGB(40, 200, 90),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = arenaFolder,
		})
		table.insert(data.AmmoPads, pad)
		table.insert(keepClear, { Position = world, Radius = 8 })
	end

	----------------------------------------------------------------
	-- Boulder clusters at chokepoints (limited attack lanes, section 5).
	----------------------------------------------------------------
	local coverPositions = {
		Vector3.new(-30, 0, -20),
		Vector3.new(30, 0, -20),
		Vector3.new(-30, 0, 40),
		Vector3.new(30, 0, 40),
	}
	for _, offset in ipairs(coverPositions) do
		local world = ARENA_CENTER + offset
		local groundY = getGroundY(world.X, world.Z)
		local boulders = createBoulderCluster(Vector3.new(world.X, groundY, world.Z))
		boulders.Parent = arenaFolder
		table.insert(keepClear, { Position = world, Radius = 8 })
	end

	----------------------------------------------------------------
	-- Trees: decorative only (non-colliding, so they never trap the
	-- zombies' simple no-pathfinding chase AI), scattered across the
	-- footprint but kept clear of every gameplay-critical point above.
	----------------------------------------------------------------
	local treesFolder = Instance.new("Folder")
	treesFolder.Name = "Trees"
	treesFolder.Parent = arenaFolder

	local treeAttempts, treesPlaced, treeCap = 420, 0, 130
	for _ = 1, treeAttempts do
		local x = ARENA_CENTER.X + (math.random() - 0.5) * (ARENA_SIZE.X + 2 * HILL_RADIUS)
		local z = ARENA_CENTER.Z + (math.random() - 0.5) * (ARENA_SIZE.Z + 2 * HILL_RADIUS)
		if farEnoughFromAll(Vector3.new(x, 0, z), keepClear) then
			local groundY = getGroundY(x, z)
			local tree = createTree(Vector3.new(x, groundY, z))
			tree.Parent = treesFolder
			treesPlaced += 1
		end
		if treesPlaced >= treeCap then
			break
		end
	end

	-- A few trees around the lobby too, purely cosmetic. The lobby floor's
	-- top surface sits at y=1 (Size.Y=2 centered on LOBBY_CENTER.Y=0).
	local lobbyFloorTopY = 1
	for _, offset in ipairs({ Vector3.new(-25, 0, 10), Vector3.new(25, 0, 10), Vector3.new(-28, 0, -20), Vector3.new(28, 0, -20) }) do
		local tree = createTree(LOBBY_CENTER + offset + Vector3.new(0, lobbyFloorTopY, 0))
		tree.Parent = lobbyFolder
	end

	----------------------------------------------------------------
	-- Forest mood lighting (no custom skybox assets needed).
	----------------------------------------------------------------
	local Lighting = game:GetService("Lighting")
	Lighting.Ambient = Color3.fromRGB(60, 70, 55)
	Lighting.OutdoorAmbient = Color3.fromRGB(90, 100, 80)
	Lighting.Brightness = 2.2
	Lighting.FogColor = Color3.fromRGB(150, 165, 140)
	Lighting.FogStart = 120
	Lighting.FogEnd = 420

	MapBuilder.Data = data
	return data
end

return MapBuilder
