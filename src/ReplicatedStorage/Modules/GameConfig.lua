-- Central tuning data for the prototype, mirroring the design document
-- sections 6 (difficulty), 8 (enemies) and 9 (weapons/ammo economy).
-- Numeric values are explicitly placeholders pending playtesting, as the
-- design document itself notes for these tables.

local GameConfig = {}

GameConfig.TotalWaves = 8
GameConfig.TradeWindowSeconds = 25
GameConfig.LobbyCountdownSeconds = 8

-- Section 6: difficulty scaling table.
GameConfig.Difficulties = {
	{
		Id = "Easy",
		Name = "Лёгкий",
		ZombieHealthMult = 1,
		ZombieDamageMult = 1,
		ZombieCountMult = 1,
		RewardMult = 1,
	},
	{
		Id = "Medium",
		Name = "Средний",
		ZombieHealthMult = 1.5,
		ZombieDamageMult = 1.3,
		ZombieCountMult = 1.2,
		RewardMult = 1.5,
	},
	{
		Id = "Hard",
		Name = "Сложный",
		ZombieHealthMult = 2.2,
		ZombieDamageMult = 1.8,
		ZombieCountMult = 1.4,
		RewardMult = 2,
	},
	{
		Id = "Extreme",
		Name = "Экстремальный",
		ZombieHealthMult = 3,
		ZombieDamageMult = 2.5,
		ZombieCountMult = 1.7,
		RewardMult = 3,
	},
}

function GameConfig.GetDifficulty(difficultyId)
	for _, difficulty in ipairs(GameConfig.Difficulties) do
		if difficulty.Id == difficultyId then
			return difficulty
		end
	end
	return GameConfig.Difficulties[1]
end

-- Section 9: weapon categories, prices and damage scale pistol < shotgun <
-- automatic < sniper as recommended in the document.
GameConfig.Weapons = {
	Pistol = {
		Id = "Pistol",
		Name = "Пистолет",
		Category = "Pistol",
		Price = 0,
		Damage = 18,
		FireRate = 0.32,
		Automatic = false,
		Infinite = true,
		ClipSize = 12,
		MaxReserve = math.huge,
		Pellets = 1,
		Spread = 0,
		AmmoRestockPrice = 0,
	},
	Shotgun = {
		Id = "Shotgun",
		Name = "Дробовик",
		Category = "Shotgun",
		Price = 450,
		Damage = 16, -- per pellet
		Pellets = 6,
		Spread = 6,
		FireRate = 0.85,
		Automatic = false,
		Infinite = false,
		ClipSize = 8,
		MaxReserve = 32,
		AmmoRestockPrice = 120,
	},
	SMG = {
		Id = "SMG",
		Name = "Автомат",
		Category = "Automatic",
		Price = 850,
		Damage = 11,
		Pellets = 1,
		Spread = 2.5,
		FireRate = 0.1,
		Automatic = true,
		Infinite = false,
		ClipSize = 30,
		MaxReserve = 150,
		AmmoRestockPrice = 200,
	},
	Sniper = {
		Id = "Sniper",
		Name = "Снайперская винтовка",
		Category = "Sniper",
		Price = 1500,
		Damage = 85,
		Pellets = 1,
		Spread = 0,
		FireRate = 1.15,
		Automatic = false,
		Infinite = false,
		ClipSize = 5,
		MaxReserve = 25,
		AmmoRestockPrice = 250,
	},
}

GameConfig.WeaponShopOrder = { "Pistol", "Shotgun", "SMG", "Sniper" }

function GameConfig.GetWeapon(weaponId)
	return GameConfig.Weapons[weaponId]
end

-- Section 8: enemy roster. AttackType drives behaviour in ZombieAI:
--   "melee"      - contact damage on cooldown
--   "melee_dot"  - contact damage + damage-over-time
--   "ranged"     - lobs a projectile that deals splash damage
--   "jump_melee" - periodically leaps at the target instead of walking
GameConfig.ZombieTypes = {
	Walker = {
		Id = "Walker",
		Name = "Обычный зомби",
		Health = 100,
		Damage = 10,
		WalkSpeed = 8,
		Size = Vector3.new(2, 5, 1),
		Color = Color3.fromRGB(90, 110, 70),
		AttackRange = 5,
		AttackCooldown = 1,
		AttackType = "melee",
		Reward = 15,
	},
	Crawler = {
		Id = "Crawler",
		Name = "Ползающий",
		Health = 70,
		Damage = 8,
		WalkSpeed = 6,
		Size = Vector3.new(2, 2.5, 1.6), -- low profile, smaller target
		Color = Color3.fromRGB(70, 90, 60),
		AttackRange = 4,
		AttackCooldown = 0.9,
		AttackType = "melee",
		Reward = 18,
	},
	Spitter = {
		Id = "Spitter",
		Name = "Плюющийся кислотой",
		Health = 80,
		Damage = 14,
		WalkSpeed = 7,
		Size = Vector3.new(2, 5, 1),
		Color = Color3.fromRGB(120, 170, 40),
		AttackRange = 30,
		AttackCooldown = 2.2,
		AttackType = "ranged",
		ProjectileSpeed = 80,
		SplashRadius = 6,
		Reward = 22,
	},
	Fire = {
		Id = "Fire",
		Name = "Огненный",
		Health = 110,
		Damage = 6,
		WalkSpeed = 7.5,
		Size = Vector3.new(2, 5, 1),
		Color = Color3.fromRGB(200, 80, 30),
		AttackRange = 5,
		AttackCooldown = 1.3,
		AttackType = "melee_dot",
		DotDamage = 4,
		DotDuration = 3,
		Reward = 24,
	},
	Runner = {
		Id = "Runner",
		Name = "Бегающий",
		Health = 65,
		Damage = 9,
		WalkSpeed = 16,
		Size = Vector3.new(1.6, 4.6, 0.9),
		Color = Color3.fromRGB(150, 120, 90),
		AttackRange = 4.5,
		AttackCooldown = 0.8,
		AttackType = "melee",
		Reward = 20,
	},
	Jumper = {
		Id = "Jumper",
		Name = "Прыгающий",
		Health = 75,
		Damage = 12,
		WalkSpeed = 9,
		Size = Vector3.new(2.2, 4.6, 1.2),
		Color = Color3.fromRGB(110, 70, 120),
		AttackRange = 5,
		AttackCooldown = 1.6,
		AttackType = "jump_melee",
		JumpInterval = 2.5,
		JumpImpulse = Vector3.new(0, 38, 0),
		Reward = 21,
	},
	Elite = {
		Id = "Elite",
		Name = "Элитный (танк)",
		Health = 650,
		Damage = 26,
		WalkSpeed = 6,
		Size = Vector3.new(3.4, 7.5, 2),
		Color = Color3.fromRGB(60, 60, 60),
		AttackRange = 6,
		AttackCooldown = 1.4,
		AttackType = "melee",
		Reward = 120,
	},
}

-- Section 7: which enemy types are introduced on which wave, and whether an
-- Elite closes the wave out (final wave recommendation from section 8).
GameConfig.WaveUnlocks = {
	[1] = { "Walker" },
	[2] = { "Walker", "Crawler" },
	[3] = { "Walker", "Crawler", "Spitter" },
	[4] = { "Walker", "Crawler", "Spitter", "Runner" },
	[5] = { "Walker", "Crawler", "Spitter", "Runner", "Fire" },
	[6] = { "Walker", "Crawler", "Spitter", "Runner", "Fire", "Jumper" },
	[7] = { "Walker", "Crawler", "Spitter", "Runner", "Fire", "Jumper" },
	[8] = { "Walker", "Crawler", "Spitter", "Runner", "Fire", "Jumper" },
}

GameConfig.EliteWaves = { [8] = 2, [6] = 1 } -- waveNumber -> elite count

function GameConfig.GetWaveZombieCount(waveNumber, difficulty)
	local base = 6 + (waveNumber - 1) * 3
	return math.floor(base * difficulty.ZombieCountMult + 0.5)
end

function GameConfig.GetWaveCompletionBonus(waveNumber, difficulty)
	return math.floor(50 * waveNumber * difficulty.RewardMult)
end

return GameConfig
