local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Rarity = require(Shared.Util.Rarity)

local ShopService = {}

local ctx
local TAB_ORDER = { Boosts = 1, Poderes = 2, Sustos = 3, Cash = 4 }

function ShopService.carouselPrice(data): number
	return math.floor(Config.Carousel.Price * Config.Carousel.PriceGrowthPerRebirth ^ data.Rebirths)
end

function ShopService.catalog(player: Player)
	local passes, products = {}, {}
	for key, def in pairs(Config.GamePasses) do
		table.insert(passes, {
			key = key,
			id = def.id,
			name = def.name,
			price = def.price,
			icon = def.icon,
			desc = def.desc,
			owned = ctx.Passes.owns(player, key),
		})
	end
	for key, def in pairs(Config.Products) do
		table.insert(products, {
			key = key,
			id = def.id,
			name = def.name,
			price = def.price,
			icon = def.icon,
			desc = def.desc,
			tab = def.tab,
		})
	end
	table.sort(passes, function(a, b)
		return a.price < b.price
	end)
	table.sort(products, function(a, b)
		local ta, tb = TAB_ORDER[a.tab] or 9, TAB_ORDER[b.tab] or 9
		if ta ~= tb then
			return ta < tb
		end
		if a.price ~= b.price then
			return a.price < b.price
		end
		return a.key < b.key
	end)
	return { passes = passes, products = products, studio = RunService:IsStudio() }
end

function ShopService.buyCarousel(player: Player)
	local data = ctx.PlayerData.data(player)
	if not data or not ctx.Net.cooldown(player, "carousel", 0.6) then
		return
	end
	local stand = Workspace.StealABooWorld.Plaza.Carousel:FindFirstChild("CarouselStand") :: BasePart
	if not stand or not ctx.Net.near(player, stand.Position, 16) then
		ctx.notify(player, "Vá até o carrossel na praça.", "warn")
		return
	end
	local price = ShopService.carouselPrice(data)
	if data.Cash < price then
		ctx.notify(player, string.format("O Boo surpresa custa $%d.", price), "warn")
		return
	end
	if ctx.Boos.inventoryCount(data) >= Config.Economy.MaxInventory then
		ctx.notify(player, "Inventário cheio!", "warn")
		return
	end
	local key = Rarity.roll(Config.Carousel.Zone, ctx.Products.serverLuck() * (1 + Config.Carousel.LuckBias))
	if not key then
		return
	end
	data.Cash -= price
	local where = ctx.Boos.giveBoo(player, data, key)
	local def = Config.Boos[key]
	ctx.fx("Capture", { userId = player.UserId, booKey = key, position = stand.Position + Vector3.new(0, 4, 0) })
	ctx.notify(
		player,
		string.format(
			"O carrossel te deu %s (%s)%s",
			def.name,
			Rarity.label(def.rarity),
			where == "placed" and " — já está na base!" or "!"
		),
		"success"
	)
	ctx.PlayerData.markDirty(player)
end

local function studioGrant(player: Player, kind, key)
	if not RunService:IsStudio() then
		return
	end
	if kind == "Pass" and ctx.Net.isString(key) and Config.GamePasses[key] then
		ctx.Passes.studioGrant(player, key)
	elseif kind == "Product" and ctx.Net.isString(key) and Config.Products[key] then
		local data = ctx.PlayerData.data(player)
		if data then
			ctx.Products.grant(player, data, key)
		end
	elseif kind == "Test" and ctx.Net.isString(key, 16) then
		task.spawn(function()
			require(script.Parent.StudioTests).run(ctx, player, key)
		end)
	elseif kind == "Carry" and ctx.Net.isString(key) and Config.Boos[key] then
		ctx.Boos.studioCarry(player, key)
	end
end

function ShopService.init(c)
	ctx = c
	ctx.Net.onInvoke("GetShopCatalog", ShopService.catalog)
	ctx.Net.on("RequestCarousel", ShopService.buyCarousel)
	if RunService:IsStudio() and ctx.Net.remote("StudioGrant") then
		ctx.Net.on("StudioGrant", studioGrant)
	end
	local prompt = Workspace.StealABooWorld.Plaza:FindFirstChild("CarouselPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(player)
			if ctx.Net.allowPrompt(player, "Carousel") then
				ShopService.buyCarousel(player)
			end
		end)
	end
end

return ShopService
