--[[
	ShopUI.luau — loja com abas: Boosts, Poderes, Sustos, Cash, Passes.

	- Lê o catálogo do servidor (GetShopCatalog), que vem 100% do Config.
	- ID 0 = botão desabilitado. No Studio aparece "Configure o ID no Config" + botão
	  "Testar grátis" (StudioGrant, que só existe no Studio). Em produção: "Em breve".
	- ID preenchido = PromptProductPurchase / PromptGamePassPurchase. Quem ENTREGA é o
	  servidor (ProcessReceipt / GamePasses). O cliente nunca concede nada.
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UIController)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer
local T = UI.Theme

local ShopUI = {}

local TABS = { "Boosts", "Poderes", "Sustos", "Cash", "Passes" }
local currentTab = "Boosts"
local catalog = nil

local _, body = UI.panel("Shop", "Loja do Boo", UDim2.fromOffset(820, 520), function()
	ShopUI.refresh()
end)

local tabBar = UI.make("Frame", { Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), Parent = body })
UI.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabBar })

local grid = UI.make("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 8, Parent = body })
UI.make("UIGridLayout", { CellSize = UDim2.fromOffset(186, 200), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })

local tabButtons = {}
local TAB_COLORS = { Boosts = T.Green, Poderes = T.Cyan, Sustos = T.Pink, Cash = T.Yellow, Passes = T.Orange }

local function renderTab()
	for name, b in pairs(tabButtons) do
		b.BackgroundColor3 = name == currentTab and TAB_COLORS[name] or T.PanelLight
	end
	for _, c in grid:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	if not catalog then
		local f = UI.make("Frame", { BackgroundTransparency = 1, Parent = grid })
		UI.text(f, { Text = "Carregando...", Color = T.Muted })
		return
	end

	local items = {}
	if currentTab == "Passes" then
		for _, p in ipairs(catalog.passes) do
			table.insert(items, { kind = "Pass", data = p })
		end
	else
		for _, p in ipairs(catalog.products) do
			if p.tab == currentTab then
				table.insert(items, { kind = "Product", data = p })
			end
		end
	end

	for i, item in ipairs(items) do
		local d = item.data
		local card = UI.make("Frame", { Name = d.key, BackgroundColor3 = T.PanelLight, LayoutOrder = i, Parent = grid })
		UI.corner(card, 14)
		UI.stroke(card, 3)
		UI.text(card, { Text = d.icon or "?", Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 6), Stroke = false })
		UI.text(card, { Text = d.name, Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, 60), MaxTextSize = 20 })
		UI.text(card, { Text = d.desc or "", Size = UDim2.new(1, -12, 0, 40), Position = UDim2.fromOffset(6, 86), Color = T.Muted, MaxTextSize = 15, Font = T.FontBold, Stroke = false })

		local buttonText, color, disabled = string.format("R$ %d", d.price), T.Green, false
		if item.kind == "Pass" and d.owned then
			buttonText, color, disabled = "Comprado", T.Grey, true
		elseif d.id == 0 then
			buttonText, disabled = catalog.studio and "Configure o ID no Config" or "Em breve", true
		end

		local buy = UI.button(card, {
			Text = buttonText,
			Color = color,
			Size = UDim2.new(1, -12, 0, 38),
			Position = UDim2.new(0, 6, 1, catalog.studio and d.id == 0 and -78 or -44),
			MaxTextSize = d.id == 0 and 14 or 22,
			OnClick = function()
				if d.id == 0 then
					return
				end
				if item.kind == "Pass" then
					MarketplaceService:PromptGamePassPurchase(player, d.id)
				else
					MarketplaceService:PromptProductPurchase(player, d.id)
				end
			end,
		})
		UI.setDisabled(buy, disabled)

		if catalog.studio and d.id == 0 and not (item.kind == "Pass" and d.owned) then
			UI.button(card, {
				Text = "Testar grátis (Studio)",
				Color = T.Cyan,
				Size = UDim2.new(1, -12, 0, 32),
				Position = UDim2.new(0, 6, 1, -38),
				MaxTextSize = 15,
				OnClick = function()
					local remote = ReplicatedStorage.Remotes:FindFirstChild("StudioGrant")
					if remote then
						remote:FireServer(item.kind, d.key)
						task.delay(0.6, ShopUI.refresh)
					end
				end,
			})
		end
	end
end

for i, name in ipairs(TABS) do
	local b = UI.button(tabBar, {
		Text = name,
		Color = T.PanelLight,
		Size = UDim2.fromOffset(148, 44),
		LayoutOrder = i,
		MaxTextSize = 22,
		OnClick = function()
			currentTab = name
			renderTab()
		end,
	})
	tabButtons[name] = b
end

function ShopUI.refresh()
	renderTab()
	local ok, result = pcall(function()
		return Remotes.get("GetShopCatalog"):InvokeServer()
	end)
	if ok and result then
		catalog = result
		renderTab()
	end
end

function ShopUI.openTab(tab: string)
	if table.find(TABS, tab) then
		currentTab = tab
	end
	UI.open("Shop")
end

HUD.openShopTab = function(tab)
	currentTab = tab
	renderTab()
end

-- Depois de comprar um passe, o servidor revalida e a loja atualiza o "Comprado"
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_, _, purchased)
	if purchased then
		task.delay(3, ShopUI.refresh)
	end
end)

return ShopUI
