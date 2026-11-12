local ReceiptStore = {}

local serverCache: { [string]: boolean } = {}

function ReceiptStore.has(data, purchaseId: string): boolean
	return serverCache[purchaseId] == true or (data and data.PurchaseIds[purchaseId] ~= nil)
end

function ReceiptStore.record(data, purchaseId: string)
	data.PurchaseIds[purchaseId] = os.time()
	serverCache[purchaseId] = true
end

function ReceiptStore.isSaved(profile, purchaseId: string): boolean
	local saved = profile.LastSavedData
	return saved ~= nil and saved.PurchaseIds ~= nil and saved.PurchaseIds[purchaseId] ~= nil
end

return ReceiptStore
