--[[
	ProcessReceipt.luau — o ÚNICO lugar do jogo que define MarketplaceService.ProcessReceipt.
	Doc oficial: https://create.roblox.com/docs/production/monetization/developer-products

	Fluxo:
	1. Jogador não está no servidor            -> NotProcessedYet (Roblox tenta de novo depois)
	2. Perfil não carregou / sessão inativa    -> NotProcessedYet
	3. ProductId não existe no Config (ou é 0) -> NotProcessedYet + log (nunca entrega desconhecido)
	4. PurchaseId já entregue                  -> PurchaseGranted (idempotente, não dá 2x)
	5. Entrega + grava PurchaseId no perfil no mesmo passo; erro -> NotProcessedYet
	6. Pede save imediato e espera o DataStore confirmar (padrão recomendado pelo ProfileStore)
	   Confirmou -> PurchaseGranted. Não confirmou a tempo -> NotProcessedYet
	   (a Roblox reenvia; o PurchaseId no perfil impede entregar de novo).
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Products = require(script.Parent.Products)
local ReceiptStore = require(script.Parent.ReceiptStore)

local ProcessReceipt = {}

local ctx
local SAVE_WAIT_SECONDS = 15

local function process(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = ctx.PlayerData.waitFor(player, 20)
	if not profile or not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local key = Products.keyById(receiptInfo.ProductId)
	if not key then
		warn(
			string.format(
				"[ProcessReceipt] ProductId %s não está no Config.Products — não vou entregar.",
				tostring(receiptInfo.ProductId)
			)
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)
	local data = profile.Data

	if not ReceiptStore.has(data, purchaseId) then
		local ok, granted = pcall(Products.grant, player, data, key)
		if not ok or not granted then
			warn(
				string.format("[ProcessReceipt] falha ao entregar %s para %s: %s", key, player.Name, tostring(granted))
			)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		ReceiptStore.record(data, purchaseId)
	end

	-- Espera o save confirmar (ProfileStore atualiza LastSavedData depois de gravar)
	if profile.Save then
		profile:Save()
	end
	local deadline = os.clock() + SAVE_WAIT_SECONDS
	while os.clock() < deadline do
		if ReceiptStore.isSaved(profile, purchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		if not profile:IsActive() then
			break
		end
		task.wait(0.25)
	end
	if ReceiptStore.isSaved(profile, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function ProcessReceipt.init(c)
	ctx = c
	MarketplaceService.ProcessReceipt = process
end

return ProcessReceipt
