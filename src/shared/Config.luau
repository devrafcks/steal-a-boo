--[[
	Config.luau — O ÚNICO arquivo que você precisa editar.

	- IDs de Dev Products e Gamepasses começam em 0.
	  ID 0 = item aparece na loja como "em breve" e NUNCA chama o prompt de compra.
	- Depois de criar cada item no Creator Dashboard (mesmo nome e preço daqui),
	  cole o ID no campo `id`.
	- Todo o resto (balance, Boos, zonas, poderes) também é lido só daqui.
	- A tabela é congelada no fim do arquivo: ninguém consegue alterá-la em runtime.
]]

local Config = {
	GameName = "Steal a Boo!",
	PlaceVersionNote = "MVP",

	DataStore = {
		ProfileStoreName = "StealABoo_Player_v1", -- mude o sufixo se quiser resetar o save de todo mundo
		OrderedCash = "StealABoo_CashAllTime_v1",
		OrderedRebirths = "StealABoo_Rebirths_v1",
		PurchaseIdMemoryDays = 45, -- por quantos dias lembramos de um PurchaseId já entregue
		PurchaseIdMaxEntries = 200,
		LeaderboardPushSeconds = 120, -- grava no OrderedDataStore a cada N segundos
		LeaderboardRefreshSeconds = 60, -- relê o top 10 a cada N segundos
	},

	World = {
		MaxPlayersPlotCount = 8, -- 8 plots no mapa
		PlotSize = Vector3.new(48, 16, 48),
		PlazaRadius = 46, -- praça central = zona neutra (sem poderes, sem sustos)
		-- Regra do portão (decisão de design, ver README):
		--   o portão começa ABERTO (base invadível, luz vermelha).
		--   o dono pode TRANCAR por GateLockSeconds (luz verde, ninguém de fora entra/rouba).
		--   depois que destranca, fica aberto pelo menos GateOpenSeconds antes de poder trancar de novo.
		GateLockSeconds = 40,
		GateOpenSeconds = 20,
		GateCooldownSeconds = 60, -- = GateLockSeconds + GateOpenSeconds (só informativo/HUD)
		StealCarrySpeedPenalty = 0.75,
		StealRange = 8,
		CaptureRange = 10,
		TrainRange = 8,
		SafeSpawnSeconds = 4, -- depois de nascer, ninguém te acerta poder/susto
		NewPlayerProtectSeconds = 120, -- novato (1ª sessão) não pode ser roubado nos 2 primeiros minutos
		DroppedBooSeconds = 8, -- Boo derrubado fica no chão por 8s
		MaxInteractDistance = 20, -- qualquer ação a mais de 20 studs é ignorada (anti-exploit)
	},

	Economy = {
		StartingCash = 50,
		IncomeTickSeconds = 1,
		TrainingCashCostBase = 10,
		TrainingCostGrowth = 1.06, -- custo = base * growth ^ (treinos já feitos naquele status)
		SpeedPerTrain = 0.25,
		ThrowPerTrain = 0.25,
		MaxSpeed = 32, -- WalkSpeed máximo vindo do treino
		MaxThrow = 40,
		BaseWalkSpeed = 16,
		ThrowRangeBonusPerPoint = 0.2, -- Throw Power aumenta o alcance da captura
		ThrowRangeBonusMax = 8,
		MaxInventory = 30, -- Boos guardados (fora da base)
		SellMultiplier = 20, -- vender um Boo = incomePerSec * 20
		StarterBoo = "MarshBoo", -- todo jogador novo ganha 1 para começar
	},

	Carousel = { -- carrossel da praça: compra um Boo surpresa com Cash
		Price = 150,
		PriceGrowthPerRebirth = 1.5,
		Zone = "Fairground",
		LuckBias = 0.15,
	},

	Rebirth = {
		CashRequiredBase = 10000,
		CashRequiredGrowth = 1.8,
		IncomeMultiplierPerRebirth = 0.25, -- +25% por rebirth
		KeepRarityAtOrAbove = "Epic", -- Boos Epic ou melhores ficam depois do rebirth
	},

	Daily = {
		StreakMax = 7,
		Rewards = { 50, 100, 200, 350, 500, 800, 1500 }, -- cash por dia da sequência
		StreakBonusItemDay7 = "LuckyTicket", -- dia 7 = +1 Super Lucky Capture
	},

	Plot = {
		-- Térreo: 12 slots (6 livres + 4 do passe ExtraSlots + 2 do passe VIP)
		GroundSlots = 12,
		BaseGroundSlots = 6,
		ExtraSlotsPass = 4, -- gamepass ExtraSlots (slots 7 a 10 do térreo)
		VIPSlots = 2, -- gamepass VIP (slots 11 e 12 do térreo)
		-- Andares de cima: comprados com Cash no painel Base (8 slots cada)
		FloorSlots = 8,
		FloorHeight = 14,
		Floors = {
			{ name = "Térreo", cost = 0 },
			{ name = "2º andar", cost = 2500 },
			{ name = "3º andar", cost = 40000 },
			{ name = "4º andar", cost = 500000 },
		},
		MaxSlots = 36, -- 12 + 8 + 8 + 8
	},

	-- Cofre e esteira de coleta: a renda dos Boos cai no cofre da base.
	-- Pise na esteira de coleta (perto do seu spawn) para passar o cofre para o seu Cash.
	Vault = {
		CollectRadius = 5,
	},

	-- Gamepasses (permanentes). IDs começam em 0.
	GamePasses = {
		DoubleCash = {
			id = 0,
			price = 99,
			name = "2x Cash",
			icon = "💰",
			desc = "Sua base gera o dobro de Cash para sempre.",
		},
		DoubleTraining = {
			id = 0,
			price = 149,
			name = "2x Training",
			icon = "💪",
			desc = "Treino rende o dobro de Speed e Throw Power.",
		},
		VIP = {
			id = 0,
			price = 249,
			name = "VIP",
			icon = "👑",
			desc = "Tag VIP, aura, +10% Cash e +2 slots no térreo.",
		},
		ExtraSlots = {
			id = 0,
			price = 199,
			name = "+4 Base Slots",
			icon = "🏠",
			desc = "Quatro slots extras permanentes no térreo.",
		},
	},

	-- Dev Products (consumíveis). IDs começam em 0.
	-- kind diz o que o ProcessReceipt entrega:
	--   ServerLuck (mult, duration) | PersonalCash2x (duration) | LuckyCaptures (amount)
	--   Consumable (item, amount)   | Cash (amount) | IncomeBoost (mult, duration)
	Products = {
		-- Esteiras pagas da base: multiplicam a renda dos Boos por pouco tempo
		Belt2x = {
			id = 0,
			price = 15,
			name = "Esteira 2x (2 min)",
			tab = "Boosts",
			icon = "⏩",
			kind = "IncomeBoost",
			mult = 2,
			duration = 120,
			desc = "Renda dos seus Boos em dobro por 2 min.",
		},
		Belt3x = {
			id = 0,
			price = 25,
			name = "Esteira 3x (2 min)",
			tab = "Boosts",
			icon = "⏩",
			kind = "IncomeBoost",
			mult = 3,
			duration = 120,
			desc = "Renda triplicada por 2 min.",
		},
		Belt4x = {
			id = 0,
			price = 39,
			name = "Esteira 4x (2 min)",
			tab = "Boosts",
			icon = "🚀",
			kind = "IncomeBoost",
			mult = 4,
			duration = 120,
			desc = "Renda QUADRUPLICADA por 2 min!",
		},
		-- Sorte do servidor (15 min, todo mundo vê o banner)
		Luck2x15 = {
			id = 0,
			price = 19,
			name = "Server Luck 2x (15 min)",
			tab = "Boosts",
			icon = "🍀",
			kind = "ServerLuck",
			mult = 2,
			duration = 900,
			desc = "Dobra a sorte de TODO o servidor.",
		},
		Luck4x15 = {
			id = 0,
			price = 39,
			name = "Server Luck 4x (15 min)",
			tab = "Boosts",
			icon = "🍀",
			kind = "ServerLuck",
			mult = 4,
			duration = 900,
			desc = "4x sorte para o servidor inteiro.",
		},
		Luck8x15 = {
			id = 0,
			price = 79,
			name = "Server Luck 8x (15 min)",
			tab = "Boosts",
			icon = "🌈",
			kind = "ServerLuck",
			mult = 8,
			duration = 900,
			desc = "8x sorte! Todo mundo vai te agradecer.",
		},
		-- Boosts pessoais
		Cash2x15 = {
			id = 0,
			price = 49,
			name = "2x Cash pessoal (15 min)",
			tab = "Boosts",
			icon = "💸",
			kind = "PersonalCash2x",
			duration = 900,
			desc = "Sua base rende o dobro por 15 min.",
		},
		LuckyThrows5 = {
			id = 0,
			price = 39,
			name = "5 Super Lucky Captures",
			tab = "Boosts",
			icon = "🎯",
			kind = "LuckyCaptures",
			amount = 5,
			desc = "As próximas 5 capturas puxam raridade alta.",
		},
		LuckyThrows10 = {
			id = 0,
			price = 69,
			name = "10 Super Lucky Captures",
			tab = "Boosts",
			icon = "🎯",
			kind = "LuckyCaptures",
			amount = 10,
			desc = "10 capturas com sorte turbinada.",
		},
		-- Poderzinhos
		SpeedRush3 = {
			id = 0,
			price = 19,
			name = "Speed Rush (3 usos)",
			tab = "Poderes",
			icon = "⚡",
			kind = "Consumable",
			item = "SpeedRush",
			amount = 3,
			desc = "Corrida turbo por 8s.",
		},
		Invis1 = {
			id = 0,
			price = 29,
			name = "Invisibilidade (1 uso, 6s)",
			tab = "Poderes",
			icon = "🫥",
			kind = "Consumable",
			item = "Invis",
			amount = 1,
			desc = "Some por 6s (não dá para roubar invisível).",
		},
		SuperJump3 = {
			id = 0,
			price = 19,
			name = "Super Jump (3 usos)",
			tab = "Poderes",
			icon = "🦘",
			kind = "Consumable",
			item = "SuperJump",
			amount = 3,
			desc = "Pulo gigante por 6s.",
		},
		Slap3 = {
			id = 0,
			price = 25,
			name = "Boo Slap (3 usos)",
			tab = "Poderes",
			icon = "🖐️",
			kind = "Consumable",
			item = "Slap",
			amount = 3,
			desc = "Empurra quem está perto e derruba o Boo roubado.",
		},
		Freeze1 = {
			id = 0,
			price = 49,
			name = "Freeze (1 uso, 3s)",
			tab = "Poderes",
			icon = "🧊",
			kind = "Consumable",
			item = "Freeze",
			amount = 1,
			desc = "Congela o ladrão mais perto por 3s.",
		},
		-- Sustos cômicos
		ScareClassic3 = {
			id = 0,
			price = 19,
			name = "Susto Clássico (3 usos)",
			tab = "Sustos",
			icon = "👻",
			kind = "Consumable",
			item = "ScareClassic",
			amount = 3,
			desc = "BOO! fofo no jogador mais perto.",
		},
		ScareParty1 = {
			id = 0,
			price = 39,
			name = "Susto Festa (1 uso, área)",
			tab = "Sustos",
			icon = "🎉",
			kind = "Consumable",
			item = "ScareParty",
			amount = 1,
			desc = "Assusta todo mundo em volta de você.",
		},
		DecoyBoo1 = {
			id = 0,
			price = 29,
			name = "Boo Isca (1 uso)",
			tab = "Sustos",
			icon = "🎭",
			kind = "Consumable",
			item = "DecoyBoo",
			amount = 1,
			desc = "Um Boo falso na sua base. Ladrão leva só fumaça.",
		},
		BaseAlarm1 = {
			id = 0,
			price = 25,
			name = "Alarme da Base (1 uso, 60s)",
			tab = "Sustos",
			icon = "🚨",
			kind = "Consumable",
			item = "BaseAlarm",
			amount = 1,
			desc = "Sirene boba quando alguém entra na base.",
		},
		-- Cash packs
		CashS = {
			id = 0,
			price = 29,
			name = "Saco de Cash",
			tab = "Cash",
			icon = "💵",
			kind = "Cash",
			amount = 1500,
			desc = "+1.500 Cash",
		},
		CashM = {
			id = 0,
			price = 79,
			name = "Baú de Cash",
			tab = "Cash",
			icon = "💰",
			kind = "Cash",
			amount = 6000,
			desc = "+6.000 Cash",
		},
		CashL = {
			id = 0,
			price = 149,
			name = "Cofre de Cash",
			tab = "Cash",
			icon = "🏦",
			kind = "Cash",
			amount = 15000,
			desc = "+15.000 Cash",
		},
	},

	-- Ordem e rótulos da hotbar (teclas 1..9)
	Consumables = {
		{ key = "SpeedRush", label = "Speed", icon = "⚡", type = "Power" },
		{ key = "SuperJump", label = "Pulo", icon = "🦘", type = "Power" },
		{ key = "Invis", label = "Invis", icon = "🫥", type = "Power" },
		{ key = "Slap", label = "Slap", icon = "🖐️", type = "Power" },
		{ key = "Freeze", label = "Freeze", icon = "🧊", type = "Power" },
		{ key = "ScareClassic", label = "Susto", icon = "👻", type = "Scare" },
		{ key = "ScareParty", label = "Festa", icon = "🎉", type = "Scare" },
		{ key = "DecoyBoo", label = "Isca", icon = "🎭", type = "Power" },
		{ key = "BaseAlarm", label = "Alarme", icon = "🚨", type = "Power" },
	},

	Powers = {
		SpeedRush = { walkSpeed = 28, duration = 8, cooldown = 12 },
		Invis = { duration = 6, cooldown = 20 },
		SuperJump = { jumpPower = 70, duration = 6, cooldown = 10 },
		Slap = { range = 8, force = 60, cooldown = 6 },
		Freeze = { range = 12, duration = 3, cooldown = 18 },
		DecoyBoo = { duration = 45, cooldown = 10 },
		BaseAlarm = { duration = 60, cooldown = 5 },
	},

	Scares = {
		Classic = { duration = 1.5, range = 20, cooldown = 8, maxFovPunch = 8 },
		Party = { duration = 2.0, radius = 16, cooldown = 15 },
	},

	Rarities = {
		-- tier: ordem; luckAffected: a sorte multiplica o peso dessa raridade
		Common = { tier = 1, color = Color3.fromRGB(200, 200, 210), label = "Comum" },
		Uncommon = { tier = 2, color = Color3.fromRGB(110, 220, 120), label = "Incomum" },
		Rare = { tier = 3, color = Color3.fromRGB(80, 170, 255), label = "Raro" },
		Epic = { tier = 4, color = Color3.fromRGB(190, 100, 255), label = "Épico" },
		Legendary = { tier = 5, color = Color3.fromRGB(255, 190, 40), label = "Lendário" },
		Mythic = { tier = 6, color = Color3.fromRGB(255, 80, 150), label = "Mítico" },
		Secret = { tier = 7, color = Color3.fromRGB(40, 255, 230), label = "Secreto" },
	},
	LuckAffectsFromTier = 3, -- sorte multiplica o peso de Rare (tier 3) para cima
	SuperLuckyMultiplier = 10, -- Super Lucky Capture = re-roll com 10x sorte (fica o melhor)

	-- Boos originais. weight = chance relativa DENTRO da zona.
	-- accessory = detalhe visual montado com primitivas (ver shared/BooModel.luau)
	Boos = {
		MarshBoo = {
			name = "MarshBoo",
			rarity = "Common",
			incomePerSec = 1,
			zone = "Fairground",
			weight = 60,
			color = Color3.fromRGB(255, 235, 240),
			accessory = "Stick",
		},
		CottonBoo = {
			name = "CottonBoo",
			rarity = "Common",
			incomePerSec = 2,
			zone = "Fairground",
			weight = 45,
			color = Color3.fromRGB(255, 150, 200),
			accessory = "Fluff",
		},
		TicketBoo = {
			name = "TicketBoo",
			rarity = "Uncommon",
			incomePerSec = 4,
			zone = "Fairground",
			weight = 22,
			color = Color3.fromRGB(255, 210, 80),
			accessory = "Ticket",
		},
		PopcornBoo = {
			name = "PopcornBoo",
			rarity = "Uncommon",
			incomePerSec = 6,
			zone = "Fairground",
			weight = 16,
			color = Color3.fromRGB(255, 250, 220),
			accessory = "Popcorn",
		},
		GumdropBoo = {
			name = "GumdropBoo",
			rarity = "Rare",
			incomePerSec = 10,
			zone = "Fairground",
			weight = 5,
			color = Color3.fromRGB(120, 230, 160),
			accessory = "Sprinkles",
		},

		LampBoo = {
			name = "LampBoo",
			rarity = "Rare",
			incomePerSec = 15,
			zone = "Midway",
			weight = 30,
			color = Color3.fromRGB(255, 170, 70),
			accessory = "Lamp",
		},
		BalloonBoo = {
			name = "BalloonBoo",
			rarity = "Rare",
			incomePerSec = 22,
			zone = "Midway",
			weight = 22,
			color = Color3.fromRGB(90, 200, 255),
			accessory = "Balloon",
		},
		JellyBoo = {
			name = "JellyBoo",
			rarity = "Epic",
			incomePerSec = 40,
			zone = "Midway",
			weight = 8,
			color = Color3.fromRGB(170, 90, 255),
			accessory = "Wobble",
		},
		CarouselBoo = {
			name = "CarouselBoo",
			rarity = "Epic",
			incomePerSec = 55,
			zone = "Midway",
			weight = 5,
			color = Color3.fromRGB(255, 120, 120),
			accessory = "Pole",
		},

		MoonBoo = {
			name = "MoonBoo",
			rarity = "Epic",
			incomePerSec = 80,
			zone = "MoonLot",
			weight = 25,
			color = Color3.fromRGB(180, 190, 255),
			accessory = "Moon",
		},
		CometBoo = {
			name = "CometBoo",
			rarity = "Legendary",
			incomePerSec = 150,
			zone = "MoonLot",
			weight = 10,
			color = Color3.fromRGB(80, 120, 255),
			accessory = "Comet",
		},
		StarlightBoo = {
			name = "StarlightBoo",
			rarity = "Legendary",
			incomePerSec = 220,
			zone = "MoonLot",
			weight = 6,
			color = Color3.fromRGB(255, 240, 120),
			accessory = "Star",
		},

		CrystalBoo = {
			name = "CrystalBoo",
			rarity = "Mythic",
			incomePerSec = 450,
			zone = "SecretTent",
			weight = 20,
			color = Color3.fromRGB(150, 255, 255),
			accessory = "Crystal",
		},
		PrismBoo = {
			name = "PrismBoo",
			rarity = "Mythic",
			incomePerSec = 700,
			zone = "SecretTent",
			weight = 10,
			color = Color3.fromRGB(255, 130, 255),
			accessory = "Prism",
		},
		AuroraBoo = {
			name = "AuroraBoo",
			rarity = "Secret",
			incomePerSec = 1500,
			zone = "SecretTent",
			weight = 3,
			color = Color3.fromRGB(60, 255, 190),
			accessory = "Aurora",
		},
		JackpotBoo = {
			name = "JackpotBoo",
			rarity = "Secret",
			incomePerSec = 2500,
			zone = "SecretTent",
			weight = 1,
			color = Color3.fromRGB(255, 215, 0),
			accessory = "Crown",
		},
	},

	-- minStat compara com max(Speed, ThrowPower) — ver README
	Zones = {
		{
			name = "Fairground",
			label = "Feirinha",
			minStat = 0,
			luckBias = 0,
			maxBoos = 8,
			center = Vector3.new(95, 0, 0),
			radius = 26,
			color = Color3.fromRGB(255, 120, 180),
		},
		{
			name = "Midway",
			label = "Corredor das Barracas",
			minStat = 6,
			luckBias = 0.1,
			maxBoos = 7,
			center = Vector3.new(170, 0, 0),
			radius = 26,
			color = Color3.fromRGB(120, 200, 255),
		},
		{
			name = "MoonLot",
			label = "Terreno da Lua",
			minStat = 14,
			luckBias = 0.2,
			maxBoos = 6,
			center = Vector3.new(245, 0, 0),
			radius = 26,
			color = Color3.fromRGB(160, 140, 255),
		},
		{
			name = "SecretTent",
			label = "Tenda Secreta",
			minStat = 24,
			luckBias = 0.35,
			maxBoos = 4,
			center = Vector3.new(-150, 0, 0),
			radius = 22,
			color = Color3.fromRGB(80, 255, 200),
		},
	},
	BooRespawnSeconds = 6, -- a cada N segundos, cada zona tenta completar seus Boos
	CaptureCooldown = 0.8,

	-- Sons: SÓ preencha com IDs do Creator Store que você tem licença (anote em assets/CREDITS.md).
	-- 0 = sem som (o jogo funciona normalmente).
	Sounds = {
		-- Áudio licenciado do Creator Store (ver assets/CREDITS.md). 0 = sem som.
		Pop = 9112872244, -- ProSoundEffects
		RareSting = 9116394545, -- ProSoundEffects
		Alarm = 9113041445, -- ProSoundEffects (sirene de desenho)
		Whoosh = 9126283592, -- ProSoundEffects
		Boo = 9119197913, -- ProSoundEffects (apito cômico)
		Coin = 9113849306, -- ProSoundEffects
		Slap = 9114771792, -- ProSoundEffects
		Freeze = 9125611419, -- ProSoundEffects
		Poof = 9125640290, -- ProSoundEffects
		Purchase = 10066947742, -- Roblox
		Click = 15675059323, -- Roblox
		Spring = 12222124, -- Roblox
		Music = 1838796580, -- APMOfficial "Carnival"
		Volume = 0.4,
	},
	-- MaterialVariants gerados no Studio (MaterialService). Se não existirem, usa o material base.
	Materials = {
		Planks = "BooCandyPlanks",
		Tiles = "BooStarTiles",
		Tent = "BooTentStripes",
		Cobble = "BooPeachCobble",
		Belt = "BooConveyor",
	},
	-- Alguns sons são longos: toca só o começo (segundos)
	SoundTrim = {
		Coin = 0.9,
		Freeze = 1.2,
	},

	RateLimit = {
		EventsPerSecond = 8, -- por jogador, por remote
		KickThreshold = 120, -- eventos em 10s (abuso extremo) => kick com log
	},
}

-- Congela tudo (deep freeze) para ninguém mudar o Config em runtime.
local function deepFreeze(t)
	for _, v in pairs(t) do
		if type(v) == "table" and not table.isfrozen(v) then
			deepFreeze(v)
		end
	end
	table.freeze(t)
	return t
end

return deepFreeze(Config)
