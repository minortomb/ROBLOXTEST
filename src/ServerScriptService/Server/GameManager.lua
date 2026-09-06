-- Central session state machine: Lobby -> Countdown -> (Wave <-> Trade)* -> GameOver -> Lobby.
--
-- Simplifications versus the design document, made explicitly for this
-- prototype (see README for the full list):
--   * One server = one squad/session, no public/private lobby matchmaking
--     or TeleportService/Reserved Servers (section 4) - everyone connected
--     to this server is the squad.
--   * Player death is permanent for the rest of the session (one of the
--     three options the design doc leaves open in section 14, question 2):
--     a dead player's Humanoid.Died flips Alive=false and Roblox's default
--     respawn drops them back in the lobby, out of the fight.
--   * Only one map, no day/night modifier (section 5).

local Players = game:GetService("Players")
local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)
local Remotes = require(game:GetService("ReplicatedStorage").Modules.Remotes)
local ZombieSpawner = require(script.Parent.ZombieSpawner)
local WeaponFactory = require(script.Parent.WeaponFactory)
local PlayerDataService = require(script.Parent.PlayerDataService)

local GameManager = {}

local mapData = nil
local sessionState = nil
local startInProgress = false

local function clearBackpackAndTools(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			item:Destroy()
		end
	end
	if player.Character then
		for _, item in ipairs(player.Character:GetChildren()) do
			if item:IsA("Tool") then
				item:Destroy()
			end
		end
	end
end

local function giveStarterPistol(player)
	clearBackpackAndTools(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		local pistol = WeaponFactory.CreateTool("Pistol")
		pistol.Parent = backpack
	end
end

local function teleportPlayerToArena(player, index)
	local character = player.Character or player.CharacterAdded:Wait()
	local spawnPoints = mapData.ArenaPlayerSpawnPoints
	local cframe = spawnPoints[((index - 1) % #spawnPoints) + 1]
	character:PivotTo(cframe)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = 100
		humanoid.Health = humanoid.MaxHealth
	end
end

local function returnPlayerToLobby(player)
	if player.Character then
		player.Character:PivotTo(mapData.LobbySpawnCFrame)
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
	end
end

local function getAliveTargets(squad)
	local targets = {}
	for _, player in ipairs(squad) do
		if player.Parent and player:GetAttribute("Alive") and player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			local root = player.Character:FindFirstChild("HumanoidRootPart")
			if humanoid and root and humanoid.Health > 0 then
				table.insert(targets, { Character = player.Character, Humanoid = humanoid, RootPart = root })
			end
		end
	end
	return targets
end

local function anySquadAlive(squad)
	for _, player in ipairs(squad) do
		if player.Parent and player:GetAttribute("Alive") then
			return true
		end
	end
	return false
end

-- Runs one wave to completion. Returns true if the squad cleared it, false
-- if the whole squad was wiped out first.
local function runWave(waveNumber, difficulty, squad)
	sessionState:SetAttribute("Phase", "Wave")
	sessionState:SetAttribute("CurrentWave", waveNumber)

	local remaining = 0

	local function onZombieDied(model)
		remaining = math.max(remaining - 1, 0)
		sessionState:SetAttribute("ZombiesRemaining", remaining)

		local killerUserId = model:GetAttribute("LastDamagerUserId")
		local reward = model:GetAttribute("Reward") or 0
		if killerUserId then
			local killer = Players:GetPlayerByUserId(killerUserId)
			if killer then
				killer:SetAttribute("Currency", (killer:GetAttribute("Currency") or 0) + reward)
				killer:SetAttribute("SessionXP", (killer:GetAttribute("SessionXP") or 0) + reward)
			end
		end
	end

	remaining = ZombieSpawner.SpawnWave(waveNumber, difficulty, mapData.ZombieSpawnPoints, function()
		return getAliveTargets(squad)
	end, onZombieDied)
	sessionState:SetAttribute("ZombiesRemaining", remaining)

	Remotes.GameStateChanged:FireAllClients("WaveStart", {
		Wave = waveNumber,
		Total = GameConfig.TotalWaves,
		Count = remaining,
	})

	while true do
		task.wait(0.5)
		if remaining <= 0 then
			local bonus = GameConfig.GetWaveCompletionBonus(waveNumber, difficulty)
			for _, player in ipairs(squad) do
				if player.Parent and player:GetAttribute("Alive") then
					player:SetAttribute("Currency", (player:GetAttribute("Currency") or 0) + bonus)
					player:SetAttribute("SessionXP", (player:GetAttribute("SessionXP") or 0) + bonus)
				end
			end
			return true
		end
		if not anySquadAlive(squad) then
			ZombieSpawner.ClearAll()
			return false
		end
	end
end

local function runTradeWindow(waveNumber)
	sessionState:SetAttribute("Phase", "Trade")
	local endsAt = workspace:GetServerTimeNow() + GameConfig.TradeWindowSeconds
	sessionState:SetAttribute("TradeWindowEndsAt", endsAt)
	Remotes.GameStateChanged:FireAllClients("TradeWindow", {
		Seconds = GameConfig.TradeWindowSeconds,
		Wave = waveNumber,
	})
	task.wait(GameConfig.TradeWindowSeconds)
end

local function endSession(won, squad)
	sessionState:SetAttribute("Phase", "GameOver")
	Remotes.GameStateChanged:FireAllClients("GameOver", { Won = won })

	for _, player in ipairs(squad) do
		if player.Parent then
			local sessionCurrency = player:GetAttribute("Currency") or 0
			local sessionXP = player:GetAttribute("SessionXP") or 0
			PlayerDataService.AddSessionRewards(player, sessionCurrency, sessionXP)
		end
	end

	task.wait(10)
	ZombieSpawner.ClearAll()

	for _, player in ipairs(squad) do
		if player.Parent then
			player:SetAttribute("InSession", false)
			clearBackpackAndTools(player)
			returnPlayerToLobby(player)
		end
	end

	sessionState:SetAttribute("Phase", "Lobby")
	sessionState:SetAttribute("CurrentWave", 0)
	sessionState:SetAttribute("ZombiesRemaining", 0)
end

local function runSession(difficulty)
	local squad = Players:GetPlayers()
	if #squad == 0 then
		startInProgress = false
		return
	end

	sessionState:SetAttribute("Phase", "Countdown")
	sessionState:SetAttribute("Difficulty", difficulty.Id)
	Remotes.GameStateChanged:FireAllClients("Countdown", { Seconds = GameConfig.LobbyCountdownSeconds })
	task.wait(GameConfig.LobbyCountdownSeconds)

	local activeSquad = {}
	for _, player in ipairs(squad) do
		if player.Parent then
			table.insert(activeSquad, player)
		end
	end
	squad = activeSquad

	if #squad == 0 then
		sessionState:SetAttribute("Phase", "Lobby")
		startInProgress = false
		return
	end

	for index, player in ipairs(squad) do
		player:SetAttribute("InSession", true)
		player:SetAttribute("Alive", true)
		player:SetAttribute("Currency", 0)
		player:SetAttribute("SessionXP", 0)
		teleportPlayerToArena(player, index)
		giveStarterPistol(player)
	end

	local won = false
	for waveNumber = 1, GameConfig.TotalWaves do
		local cleared = runWave(waveNumber, difficulty, squad)
		if not cleared then
			won = false
			break
		end
		if waveNumber == GameConfig.TotalWaves then
			won = true
		else
			runTradeWindow(waveNumber)
		end
	end

	endSession(won, squad)
	startInProgress = false
end

local function handleStartRequest(player, difficultyId)
	if sessionState:GetAttribute("Phase") ~= "Lobby" then
		Remotes.Notify:FireClient(player, "Сессия уже идёт, дождитесь следующей", "warning")
		return
	end
	if startInProgress then
		return
	end
	startInProgress = true
	local difficulty = GameConfig.GetDifficulty(difficultyId)
	task.spawn(runSession, difficulty)
end

local function onPlayerAdded(player)
	player:SetAttribute("Currency", 0)
	player:SetAttribute("SessionXP", 0)
	player:SetAttribute("Alive", true)
	player:SetAttribute("InSession", false)

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			player:SetAttribute("Alive", false)
		end)
	end)
end

function GameManager.Init(builtMapData)
	mapData = builtMapData

	sessionState = Instance.new("Folder")
	sessionState.Name = "SessionState"
	sessionState:SetAttribute("Phase", "Lobby")
	sessionState:SetAttribute("CurrentWave", 0)
	sessionState:SetAttribute("TotalWaves", GameConfig.TotalWaves)
	sessionState:SetAttribute("ZombiesRemaining", 0)
	sessionState:SetAttribute("TradeWindowEndsAt", 0)
	sessionState:SetAttribute("Difficulty", "")
	sessionState.Parent = game:GetService("ReplicatedStorage")

	Remotes.RequestStartGame.OnServerEvent:Connect(handleStartRequest)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end

return GameManager
