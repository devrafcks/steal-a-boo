--[[
	Remotes.luau — lista nomeada de todos os remotes.
	O SERVIDOR cria tudo (ver server/Systems/AntiExploit.luau). O cliente só espera e usa.
	Não existe nenhum remote do tipo "GiveCash": o cliente só PEDE ações; o servidor valida.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.FolderName = "Remotes"

-- Cliente -> Servidor (RemoteEvent, todos com rate limit)
Remotes.ClientEvents = {
	"RequestCapture", -- (booModel) captura um Boo da zona
	"RequestPlaceBoo", -- (booKey, slotIndex?) coloca do inventário na base
	"RequestStoreBoo", -- (slotIndex) guarda um Boo da base no inventário
	"RequestSellBoo", -- (booKey) vende um Boo do inventário
	"RequestSteal", -- (booModel) rouba um Boo de outra base
	"RequestTrain", -- ("Speed" | "Throw")
	"RequestRebirth", -- ()
	"RequestDaily", -- ()
	"RequestCarousel", -- () compra Boo surpresa com Cash
	"RequestUsePower", -- (powerKey)
	"RequestUseScare", -- (scareKey)
	"ToggleBaseGate", -- () tranca o portão da própria base
	"RequestUpgradeBase", -- () constrói o próximo andar da base
	"UpdateSettings", -- ({ReduceScares, MusicVolume})
}

-- Servidor -> Cliente (RemoteEvent)
Remotes.ServerEvents = {
	"ReplicateEffect", -- (effectName, payload) efeito visual já autorizado
	"DataUpdated", -- (snapshot) snapshot leve para o HUD
	"Notify", -- (text, kind) toast
}

-- RemoteFunctions
Remotes.Functions = {
	"GetShopCatalog",
}

-- Só existe dentro do Studio (o servidor nem cria em produção)
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
