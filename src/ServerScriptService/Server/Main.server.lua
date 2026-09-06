-- Server entry point: builds the world, then brings the game systems up in
-- dependency order.

local MapBuilder = require(script.Parent.MapBuilder)
local WeaponServer = require(script.Parent.WeaponServer)
local ShopService = require(script.Parent.ShopService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local GameManager = require(script.Parent.GameManager)

local mapData = MapBuilder.BuildAll()

PlayerDataService.Init()
WeaponServer.Init()
ShopService.Init(mapData)
GameManager.Init(mapData)

print("[ZombieWaveShooterPrototype] Server systems initialized.")
