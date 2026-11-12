local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.FolderName = "Remotes"

Remotes.ClientEvents = {
	"RequestCapture",
	"RequestPlaceBoo",
	"RequestStoreBoo",
	"RequestSellBoo",
	"RequestSteal",
	"RequestTrain",
	"RequestRebirth",
	"RequestDaily",
	"RequestCarousel",
	"RequestUsePower",
	"RequestUseScare",
	"ToggleBaseGate",
	"RequestUpgradeBase",
	"RequestUpgradeTrack",
	"RequestUpgradePedestal",
	"RequestPunch",
	"UpdateSettings",
}

Remotes.ServerEvents = {
	"ReplicateEffect",
	"DataUpdated",
	"Notify",
}

Remotes.Functions = {
	"GetShopCatalog",
}

Remotes.StudioOnly = {
	"StudioGrant",
}

function Remotes.get(name: string): Instance
	local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName)
	local remote = folder:WaitForChild(name, 15)
	assert(remote, "Remote não encontrado: " .. name)
	return remote
end

return Remotes
