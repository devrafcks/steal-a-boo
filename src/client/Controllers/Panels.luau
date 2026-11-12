local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Rarity = require(Shared.Util.Rarity)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UIController)
local State = require(script.Parent.State)

local T = UI.Theme

local Panels = {}

local _, invBody = UI.panel("Inventory", "Bolsa de Boos", UDim2.fromOffset(640, 460))
local invInfo = UI.text(
	invBody,
	{ Text = "", Size = UDim2.new(1, 0, 0, 24), Color = T.Muted, XAlign = Enum.TextXAlignment.Left, MaxTextSize = 20 }
)
local invList = UI.make("ScrollingFrame", {
	Name = "List",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 30),
	Size = UDim2.new(1, 0, 1, -30),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 8,
	BorderSizePixel = 0,
	Parent = invBody,
})
UI.make("UIGridLayout", {
	CellSize = UDim2.fromOffset(190, 120),
	CellPadding = UDim2.fromOffset(10, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = invList,
})

local lastInvSignature = ""
local function renderInventory(data)
	local parts = { tostring(data.SlotCount) }
	for k, v in pairs(data.Inventory) do
		table.insert(parts, k .. "=" .. v)
	end
	for k, v in pairs(data.PlotLayout) do
		table.insert(parts, k .. ":" .. v)
	end
	table.sort(parts)
	local signature = table.concat(parts, ",")
	if signature == lastInvSignature then
		return
	end
	lastInvSignature = signature
	for _, c in invList:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local keys = {}
	local total = 0
	for key, count in pairs(data.Inventory) do
		if Config.Boos[key] and count > 0 then
			table.insert(keys, key)
			total += count
		end
	end
	table.sort(keys, function(a, b)
		return Config.Boos[a].incomePerSec > Config.Boos[b].incomePerSec
	end)
	local placed = 0
	for _ in pairs(data.PlotLayout) do
		placed += 1
	end
	invInfo.Text = string.format(
		"Na bolsa: %d/%d   •   Na base: %d/%d slots",
		total,
		Config.Economy.MaxInventory,
		placed,
		data.SlotCount
	)
	if #keys == 0 then
		local empty = UI.make("Frame", { BackgroundTransparency = 1, Parent = invList })
		UI.text(empty, { Text = "Vazia! Capture Boos nas zonas.", Color = T.Muted, MaxTextSize = 20 })
		return
	end
	for i, key in ipairs(keys) do
		local def = Config.Boos[key]
		local card =
			UI.make("Frame", { Name = key, BackgroundColor3 = T.PanelLight, LayoutOrder = i, Parent = invList })
		UI.corner(card, 12)
		UI.make("UIStroke", { Thickness = 3, Color = Rarity.color(def.rarity), Parent = card })
		UI.text(card, {
			Text = string.format("%s  x%d", def.name, data.Inventory[key]),
			Size = UDim2.new(1, -12, 0, 26),
			Position = UDim2.fromOffset(6, 4),
			MaxTextSize = 22,
		})
		UI.text(card, {
			Text = string.format("%s • $%d/s", Rarity.label(def.rarity), def.incomePerSec),
			Size = UDim2.new(1, -12, 0, 20),
			Position = UDim2.fromOffset(6, 32),
			Color = Rarity.color(def.rarity),
			MaxTextSize = 18,
		})
		UI.button(card, {
			Text = "Colocar",
			Color = T.Green,
			Size = UDim2.new(0.5, -9, 0, 40),
			Position = UDim2.new(0, 6, 1, -46),
			MaxTextSize = 18,
			OnClick = function()
				Remotes.get("RequestPlaceBoo"):FireServer(key)
			end,
		})
		UI.button(card, {
			Text = "Vender $" .. Format.compact(def.incomePerSec * Config.Economy.SellMultiplier),
			Color = T.Orange,
			Size = UDim2.new(0.5, -9, 0, 40),
			Position = UDim2.new(0.5, 3, 1, -46),
			MaxTextSize = 16,
			OnClick = function()
				UI.confirm(
					string.format("Vender 1 %s por $%d?", def.name, def.incomePerSec * Config.Economy.SellMultiplier),
					function()
						Remotes.get("RequestSellBoo"):FireServer(key)
						task.delay(0.3, function()
							UI.open("Inventory")
						end)
					end
				)
			end,
		})
	end
end

local _, rebBody = UI.panel("Rebirth", "Rebirth", UDim2.fromOffset(520, 340))
local rebText = UI.text(rebBody, { Text = "", Size = UDim2.new(1, 0, 0, 170), MaxTextSize = 24, RichText = true })
local rebButton = UI.button(rebBody, {
	Text = "Fazer Rebirth",
	Color = T.Green,
	Size = UDim2.fromOffset(260, 60),
	Position = UDim2.new(0.5, -130, 1, -66),
	OnClick = function()
		local data = State.data
		if not data then
			return
		end
		UI.confirm(
			string.format(
				"Rebirth custa $%s. Seu Cash e Boos abaixo de %s serão resetados. Continuar?",
				Format.compact(data.RebirthCost),
				Rarity.label(Config.Rebirth.KeepRarityAtOrAbove)
			),
			function()
				Remotes.get("RequestRebirth"):FireServer()
			end
		)
	end,
})

local function renderRebirth(data)
	local nextBonus = math.floor((data.Rebirths + 1) * Config.Rebirth.IncomeMultiplierPerRebirth * 100)
	rebText.Text = string.format(
		"Rebirths: <b>%d</b>\nCusto: <b>$%s</b> (você tem $%s)\n\nDepois: renda <b>+%d%%</b> para sempre.\nMantém Boos %s ou melhores, passes,\nitens, Speed e Throw.",
		data.Rebirths,
		Format.compact(data.RebirthCost),
		Format.compact(data.Cash),
		nextBonus,
		Rarity.label(Config.Rebirth.KeepRarityAtOrAbove)
	)
	UI.setDisabled(rebButton, data.Cash < data.RebirthCost, T.Green)
end

local _, dailyBody = UI.panel("Daily", "Recompensa Diária", UDim2.fromOffset(640, 300))
local dayRow = UI.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 120), Parent = dailyBody })
UI.make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 8),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Parent = dayRow,
})
local dayCards = {}
for i = 1, Config.Daily.StreakMax do
	local c = UI.make(
		"Frame",
		{ BackgroundColor3 = T.PanelLight, Size = UDim2.fromOffset(78, 110), LayoutOrder = i, Parent = dayRow }
	)
	UI.corner(c, 12)
	UI.stroke(c, 3)
	UI.text(
		c,
		{ Text = "Dia " .. i, Size = UDim2.new(1, -6, 0, 26), Position = UDim2.fromOffset(3, 4), MaxTextSize = 20 }
	)
	UI.text(c, {
		Text = "$" .. Format.compact(Config.Daily.Rewards[i]) .. (i == Config.Daily.StreakMax and "\n+Sorte" or ""),
		Size = UDim2.new(1, -6, 0, 60),
		Position = UDim2.fromOffset(3, 40),
		Color = T.Yellow,
		MaxTextSize = 20,
	})
	dayCards[i] = c
end
local dailyStatus = UI.text(
	dailyBody,
	{ Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 126), Color = T.Muted, MaxTextSize = 20 }
)
local dailyButton = UI.button(dailyBody, {
	Text = "Pegar!",
	Color = T.Yellow,
	Size = UDim2.fromOffset(220, 54),
	Position = UDim2.new(0.5, -110, 1, -58),
	OnClick = function()
		Remotes.get("RequestDaily"):FireServer()
	end,
})

local function renderDaily(data)
	local d = data.Daily
	for i, c in ipairs(dayCards) do
		local done = d.canClaim and i < d.streak or (not d.canClaim and i <= d.streak)
		local isNext = d.canClaim and i == d.streak
		c.BackgroundColor3 = isNext and T.Pink or (done and T.Green or T.PanelLight)
	end
	if d.canClaim then
		dailyStatus.Text = string.format("Hoje: dia %d da sequência (+$%s)", d.streak, Format.compact(d.nextReward))
	else
		local s = d.secondsToReset or 0
		dailyStatus.Text =
			string.format("Já pegou hoje! Volte em %dh%02dm (horário UTC)", s // 3600, (s % 3600) // 60)
	end
	UI.setDisabled(dailyButton, not d.canClaim, T.Yellow)
end

local _, lbBody = UI.panel("Leaderboard", "Ranking Global", UDim2.fromOffset(640, 440), function()
	Panels.renderLeaderboard()
end)
local lbCash = UI.text(lbBody, {
	Text = "",
	Size = UDim2.new(0.5, -8, 1, 0),
	XAlign = Enum.TextXAlignment.Left,
	YAlign = Enum.TextYAlignment.Top,
	TextScaled = false,
	TextSize = 20,
	Font = T.FontBold,
})
local lbReb = UI.text(lbBody, {
	Text = "",
	Size = UDim2.new(0.5, -8, 1, 0),
	Position = UDim2.new(0.5, 8, 0, 0),
	XAlign = Enum.TextXAlignment.Left,
	YAlign = Enum.TextYAlignment.Top,
	TextScaled = false,
	TextSize = 20,
	Font = T.FontBold,
})

function Panels.renderLeaderboard()
	local value = ReplicatedStorage:FindFirstChild("LeaderboardData")
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(value and value.Value or "{}")
	end)
	if not ok or not decoded.available then
		lbCash.Text = "Ranking indisponível agora.\n(No Studio, ligue API Services.)"
		lbReb.Text = ""
		return
	end
	local function lines(title, rows, prefix)
		local out = { title, "" }
		for i, r in ipairs(rows) do
			table.insert(
				out,
				string.format("%d. %s — %s%s", i, (tostring(r.name):gsub("<", "")), prefix, Format.compact(r.value))
			)
		end
		return table.concat(out, "\n")
	end
	lbCash.Text = lines("Mais Cash (all-time)", decoded.cash or {}, "$")
	lbReb.Text = lines("Mais Rebirths", decoded.rebirths or {}, "")
end

local _, setBody = UI.panel("Settings", "Ajustes", UDim2.fromOffset(500, 300))
local reduceButton, reduceLabel = UI.button(setBody, {
	Text = "Reduzir sustos: NÃO",
	Color = T.PanelLight,
	Size = UDim2.new(1, 0, 0, 56),
	OnClick = function()
		local data = State.data
		if data then
			Remotes.get("UpdateSettings"):FireServer({ ReduceScares = not data.Settings.ReduceScares })
		end
	end,
})
UI.text(setBody, {
	Text = "Com isso ligado, sustos viram só um ícone pequeno, sem tela cheia nem tremida.",
	Size = UDim2.new(1, 0, 0, 40),
	Position = UDim2.fromOffset(0, 60),
	Color = T.Muted,
	MaxTextSize = 18,
})
local volLabel = UI.text(
	setBody,
	{ Text = "Música: 50%", Size = UDim2.new(0.5, 0, 0, 50), Position = UDim2.fromOffset(0, 120), MaxTextSize = 22 }
)
local function changeVolume(delta)
	local data = State.data
	if data then
		local v = math.clamp(math.floor((data.Settings.MusicVolume + delta) * 10 + 0.5) / 10, 0, 1)
		Remotes.get("UpdateSettings"):FireServer({ MusicVolume = v })
	end
end
UI.button(setBody, {
	Text = "-",
	Color = T.Grey,
	Size = UDim2.fromOffset(60, 50),
	Position = UDim2.new(0.5, 10, 0, 120),
	OnClick = function()
		changeVolume(-0.1)
	end,
})
UI.button(setBody, {
	Text = "+",
	Color = T.Green,
	Size = UDim2.fromOffset(60, 50),
	Position = UDim2.new(0.5, 80, 0, 120),
	OnClick = function()
		changeVolume(0.1)
	end,
})
local saveNote = UI.text(
	setBody,
	{ Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -34), Color = T.Muted, MaxTextSize = 16 }
)

local function renderSettings(data)
	local on = data.Settings.ReduceScares
	reduceLabel.Text = on and "Reduzir sustos: SIM" or "Reduzir sustos: NÃO"
	reduceButton.BackgroundColor3 = on and T.Green or T.PanelLight
	volLabel.Text = string.format("Música: %d%%", math.floor(data.Settings.MusicVolume * 100 + 0.5))
	saveNote.Text = data.RealSave and "Seu progresso é salvo automaticamente."
		or "Studio: save em memória (API Services desligado)."
end

local _, baseBody = UI.panel("Base", "Minha Base", UDim2.fromOffset(600, 430))
local baseInfo = UI.text(baseBody, { Text = "", Size = UDim2.new(1, 0, 0, 120), MaxTextSize = 22, RichText = true })
local upgradeButton, upgradeLabel = UI.button(baseBody, {
	Text = "Construir",
	Color = T.Cyan,
	Size = UDim2.fromOffset(300, 56),
	Position = UDim2.new(0.5, -150, 0, 128),
	OnClick = function()
		Remotes.get("RequestUpgradeBase"):FireServer()
	end,
})
UI.text(baseBody, {
	Text = "Esteiras pagas: multiplicam a renda dos seus Boos por 2 minutos",
	Size = UDim2.new(1, 0, 0, 26),
	Position = UDim2.fromOffset(0, 200),
	Color = T.Muted,
	MaxTextSize = 18,
})
local beltRow = UI.make("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 120),
	Position = UDim2.fromOffset(0, 232),
	Parent = baseBody,
})
UI.make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 12),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Parent = beltRow,
})
for i, key in ipairs({ "Belt2x", "Belt3x", "Belt4x" }) do
	local def = Config.Products[key]
	local color = ({ T.Green, T.Orange, T.Pink })[i]
	local card = UI.make(
		"Frame",
		{ BackgroundColor3 = T.PanelLight, Size = UDim2.fromOffset(170, 116), LayoutOrder = i, Parent = beltRow }
	)
	UI.corner(card, 12)
	UI.make("UIStroke", { Thickness = 3, Color = color, Parent = card })
	UI.text(card, {
		Text = def.mult .. "x RENDA",
		Font = T.FontTitle,
		Color = color,
		Size = UDim2.new(1, -10, 0, 36),
		Position = UDim2.fromOffset(5, 6),
	})
	UI.text(card, {
		Text = "2 minutos",
		Size = UDim2.new(1, -10, 0, 20),
		Position = UDim2.fromOffset(5, 42),
		Color = T.Muted,
		MaxTextSize = 16,
	})
	UI.button(card, {
		Text = "R$ " .. def.price,
		Color = color,
		Size = UDim2.new(1, -16, 0, 40),
		Position = UDim2.new(0, 8, 1, -48),
		OnClick = function()
			require(script.Parent.ShopUI).buyProduct(key)
		end,
	})
end

local function renderBase(data)
	local nextFloor = data.NextFloor
	local boostText = (data.IncomeBoostEnds or 0) > os.time()
			and string.format(
				"\nEsteira ativa: <b>%dx</b> (%s)",
				data.IncomeBoostMult,
				Format.time(data.IncomeBoostEnds - os.time())
			)
		or ""
	baseInfo.Text = string.format(
		"Andares: <b>%d/%d</b>   •   Slots liberados: <b>%d</b>\nCofre: <b>$%s</b> (pise no pad dourado da base)%s",
		data.BaseLevel or 1,
		data.MaxLevel or 4,
		data.SlotCount,
		Format.compact(data.Vault or 0),
		boostText
	)
	if nextFloor then
		upgradeLabel.Text = string.format("Construir %s — $%s", nextFloor.name, Format.compact(nextFloor.cost))
		UI.setDisabled(upgradeButton, data.Cash + (data.Vault or 0) < nextFloor.cost, T.Cyan)
	else
		upgradeLabel.Text = "Base no máximo!"
		UI.setDisabled(upgradeButton, true)
	end
end

local U = Config.Upgrades
local _, labBody = UI.panel("Lab", "Laboratório de Upgrades", UDim2.fromOffset(660, 500))

local saleBar = UI.make(
	"Frame",
	{ BackgroundColor3 = Color3.fromRGB(150, 60, 150), Size = UDim2.new(1, 0, 0, 46), Parent = labBody }
)
UI.corner(saleBar, 12)
UI.stroke(saleBar, 3)
local saleText = UI.text(saleBar, {
	Text = "",
	Size = UDim2.new(1, -200, 1, -8),
	Position = UDim2.fromOffset(12, 4),
	XAlign = Enum.TextXAlignment.Left,
	MaxTextSize = 20,
	ZIndex = 52,
})
local _, saleLabel = UI.button(saleBar, {
	Text = "",
	Color = T.Yellow,
	Size = UDim2.fromOffset(180, 36),
	Position = UDim2.new(1, -188, 0, 5),
	MaxTextSize = 17,
	ZIndex = 52,
	OnClick = function()
		require(script.Parent.ShopUI).buyProduct("Sale50")
	end,
})

local labGrid = UI.make("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 56),
	Size = UDim2.new(1, 0, 1, -100),
	Parent = labBody,
})
UI.make("UIGridLayout", {
	CellSize = UDim2.fromOffset(300, 168),
	CellPadding = UDim2.fromOffset(12, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = labGrid,
})
UI.text(labBody, {
	Text = "Pedestais: aperte F perto de um Boo na sua base para evoluir só aquele slot.",
	Size = UDim2.new(1, 0, 0, 26),
	Position = UDim2.new(0, 0, 1, -32),
	Color = T.Muted,
	MaxTextSize = 17,
})

local labCards = {}
for i, track in ipairs(U.Order) do
	local def = U[track]
	local card = UI.make("Frame", { BackgroundColor3 = T.PanelLight, LayoutOrder = i, Parent = labGrid })
	UI.corner(card, 14)
	UI.stroke(card, 3)
	UI.text(card, {
		Text = def.icon .. " " .. def.name,
		Font = T.FontTitle,
		Color = T.Yellow,
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.fromOffset(8, 6),
		XAlign = Enum.TextXAlignment.Left,
		MaxTextSize = 26,
	})
	local levelText = UI.text(card, {
		Text = "",
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(8, 38),
		XAlign = Enum.TextXAlignment.Left,
		Color = T.Cyan,
		MaxTextSize = 20,
	})
	local effectText = UI.text(card, {
		Text = "",
		Size = UDim2.new(1, -16, 0, 40),
		Position = UDim2.fromOffset(8, 62),
		XAlign = Enum.TextXAlignment.Left,
		Color = T.Muted,
		MaxTextSize = 17,
		Font = T.FontBold,
		Stroke = false,
	})
	local button, buttonLabel = UI.button(card, {
		Text = "",
		Color = T.Green,
		Size = UDim2.new(1, -16, 0, 42),
		Position = UDim2.new(0, 8, 1, -50),
		MaxTextSize = 20,
		OnClick = function()
			Remotes.get("RequestUpgradeTrack"):FireServer(track)
		end,
	})
	labCards[track] = { level = levelText, effect = effectText, button = button, label = buttonLabel }
end

local function trackEffect(track: string, level: number): string
	if track == "Income" then
		return string.format("Renda x%.2f", 1 + level * U.Income.perLevel)
	elseif track == "Vault" then
		return string.format(
			"Cofre guarda %ds de renda",
			Config.Vault.BaseSeconds + level * Config.Vault.SecondsPerLevel
		)
	elseif track == "Luck" then
		return string.format("+%d%% de chance de raros", math.floor(level * U.Luck.perLevel * 100 + 0.5))
	end
	return string.format(
		"Roubar demora %.1fs • %d socos • portão %ds",
		0.8 + level * U.StealHoldPerLevel,
		Config.Combat.GripBase + math.floor(level * Config.Combat.GripPerTwoSecurityLevels / 2),
		Config.World.GateLockSeconds + level * U.GateLockPerLevel
	)
end

local function renderLab(data)
	for _, track in ipairs(U.Order) do
		local def, card = U[track], labCards[track]
		local level = (data.UpgradeLevels and data.UpgradeLevels[track]) or 0
		local cost = data.UpgradeCosts and data.UpgradeCosts[track]
		card.level.Text = string.format("Nível %d / %d", level, def.max)
		if cost then
			card.effect.Text = trackEffect(track, level) .. "\n→ " .. trackEffect(track, level + 1)
			card.label.Text = string.format("Evoluir  $%s", Format.compact(cost))
			UI.setDisabled(card.button, data.Cash < cost, T.Green)
		else
			card.effect.Text = trackEffect(track, level) .. "\n(máximo)"
			card.label.Text = "Nível máximo"
			UI.setDisabled(card.button, true)
		end
	end
	local left = (data.UpgradeSaleEnds or 0) - os.time()
	local price = Config.Products.Sale50.price
	if left > 0 then
		saleText.Text = string.format("PROMOÇÃO ativa: upgrades e andares -50%%  (%s)", Format.time(left))
		saleLabel.Text = string.format("+10 min  R$ %d", price)
	else
		saleText.Text = "Promoção: upgrades e andares pela METADE do preço por 10 min"
		saleLabel.Text = string.format("Ativar  R$ %d", price)
	end
end

State.onReady(function(data)
	renderLab(data)
	renderBase(data)
	renderInventory(data)
	renderRebirth(data)
	renderDaily(data)
	renderSettings(data)
end)

return Panels
