--[[
	ReceiptStore.luau — lembra quais PurchaseId já foram entregues.

	- Principal: Data.PurchaseIds no perfil (vai junto com o item no MESMO save).
	- Extra: cache em memória do servidor, para o caso raro de o mesmo receipt chegar 2x
	  antes do perfil salvar.
	- Entradas com mais de Config.DataStore.PurchaseIdMemoryDays são limpas no load (PlayerData).
]]
local ReceiptStore = {}

local serverCache: { [string]: boolean } = {}

function ReceiptStore.has(data, purchaseId: string): boolean
	return serverCache[purchaseId] == true or (data and data.PurchaseIds[purchaseId] ~= nil)
end

function ReceiptStore.record(data, purchaseId: string)
	data.PurchaseIds[purchaseId] = os.time()
	serverCache[purchaseId] = true
end

-- true quando o PurchaseId já está no último save confirmado do DataStore
function ReceiptStore.isSaved(profile, purchaseId: string): boolean
	local saved = profile.LastSavedData
	return saved ~= nil and saved.PurchaseIds ~= nil and saved.PurchaseIds[purchaseId] ~= nil
end

return ReceiptStore
