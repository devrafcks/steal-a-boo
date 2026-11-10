--[[
	Leaderboards.luau — ranking global com OrderedDataStore (não usa ProfileStore).
	- Grava TotalCash e Rebirths no leave e a cada LeaderboardPushSeconds.
	- Lê o top 10 a cada LeaderboardRefreshSeconds e escreve nos painéis da praça
	  e em ReplicatedStorage.LeaderboardData (JSON) para o botão do HUD.
	- Sem API Services no Studio: mostra "Ranking indisponível no Studio" e segue.
]]
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)

local Leaderboards = {}

local ctx
local cashStore, rebirthStore
local available = true
local nameCache: { [number]: string } = {}
local dataValue: StringValue

local function getName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		nameCache[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = ok and name or ("Jogador " .. userId)
	return nameCache[userId]
end

function Leaderboards.push(player: Player)
	if not available then
		return
	end
	local data = ctx.PlayerData.data(player)
	if not data then
		return
	end
	local cash = math.floor(data.TotalCash)
	local rebirths = data.Rebirths
	local key = tostring(player.UserId)
	task.spawn(function()
		pcall(cashStore.SetAsync, cashStore, key, cash)
		pcall(rebirthStore.SetAsync, rebirthStore, key, rebirths)
	end)
end

local function readTop(store): { { name: string, value: number } }?
	local ok, pages = pcall(store.GetSortedAsync, store, false, 10)
	if not ok then
		return nil
	end
	local rows = {}
	for _, entry in ipairs(pages:GetCurrentPage()) do
		table.insert(rows, { name = getName(tonumber(entry.key) or 0), value = entry.value })
	end
	return rows
end

local function writeBoard(board: Instance?, rows, prefix: string)
	if not board then
		return
	end
	local label = board:FindFirstChild("BoardGui") and board.BoardGui:FindFirstChild("Rows")
	if not label then
		return
	end
	if not rows then
		label.Text = "Ranking indisponível\n(ligue API Services)"
		return
	end
	local lines = {}
	for i, r in ipairs(rows) do
		table.insert(lines, string.format("%d. %s  —  %s%s", i, r.name, prefix, Format.compact(r.value)))
	end
	label.Text = #lines > 0 and table.concat(lines, "\n") or "Ninguém ainda. Seja o primeiro!"
end

local function refresh()
	local cashRows = available and readTop(cashStore) or nil
	local rebirthRows = available and readTop(rebirthStore) or nil
	local plaza = Workspace.StealABooWorld.Plaza
	writeBoard(plaza:FindFirstChild("CashBoard"), cashRows, "$")
	writeBoard(plaza:FindFirstChild("RebirthBoard"), rebirthRows, "")
	dataValue.Value =
		HttpService:JSONEncode({ cash = cashRows or {}, rebirths = rebirthRows or {}, available = cashRows ~= nil })
end

function Leaderboards.init(c)
	ctx = c
	dataValue = Instance.new("StringValue")
	dataValue.Name = "LeaderboardData"
	dataValue.Value = "{}"
	dataValue.Parent = ReplicatedStorage

	local ok = pcall(function()
		cashStore = DataStoreService:GetOrderedDataStore(Config.DataStore.OrderedCash)
		rebirthStore = DataStoreService:GetOrderedDataStore(Config.DataStore.OrderedRebirths)
		cashStore:GetSortedAsync(false, 1)
	end)
	if not ok then
		available = false
		warn("[Leaderboards] OrderedDataStore indisponível (Studio sem API Services?). Ranking desligado.")
	end

	ctx.PlayerData.Releasing:Connect(function(player)
		Leaderboards.push(player)
	end)

	task.spawn(function()
		local pushTimer = 0
		while true do
			refresh()
			local wait = Config.DataStore.LeaderboardRefreshSeconds
			task.wait(wait)
			pushTimer += wait
			if pushTimer >= Config.DataStore.LeaderboardPushSeconds then
				pushTimer = 0
				for _, p in Players:GetPlayers() do
					Leaderboards.push(p)
				end
			end
		end
	end)
end

return Leaderboards
