-- Weapon stalls and ammo pads (design doc section 9). Purchases run purely
-- through ProximityPrompt.Triggered, which already fires server-side, so no
-- extra RemoteEvent surface is needed for something that spends currency.

local Players = game:GetService("Players")
local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)
local Remotes = require(game:GetService("ReplicatedStorage").Modules.Remotes)
local WeaponFactory = require(script.Parent.WeaponFactory)

local ShopService = {}

local AMMO_PAD_COOLDOWN = 8
local padCooldowns = {} -- [pad][userId] = os.clock()

local function notify(player, text, kind)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

local function findOwnedTool(player, weaponId)
	local character = player.Character
	if character then
		for _, instance in ipairs(character:GetChildren()) do
			if instance:IsA("Tool") and instance:GetAttribute("WeaponId") == weaponId then
				return instance
			end
		end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, instance in ipairs(backpack:GetChildren()) do
			if instance:IsA("Tool") and instance:GetAttribute("WeaponId") == weaponId then
				return instance
			end
		end
	end
	return nil
end

local function handleBuyWeapon(player, weaponId)
	local weapon = GameConfig.GetWeapon(weaponId)
	if not weapon then
		return
	end
	if findOwnedTool(player, weaponId) then
		notify(player, weapon.Name .. " уже куплен", "warning")
		return
	end

	local currency = player:GetAttribute("Currency") or 0
	if currency < weapon.Price then
		notify(player, "Недостаточно валюты", "warning")
		return
	end

	player:SetAttribute("Currency", currency - weapon.Price)

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local tool = WeaponFactory.CreateTool(weaponId)
	tool.Parent = backpack
	notify(player, "Куплено: " .. weapon.Name, "success")
end

local function handleRestockAmmo(player, weaponId)
	local weapon = GameConfig.GetWeapon(weaponId)
	if not weapon or weapon.Infinite then
		return
	end
	local tool = findOwnedTool(player, weaponId)
	if not tool then
		notify(player, "Сначала купите " .. weapon.Name, "warning")
		return
	end

	local reserveAmmo = tool:GetAttribute("ReserveAmmo") or 0
	if reserveAmmo >= weapon.MaxReserve then
		notify(player, "Патроны уже полны", "info")
		return
	end

	local currency = player:GetAttribute("Currency") or 0
	if currency < weapon.AmmoRestockPrice then
		notify(player, "Недостаточно валюты", "warning")
		return
	end

	player:SetAttribute("Currency", currency - weapon.AmmoRestockPrice)
	tool:SetAttribute("ReserveAmmo", weapon.MaxReserve)
	notify(player, "Патроны пополнены: " .. weapon.Name, "success")
end

local function handleAmmoPadTouched(pad, hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	padCooldowns[pad] = padCooldowns[pad] or {}
	local lastTime = padCooldowns[pad][player.UserId] or 0
	if os.clock() - lastTime < AMMO_PAD_COOLDOWN then
		return
	end

	local equippedTool = character:FindFirstChildOfClass("Tool")
	if not equippedTool then
		return
	end
	local weaponId = equippedTool:GetAttribute("WeaponId")
	local weapon = weaponId and GameConfig.GetWeapon(weaponId)
	if not weapon or weapon.Infinite then
		return
	end

	local reserveAmmo = equippedTool:GetAttribute("ReserveAmmo") or 0
	if reserveAmmo >= weapon.MaxReserve then
		return
	end

	padCooldowns[pad][player.UserId] = os.clock()
	equippedTool:SetAttribute("ReserveAmmo", weapon.MaxReserve)
	notify(player, "Патроны пополнены на пункте снабжения", "success")
end

function ShopService.Init(mapData)
	for _, stall in ipairs(mapData.ShopStalls) do
		stall.BuyPrompt.Triggered:Connect(function(player)
			handleBuyWeapon(player, stall.WeaponId)
		end)
		stall.RestockPrompt.Triggered:Connect(function(player)
			handleRestockAmmo(player, stall.WeaponId)
		end)
	end

	for _, pad in ipairs(mapData.AmmoPads) do
		pad.Touched:Connect(function(hit)
			handleAmmoPadTouched(pad, hit)
		end)
	end
end

return ShopService
