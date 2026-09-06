-- Minimal DataStore-backed meta progression (design doc section 10 & 13):
-- persistent currency and an account level that survive between sessions,
-- separate from the in-session currency that resets every match.
-- All DataStore calls are pcall-wrapped: Studio without API access enabled,
-- or a genuine outage, degrades to in-memory-only progress instead of
-- erroring the whole server.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local PlayerDataService = {}

local store = DataStoreService:GetDataStore("PlayerMeta_v1")
local cache = {} -- [userId] = { MetaCurrency, AccountLevel, TotalXP }
local warnedOnce = false

local function computeLevel(totalXP)
	return 1 + math.floor(totalXP / 500)
end

local function applyAttributes(player, data)
	player:SetAttribute("MetaCurrency", data.MetaCurrency)
	player:SetAttribute("AccountLevel", data.AccountLevel)
	player:SetAttribute("TotalXP", data.TotalXP)
end

function PlayerDataService.Load(player)
	local key = "Player_" .. player.UserId
	local data = { MetaCurrency = 0, AccountLevel = 1, TotalXP = 0 }

	local ok, result = pcall(function()
		return store:GetAsync(key)
	end)

	if ok and result then
		data = result
	elseif not ok and not warnedOnce then
		warnedOnce = true
		warn("PlayerDataService: DataStore unavailable, running with in-memory progress only (" .. tostring(result) .. ")")
	end

	cache[player.UserId] = data
	applyAttributes(player, data)
end

function PlayerDataService.Save(player)
	local data = cache[player.UserId]
	if not data then
		return
	end
	local key = "Player_" .. player.UserId
	pcall(function()
		store:SetAsync(key, data)
	end)
end

-- sessionCurrency/sessionXP are the totals earned in the match just played;
-- a portion of the session currency carries over as persistent currency so
-- spending it all in-session doesn't erase all progress.
function PlayerDataService.AddSessionRewards(player, sessionCurrency, sessionXP)
	local data = cache[player.UserId]
	if not data then
		return
	end
	data.MetaCurrency += math.floor(sessionCurrency * 0.2)
	data.TotalXP += sessionXP
	data.AccountLevel = computeLevel(data.TotalXP)
	applyAttributes(player, data)
end

function PlayerDataService.Init()
	Players.PlayerAdded:Connect(PlayerDataService.Load)
	Players.PlayerRemoving:Connect(PlayerDataService.Save)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(PlayerDataService.Load, player)
	end

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			PlayerDataService.Save(player)
		end
	end)
end

return PlayerDataService
