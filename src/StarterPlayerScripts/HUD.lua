-- Builds and drives all prototype UI: the HUD bar, a lobby hint (actual
-- difficulty selection happens via world portals - see MapBuilder.lua),
-- trade-window/countdown banners, game-over summary and toast
-- notifications. Everything is created at runtime with Instance.new so the
-- project has no external UI assets to ship alongside the code.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local Remotes = require(ReplicatedStorage.Modules.Remotes)

local LocalPlayer = Players.LocalPlayer

local HUD = {}

local function create(className, props)
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		instance[key] = value
	end
	return instance
end

function HUD.Init()
	local sessionState = ReplicatedStorage:WaitForChild("SessionState")

	local screenGui = create("ScreenGui", {
		Name = "GameHUD",
		ResetOnSpawn = false,
		Parent = LocalPlayer:WaitForChild("PlayerGui"),
	})

	----------------------------------------------------------------
	-- Top HUD bar (health / ammo / currency / wave)
	----------------------------------------------------------------
	local topBar = create("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundTransparency = 1,
		Parent = screenGui,
	})

	local function statLabel(name, position, defaultText)
		return create("TextLabel", {
			Name = name,
			Size = UDim2.new(0, 220, 0, 26),
			Position = position,
			BackgroundColor3 = Color3.fromRGB(20, 20, 25),
			BackgroundTransparency = 0.35,
			TextColor3 = Color3.fromRGB(240, 240, 240),
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = defaultText,
			Parent = topBar,
		})
	end

	local healthLabel = statLabel("Health", UDim2.new(0, 12, 0, 8), "Здоровье: 100")
	local ammoLabel = statLabel("Ammo", UDim2.new(0, 12, 0, 38), "Патроны: -")
	local currencyLabel = statLabel("Currency", UDim2.new(1, -232, 0, 8), "Валюта: 0")
	local waveLabel = statLabel("Wave", UDim2.new(1, -232, 0, 38), "Волна: -/-")
	waveLabel.TextXAlignment = Enum.TextXAlignment.Right
	currencyLabel.TextXAlignment = Enum.TextXAlignment.Right

	local zombiesLabel = create("TextLabel", {
		Name = "Zombies",
		Size = UDim2.new(0, 260, 0, 26),
		Position = UDim2.new(0.5, -130, 0, 8),
		BackgroundColor3 = Color3.fromRGB(20, 20, 25),
		BackgroundTransparency = 0.35,
		TextColor3 = Color3.fromRGB(255, 200, 120),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		Text = "Осталось зомби: 0",
		Parent = topBar,
	})

	local bannerLabel = create("TextLabel", {
		Name = "Banner",
		Size = UDim2.new(0, 420, 0, 50),
		Position = UDim2.new(0.5, -210, 0, 70),
		BackgroundColor3 = Color3.fromRGB(15, 15, 20),
		BackgroundTransparency = 0.25,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		Visible = false,
		Text = "",
		Parent = screenGui,
	})

	----------------------------------------------------------------
	-- Lobby hint (difficulty is chosen by walking into one of the
	-- portals built in the lobby - see MapBuilder.lua)
	----------------------------------------------------------------
	local lobbyHintLabel = create("TextLabel", {
		Name = "LobbyHint",
		Size = UDim2.new(0, 460, 0, 34),
		Position = UDim2.new(0.5, -230, 1, -90),
		BackgroundColor3 = Color3.fromRGB(15, 15, 20),
		BackgroundTransparency = 0.3,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		Visible = true,
		Text = "Войдите в портал нужной сложности, чтобы начать игру",
		Parent = screenGui,
	})

	----------------------------------------------------------------
	-- Game-over panel
	----------------------------------------------------------------
	local gameOverPanel = create("Frame", {
		Name = "GameOverPanel",
		Size = UDim2.new(0, 360, 0, 160),
		Position = UDim2.new(0.5, -180, 0.5, -80),
		BackgroundColor3 = Color3.fromRGB(20, 20, 28),
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = screenGui,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = gameOverPanel })

	local gameOverTitle = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Text = "",
		Parent = gameOverPanel,
	})
	local gameOverDetails = create("TextLabel", {
		Size = UDim2.new(1, -24, 0, 80),
		Position = UDim2.new(0, 12, 0, 50),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(220, 220, 220),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		Parent = gameOverPanel,
	})

	----------------------------------------------------------------
	-- Toast notifications
	----------------------------------------------------------------
	local toastLabel = create("TextLabel", {
		Name = "Toast",
		Size = UDim2.new(0, 380, 0, 30),
		Position = UDim2.new(0.5, -190, 1, -80),
		BackgroundColor3 = Color3.fromRGB(20, 20, 25),
		BackgroundTransparency = 0.3,
		Font = Enum.Font.Gotham,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Visible = false,
		Text = "",
		Parent = screenGui,
	})

	local toastColors = {
		info = Color3.fromRGB(255, 255, 255),
		success = Color3.fromRGB(140, 230, 140),
		warning = Color3.fromRGB(255, 170, 90),
	}

	Remotes.Notify.OnClientEvent:Connect(function(text, kind)
		toastLabel.Text = text
		toastLabel.TextColor3 = toastColors[kind] or toastColors.info
		toastLabel.Visible = true
		task.delay(3, function()
			toastLabel.Visible = false
		end)
	end)

	----------------------------------------------------------------
	-- Phase-driven panel visibility
	----------------------------------------------------------------
	local function updatePanelsForPhase(phase)
		lobbyHintLabel.Visible = (phase == "Lobby")
		gameOverPanel.Visible = (phase == "GameOver")
		if phase ~= "Trade" and phase ~= "Countdown" then
			bannerLabel.Visible = false
		end
	end

	sessionState:GetAttributeChangedSignal("Phase"):Connect(function()
		updatePanelsForPhase(sessionState:GetAttribute("Phase"))
	end)
	updatePanelsForPhase(sessionState:GetAttribute("Phase"))

	-- Countdown/Trade/GameOver banners are live countdowns driven off synced
	-- server time in the Heartbeat loop below; these handlers only flip
	-- visibility immediately and (for WaveStart, which isn't a countdown)
	-- set the one-shot message text.
	Remotes.GameStateChanged.OnClientEvent:Connect(function(kind, payload)
		if kind == "Countdown" or kind == "TradeWindow" then
			bannerLabel.Visible = true
		elseif kind == "WaveStart" then
			bannerLabel.Visible = true
			bannerLabel.Text = string.format("Волна %d из %d началась!", payload.Wave, payload.Total)
			task.delay(3, function()
				if bannerLabel.Text:find("Волна") then
					bannerLabel.Visible = false
				end
			end)
		elseif kind == "GameOver" then
			gameOverTitle.Text = payload.Won and "Победа!" or "Поражение"
			gameOverTitle.TextColor3 = payload.Won and Color3.fromRGB(140, 230, 140)
				or Color3.fromRGB(230, 90, 90)
		end
	end)

	----------------------------------------------------------------
	-- Continuously updated readouts
	----------------------------------------------------------------
	local function getEquippedTool()
		local character = LocalPlayer.Character
		return character and character:FindFirstChildOfClass("Tool")
	end

	local updateAccumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		updateAccumulator += dt
		if updateAccumulator < 0.1 then
			return
		end
		updateAccumulator = 0

		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			healthLabel.Text = string.format(
				"Здоровье: %d/%d",
				math.max(math.floor(humanoid.Health + 0.5), 0),
				math.floor(humanoid.MaxHealth + 0.5)
			)
		end

		local tool = getEquippedTool()
		if tool then
			local weapon = GameConfig.GetWeapon(tool:GetAttribute("WeaponId"))
			local clip = tool:GetAttribute("ClipAmmo") or 0
			local reserve = tool:GetAttribute("ReserveAmmo") or 0
			if weapon and weapon.Infinite then
				ammoLabel.Text = string.format("Патроны: %s (∞)", weapon.Name)
			else
				local reserveText = (reserve < 0) and "∞" or tostring(reserve)
				ammoLabel.Text = string.format("Патроны: %d / %s", clip, reserveText)
			end
		else
			ammoLabel.Text = "Патроны: оружие не выбрано"
		end

		currencyLabel.Text = string.format("Валюта: %d", LocalPlayer:GetAttribute("Currency") or 0)

		local currentWave = sessionState:GetAttribute("CurrentWave") or 0
		local totalWaves = sessionState:GetAttribute("TotalWaves") or GameConfig.TotalWaves
		waveLabel.Text = string.format("Волна: %d/%d", currentWave, totalWaves)
		zombiesLabel.Text = string.format("Осталось зомби: %d", sessionState:GetAttribute("ZombiesRemaining") or 0)

		local phase = sessionState:GetAttribute("Phase")
		local now = workspace:GetServerTimeNow()

		if phase == "Trade" then
			local endsAt = sessionState:GetAttribute("TradeWindowEndsAt") or 0
			local secondsLeft = math.max(0, math.ceil(endsAt - now))
			bannerLabel.Visible = true
			bannerLabel.Text = string.format("Торговое окно: %d сек. до следующей волны", secondsLeft)
		elseif phase == "Countdown" then
			local endsAt = sessionState:GetAttribute("CountdownEndsAt") or 0
			local secondsLeft = math.max(0, math.ceil(endsAt - now))
			bannerLabel.Visible = true
			bannerLabel.Text = string.format("Игра начнётся через %d сек.", secondsLeft)
		elseif phase == "GameOver" then
			local endsAt = sessionState:GetAttribute("GameOverReturnAt") or 0
			local secondsLeft = math.max(0, math.ceil(endsAt - now))
			gameOverDetails.Text = string.format(
				"Заработано валюты за сессию: %d\nОпыт за сессию: %d\nВозврат в лобби через %d сек...",
				LocalPlayer:GetAttribute("Currency") or 0,
				LocalPlayer:GetAttribute("SessionXP") or 0,
				secondsLeft
			)
		end
	end)
end

return HUD
