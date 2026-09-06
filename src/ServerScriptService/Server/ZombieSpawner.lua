local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)
local ZombieFactory = require(script.Parent.ZombieFactory)
local ZombieAI = require(script.Parent.ZombieAI)

local ZombieSpawner = {}

local zombiesFolder = Instance.new("Folder")
zombiesFolder.Name = "Zombies"
zombiesFolder.Parent = workspace

local SPAWN_STAGGER = 0.6

local function cleanUpAfterDeath(model)
	task.delay(4, function()
		if model and model.Parent then
			model:Destroy()
		end
	end)
end

-- Builds the list of zombie type ids to spawn this wave (regular mix plus
-- any Elite bosses called for by GameConfig.EliteWaves), then spawns them
-- staggered over time so the arena doesn't get a single instant surge.
-- onZombieDied(model) is invoked once per death so the caller can award
-- currency/XP and decrement its own remaining-zombie counter.
function ZombieSpawner.SpawnWave(waveNumber, difficulty, spawnPoints, getAliveTargets, onZombieDied)
	local unlockedTypes = GameConfig.WaveUnlocks[waveNumber] or GameConfig.WaveUnlocks[1]
	local regularCount = GameConfig.GetWaveZombieCount(waveNumber, difficulty)
	local eliteCount = GameConfig.EliteWaves[waveNumber] or 0

	local spawnList = {}
	for i = 1, regularCount do
		local typeId = unlockedTypes[((i - 1) % #unlockedTypes) + 1]
		table.insert(spawnList, typeId)
	end
	for _ = 1, eliteCount do
		table.insert(spawnList, "Elite")
	end

	-- Shuffle so Elites/late-unlocked types aren't all bunched at the end.
	for i = #spawnList, 2, -1 do
		local j = math.random(i)
		spawnList[i], spawnList[j] = spawnList[j], spawnList[i]
	end

	local totalCount = #spawnList

	task.spawn(function()
		for _, typeId in ipairs(spawnList) do
			local zombieType = GameConfig.ZombieTypes[typeId]
			local spawnPoint = spawnPoints[math.random(#spawnPoints)]

			local model = ZombieFactory.Create(zombieType, difficulty)
			model:PivotTo(CFrame.new(spawnPoint))
			model.Parent = zombiesFolder

			local humanoid = model:FindFirstChildOfClass("Humanoid")
			humanoid.Died:Connect(function()
				onZombieDied(model)
				cleanUpAfterDeath(model)
			end)

			ZombieAI.Start(model, zombieType, getAliveTargets)

			task.wait(SPAWN_STAGGER)
		end
	end)

	return totalCount
end

function ZombieSpawner.ClearAll()
	for _, model in ipairs(zombiesFolder:GetChildren()) do
		model:Destroy()
	end
end

return ZombieSpawner
