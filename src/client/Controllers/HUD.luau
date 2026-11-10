--[[
	HUD.luau — Cash, Cash/s, Speed, Throw, Rebirths, sorte do servidor,
	botões laterais (Loja, Bolsa, Daily, Rebirth, Ranking, Ajustes, Trancar),
	hotbar de consumíveis (teclas 1..9) e aviso de "carregando Boo".
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UIController)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local T = UI.Theme

local HUD = {}

local cooldownEnds: { [string]: number } = {}

----------------------------------------------------------------------
-- Painel de status (topo esquerdo)
----------------------------------------------------------------------
local stats = UI.make("Frame", {
	Name = "Stats",
	BackgroundColor3 = T.Panel,
	BackgroundTransparency = 0.1,
	Position = UDim2.fromOffset(12, 12),
	Size = UDim2.fromOffset(250, 152),
	Parent = UI.root,
})
UI.corner(stats, 16)
UI.stroke(stats, 3)
local cashLabel = UI.text(stats, {
	Text = "$0",
	Font = T.FontTitle,
	Color = T.Yellow,
	Size = UDim2.new(1, -20, 0, 40),
	Position = UDim2.fromOffset(12, 6),
	XAlign = Enum.TextXAlignment.Left,
})
local incomeLabel = UI.text(stats, {
	Text = "+$0/s",
	Color = T.Green,
	Size = UDim2.new(1, -20, 0, 24),
	Position = UDim2.fromOffset(12, 46),
	XAlign = Enum.TextXAlignment.Left,
})
local statLine = UI.text(stats, {
	Text = "",
	Color = T.Muted,
	Size = UDim2.new(1, -20, 0, 22),
	Position = UDim2.fromOffset(12, 72),
	XAlign = Enum.TextXAlignment.Left,
	MaxTextSize = 20,
})
local vaultLine = UI.text(stats, {
	Text = "",
	Color = T.Yellow,
	Size = UDim2.new(1, -20, 0, 22),
	Position = UDim2.fromOffset(12, 120),
	XAlign = Enum.TextXAlignment.Left,
	MaxTextSize = 20,
})
local statLine2 = UI.text(stats, {
	Text = "",
	Color = T.Muted,
	Size = UDim2.new(1, -20, 0, 22),
	Position = UDim2.fromOffset(12, 96),
	XAlign = Enum.TextXAlignment.Left,
	MaxTextSize = 20,
})

----------------------------------------------------------------------
-- Banner de sorte do servidor e boosts (topo centro)
----------------------------------------------------------------------
local banner = UI.make("Frame", {
	Name = "LuckBanner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(460, 50),
	BackgroundColor3 = Color3.fromRGB(60, 180, 90),
	Visible = false,
	Parent = UI.root,
})
UI.corner(banner, 14)
UI.stroke(banner, 3)
UI.make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 200)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 90)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 220, 255)),
	}),
	Parent = banner,
})
local bannerText = UI.text(
	banner,
	{ Text = "", Font = T.FontTitle, Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4) }
)

local carryBanner = UI.make("Frame", {
	Name = "CarryBanner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 68),
	Size = UDim2.fromOffset(460, 40),
	BackgroundColor3 = T.Orange,
	Visible = false,
	Parent = UI.root,
})
UI.corner(carryBanner, 12)
UI.stroke(carryBanner, 3)
local carryText =
	UI.text(carryBanner, { Text = "", Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4) })

----------------------------------------------------------------------
-- Botões laterais
----------------------------------------------------------------------
local side = UI.make("Frame", {
	Name = "SideButtons",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 176),
	Size = UDim2.fromOffset(110, 480),
	Parent = UI.root,
})
UI.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = side })

local dailyBadge
local function sideButton(order: number, text: string, color: Color3, onClick)
	local b = UI.button(side, {
		Text = text,
		Color = color,
		Size = UDim2.fromOffset(110, 52),
		LayoutOrder = order,
		OnClick = onClick,
		MaxTextSize = 22,
	})
	return b
end
sideButton(1, "🛒 Loja", T.Pink, function()
	UI.toggle("Shop")
end)
sideButton(2, "🎒 Bolsa", T.Cyan, function()
	UI.toggle("Inventory")
end)
local dailyButton = sideButton(3, "🎁 Daily", T.Yellow, function()
	UI.toggle("Daily")
end)
dailyBadge = UI.make("Frame", {
	Name = "Badge",
	BackgroundColor3 = T.Red,
	Size = UDim2.fromOffset(22, 22),
	Position = UDim2.new(1, -14, 0, -8),
	Visible = false,
	ZIndex = 5,
	Parent = dailyButton,
})
UI.corner(dailyBadge, 11)
UI.text(dailyBadge, { Text = "!", ZIndex = 6 })
sideButton(4, "♻️ Rebirth", T.Green, function()
	UI.toggle("Rebirth")
end)
sideButton(5, "🏆 Ranking", T.Orange, function()
	UI.toggle("Leaderboard")
end)
sideButton(6, "🏠 Base", Color3.fromRGB(150, 110, 255), function()
	UI.toggle("Base")
end)
sideButton(7, "⚙️ Ajustes", T.Grey, function()
	UI.toggle("Settings")
end)

-- Trancar base (direita)
local lockButton, lockLabel = UI.button(UI.root, {
	Name = "LockButton",
	Text = "🔒 Trancar base",
	Color = T.Green,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -110),
	Size = UDim2.fromOffset(170, 52),
	MaxTextSize = 22,
	OnClick = function()
		Remotes.get("ToggleBaseGate"):FireServer()
	end,
})

----------------------------------------------------------------------
-- Hotbar (teclas 1..9)
----------------------------------------------------------------------
local hotbar = UI.make("Frame", {
	Name = "Hotbar",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.fromOffset(9 * 66, 64),
	Parent = UI.root,
})
UI.make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = hotbar,
})

local slots = {}

function HUD.use(index: number)
	local item = Config.Consumables[index]
	if not item then
		return
	end
	local data = State.data
	if not data or (data.Consumables[item.key] or 0) <= 0 then
		UI.open("Shop")
		HUD.openShopTab(item.type == "Scare" and "Sustos" or "Poderes")
		return
	end
	local remote = item.type == "Scare" and "RequestUseScare" or "RequestUsePower"
	Remotes.get(remote):FireServer(item.key)
end

for i, item in ipairs(Config.Consumables) do
	local b = UI.make("TextButton", {
		Name = item.key,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = T.Panel,
		Size = UDim2.fromOffset(60, 60),
		LayoutOrder = i,
		Parent = hotbar,
	})
	UI.corner(b, 12)
	UI.stroke(b, 3)
	UI.text(
		b,
		{ Text = item.icon, Size = UDim2.new(1, -14, 1, -22), Position = UDim2.fromOffset(7, 4), Stroke = false }
	)
	local count = UI.text(b, {
		Text = "0",
		Size = UDim2.fromOffset(26, 18),
		Position = UDim2.new(1, -28, 1, -20),
		Color = T.Yellow,
		MaxTextSize = 16,
		Name = "Count",
	})
	UI.text(b, {
		Text = tostring(i),
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromOffset(4, 2),
		Color = T.Muted,
		MaxTextSize = 14,
		Name = "Key",
	})
	UI.text(b, {
		Text = item.label,
		Size = UDim2.new(1, -4, 0, 14),
		Position = UDim2.new(0, 2, 1, -16),
		Color = T.Text,
		MaxTextSize = 12,
		Name = "Name",
		XAlign = Enum.TextXAlignment.Left,
	})
	local cd = UI.make("Frame", {
		Name = "Cooldown",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		ZIndex = 4,
		Parent = b,
	})
	UI.corner(cd, 12)
	b.MouseButton1Click:Connect(function()
		UI.squash(b)
		HUD.use(i)
	end)
	slots[item.key] = { button = b, count = count, cd = cd }
end

function HUD.startCooldown(key: string, seconds: number)
	cooldownEnds[key] = os.clock() + seconds
	local s = slots[key]
	if s then
		s.cd:SetAttribute("Total", seconds)
	end
end

-- O ShopUI substitui esta função quando carrega
function HUD.openShopTab(_tab: string) end

----------------------------------------------------------------------
-- Atualização
----------------------------------------------------------------------
local function render(data)
	cashLabel.Text = "$" .. Format.compact(data.Cash)
	local boost = (data.IncomeBoostEnds or 0) > os.time() and string.format("  (%dx esteira!)", data.IncomeBoostMult)
		or ((data.Cash2xEnds or 0) > os.time() and "  (2x!)" or "")
	vaultLine.Text = string.format("Cofre: $%s  (pise no pad dourado)", Format.compact(data.Vault or 0))
	incomeLabel.Text = string.format("+$%s/s%s", Format.compact(data.IncomePerSec), boost)
	statLine.Text = string.format("Speed %.1f  •  Throw %.1f", data.Speed, data.ThrowPower)
	statLine2.Text = string.format("Rebirths %d  •  Sorte+ %d", data.Rebirths, data.LuckyCaptures)
	for key, s in pairs(slots) do
		local n = data.Consumables[key] or 0
		s.count.Text = tostring(n)
		s.button.BackgroundColor3 = n > 0 and T.PanelLight or T.Panel
	end
	dailyBadge.Visible = data.Daily and data.Daily.canClaim or false
end
State.onReady(render)

RunService.Heartbeat:Connect(function()
	-- Banner de sorte
	local luck = Workspace:GetAttribute("ServerLuck") or 1
	local ends = Workspace:GetAttribute("ServerLuckEnds") or 0
	local left = ends - Workspace:GetServerTimeNow()
	if luck > 1 and left > 0 then
		banner.Visible = true
		bannerText.Text = string.format(
			"%dx LUCK por %s  —  %s",
			luck,
			Workspace:GetAttribute("ServerLuckBy") or "?",
			Format.time(left)
		)
	else
		banner.Visible = false
	end

	-- Carregando Boo
	local carrying = player:GetAttribute("Carrying")
	carryBanner.Visible = carrying ~= nil
	if carrying then
		carryText.Text = string.format("Carregando %s! Corra para a SUA base!", carrying)
	end

	-- Cooldowns da hotbar
	local now = os.clock()
	for key, s in pairs(slots) do
		local e = cooldownEnds[key]
		local total = s.cd:GetAttribute("Total") or 1
		if e and e > now then
			s.cd.Size = UDim2.fromScale(1, (e - now) / total)
		else
			s.cd.Size = UDim2.fromScale(1, 0)
		end
	end

	-- Botão de trancar
	local idx = player:GetAttribute("PlotIndex")
	local plots = Workspace:FindFirstChild("StealABooWorld") and Workspace.StealABooWorld:FindFirstChild("Plots")
	local plot = idx and plots and plots:FindFirstChild("Plot_" .. idx)
	if plot then
		local t = Workspace:GetServerTimeNow()
		local lockEnds = plot:GetAttribute("LockEnds") or 0
		local nextLock = plot:GetAttribute("NextLockAt") or 0
		if lockEnds > t then
			lockLabel.Text = string.format("🔒 Trancada %ds", math.ceil(lockEnds - t))
			UI.setDisabled(lockButton, true)
		elseif nextLock > t then
			lockLabel.Text = string.format("⏳ Trancar em %ds", math.ceil(nextLock - t))
			UI.setDisabled(lockButton, true)
		else
			lockLabel.Text = "🔓 Trancar base"
			UI.setDisabled(lockButton, false, T.Green)
		end
	end
end)

return HUD
