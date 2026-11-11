--[[
	StudioTests.luau — cenários de teste que rodam DENTRO do servidor real, só no Studio.

	Só é carregado pelo StudioGrant (remote que nem existe em produção) e checa RunService:IsStudio()
	de novo. Existe porque com um único jogador no Studio não dá para testar o combate: aqui criamos
	"jogadores falsos" (bonecos simples) para socar e tomar o Boo, e imprimimos o resultado no Output
	com o prefixo [StudioTests].

	Cenários: "combat" (soco, nocaute, prioridade do dono) e "take" (tomar o Boo de volta).
]]
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local StudioTests = {}

local function say(text: string)
	print("[StudioTests] " .. text)
end

-- "Jogador" falso: só o necessário para as funções de combate (Character, UserId, nomes)
local function mockPlayer(near: Vector3, userId: number, name: string)
	local model = Instance.new("Model")
	model.Name = name
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = true
	root.Size = Vector3.new(2, 2, 1)
	root.Position = near
	root.Parent = model
	model.Parent = Workspace
	return { UserId = userId, DisplayName = name, Name = name, Character = model, Parent = nil }
end

local function cleanup(...)
	for _, p in { ... } do
		p.Character:Destroy()
	end
end

local FAKE_OWNER_ID = 777000777

-- leva o jogador para FORA da própria base (dentro dela, a entrega do roubo conclui na hora)
local function stepOutside(player: Player)
	player.Character:PivotTo(CFrame.new(Vector3.new(-90, 4, 45)))
	task.wait(0.5)
end

function StudioTests.run(ctx, player: Player, scenario: string)
	if not RunService:IsStudio() then
		return
	end
	local Boos = ctx.Boos
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	if scenario == "combat" then
		stepOutside(player)
		Boos.studioCarry(player, "CometBoo")
		task.wait(0.4)
		say("carregando Boo roubado: " .. tostring(Boos.isCarrying(player)) .. " (esperado true)")
		say(
			"marcador LADRÃO: "
				.. tostring(player.Character:FindFirstChild("ThiefMarker") ~= nil)
				.. " (esperado true)"
		)

		local puncher = mockPlayer(root.Position + Vector3.new(3, 0, 0), 555, "Defensor")
		local _, _, proot = ctx.Net.alive(puncher)
		say(
			string.format(
				"diag: puncher vivo=%s dist=%.1f isFrozen=%s spawnSafe(ladrão)=%s",
				tostring(proot ~= nil),
				proot and (proot.Position - root.Position).Magnitude or -1,
				tostring(ctx.Character.isFrozen(puncher)),
				tostring(ctx.Character.isSpawnSafe(player))
			)
		)
		for i = 1, 3 do
			-- o defensor acompanha o ladrão (o empurrão afasta um pouco)
			puncher.Character.HumanoidRootPart.Position = player.Character.HumanoidRootPart.Position
				+ Vector3.new(4, 0, 0)
			Boos.punch(puncher)
			say(
				string.format(
					"soco %d -> ainda carregando: %s (esperado %s)",
					i,
					tostring(Boos.isCarrying(player)),
					tostring(i < 3)
				)
			)
			task.wait(ctx.Config.Combat.Punch.cooldown + 0.15)
		end
		local dropped
		for _, m in Workspace.StealABooWorld.DroppedBoos:GetChildren() do
			dropped = m
		end
		say(
			"Boo caiu no chão: "
				.. tostring(dropped ~= nil)
				.. " (esperado true), dono "
				.. tostring(dropped and dropped:GetAttribute("FromUserId"))
		)
		say("ladrão atordoado: " .. tostring(ctx.Character.isFrozen(player)) .. " (esperado true)")
		say(
			"marcador removido: "
				.. tostring(player.Character:FindFirstChild("ThiefMarker") == nil)
				.. " (esperado true)"
		)
		cleanup(puncher)
	elseif scenario == "take" then
		stepOutside(player)
		Boos.studioCarry(player, "MoonBoo")
		task.wait(0.4)
		local stranger = mockPlayer(root.Position + Vector3.new(2, 0, 0), 888, "Estranho")
		local owner = mockPlayer(root.Position + Vector3.new(-2, 0, 0), FAKE_OWNER_ID, "DonoOriginal")
		Boos.takeFromCarrier(stranger, player)
		say(
			"estranho SEM base tenta tomar -> ainda carregando: "
				.. tostring(Boos.isCarrying(player))
				.. " (esperado true)"
		)
		Boos.takeFromCarrier(owner, player)
		say("dono original toma de volta -> carregando: " .. tostring(Boos.isCarrying(player)) .. " (esperado false)")
		say(
			"CarriedBoo removido: "
				.. tostring(player.Character:FindFirstChild("CarriedBoo") == nil)
				.. " (esperado true)"
		)
		say(
			"marcador removido: "
				.. tostring(player.Character:FindFirstChild("ThiefMarker") == nil)
				.. " (esperado true)"
		)
		cleanup(stranger, owner)
	elseif scenario == "floors" then
		local data = ctx.PlayerData.data(player)
		data.BaseLevel = #ctx.Config.Plot.Floors
		ctx.Plots.renderFloors(player)
		ctx.Plots.renderSlots(player)
		local plot = ctx.Plots.getPlot(player)
		local built = {}
		for f = 2, #ctx.Config.Plot.Floors do
			table.insert(built, plot:FindFirstChild("Level_" .. f) and "ok" or "FALTA")
		end
		say("andares 2..6: " .. table.concat(built, ","))
		say(
			"slots liberados: "
				.. ctx.Plots.unlockedCount(player)
				.. " (esperado "
				.. ctx.Config.Plot.MaxSlots
				.. " com passes)"
		)
		say("próximo andar: " .. tostring(ctx.Plots.nextFloor(player)) .. " (esperado nil)")
		ctx.PlayerData.markDirty(player)
	end
end

return StudioTests
