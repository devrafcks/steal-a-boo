--[[
	Panels.luau — painéis: Bolsa (inventário), Rebirth, Daily, Ranking e Ajustes.
	Botões só PEDEM ao servidor; o resultado volta pelo snapshot (DataUpdated).
]]
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

----------------------------------------------------------------------
-- Bolsa
----------------------------------------------------------------------
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
	-- só redesenha quando o inventário/base mudou (o snapshot chega a cada segundo)
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

----------------------------------------------------------------------
-- Rebirth
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- Daily
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- Ranking
----------------------------------------------------------------------
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

----------------------------------------------------------------------
-- Ajustes
----------------------------------------------------------------------
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

----------------------------------------------------------------------
State.onReady(function(data)
	renderInventory(data)
	renderRebirth(data)
	renderDaily(data)
	renderSettings(data)
end)

return Panels
