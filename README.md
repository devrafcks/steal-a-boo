<p align="center">
  <img src="assets/logo.svg" alt="Steal a Boo!" width="560">
</p>

<p align="center">
  <img alt="Plataforma" src="https://img.shields.io/badge/plataforma-Roblox-00A2FF?style=for-the-badge&logo=roblox&logoColor=white">
  <img alt="Linguagem" src="https://img.shields.io/badge/Luau-puro-2C2D72?style=for-the-badge&logo=lua&logoColor=white">
  <img alt="Rojo" src="https://img.shields.io/badge/Rojo-7.6.1-E13835?style=for-the-badge">
  <img alt="Wally" src="https://img.shields.io/badge/Wally-0.3.2-AD3CE0?style=for-the-badge">
  <img alt="ProfileStore" src="https://img.shields.io/badge/ProfileStore-1.0.3-F5A623?style=for-the-badge">
  <img alt="Status" src="https://img.shields.io/badge/status-MVP-4CC38A?style=for-the-badge">
</p>

<p align="center">
  Simulator social de coleta e roubo numa feira noturna. Capture Boos, monte sua base,
  gere Cash por segundo, roube dos amigos e defenda o que é seu.
</p>

---

## Sumário

- [Sobre o jogo](#sobre-o-jogo)
- [Loop principal](#loop-principal)
- [Funcionalidades](#funcionalidades)
- [Stack e arquitetura](#stack-e-arquitetura)
- [Como rodar](#como-rodar)
- [Testando no Studio](#testando-no-studio)
- [Configuração única](#configuração-única)
- [Monetização](#monetização)
- [Checklist humano para publicar](#checklist-humano-para-publicar)
- [Decisões de design](#decisões-de-design)
- [Convenção de commits](#convenção-de-commits)
- [Créditos](#créditos)

## Sobre o jogo

| | |
| --- | --- |
| Gênero | Simulator social, collect and steal |
| Sessão alvo | 10 a 15 minutos |
| Público | Todas as idades, tom fofo e cômico (feira iluminada, nada de terror) |
| Jogadores por servidor | 8 (um plot para cada) |

Você chega num parque colorido. No centro fica a praça neutra com loja, estações de treino,
baú diário, carrossel e rankings. Em volta, oito bases iguais. A leste e a oeste, quatro zonas
de captura que pedem cada vez mais Speed ou Throw Power.

## Loop principal

1. **Treine** Speed (esteira) e Throw Power (alvo) na praça pagando Cash.
2. **Capture** Boos nas zonas. Zonas mais longe exigem mais status e têm Boos mais raros.
3. **Coloque** os Boos nos slots da sua base. Cada um gera Cash por segundo.
4. **Roube** Boos de bases com o portão aberto e corra de volta para a sua.
5. **Defenda** trancando o portão, usando alarme, isca, slap, freeze e sustos cômicos.
6. **Rebirth** para multiplicar a renda para sempre.
7. **Volte todo dia** para o Daily e suba no ranking global.

## Funcionalidades

- 16 Boos originais em 7 raridades (Comum a Secreto), feitos só com primitivas
- Mapa gerado por código: praça, 8 bases com 16 slots e mezanino, 4 zonas temáticas
- Save com ProfileStore (session lock, Reconcile, BindToClose, mock no Studio)
- Roubo com carga visível, penalidade de velocidade, queda do Boo e retorno ao dono
- Proteção de novatos e regra do último Boo
- 9 consumíveis: Speed Rush, Super Jump, Invisibilidade, Slap, Freeze, Susto Clássico,
  Susto Festa, Boo Isca e Alarme da Base
- Opção "Reduzir sustos" para quem não curte o overlay
- Rebirth, Daily com sequência de 7 dias, ranking global com OrderedDataStore
- Loja com abas, 18 dev products e 4 gamepasses, todos lidos do `Config.luau`
- `ProcessReceipt` único e idempotente por `PurchaseId`
- Server Luck compartilhado com banner para todo o servidor
- Rate limit em todos os remotes e validação de distância, dono, cooldown e estado
- UI responsiva para celular e PC, tutorial de 4 passos na primeira sessão

## Stack e arquitetura

| Ferramenta | Uso |
| --- | --- |
| [Rokit](https://github.com/rojo-rbx/rokit) | Instala as ferramentas nas versões do `rokit.toml` |
| [Rojo 7](https://rojo.space/docs/v7/) | Sincroniza `src/` com o Studio |
| [Wally](https://wally.run) | Gerenciador de pacotes (ProfileStore) |
| [ProfileStore](https://madstudioroblox.github.io/ProfileStore/) | Save de jogador com session lock |
| [Selene](https://github.com/Kampfkarren/selene) e [StyLua](https://github.com/JohnnyMorganz/StyLua) | Lint e formatação |
| [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) | Análise estática |

```
steal-a-boo/
  default.project.json        mapeamento Rojo
  rokit.toml  wally.toml      ferramentas e pacotes
  assets/                     logo e CREDITS.md
  src/
    shared/                   ReplicatedStorage.Shared
      Config.luau             o único arquivo de balance, IDs e preços
      Remotes.luau            lista nomeada de remotes (criados pelo servidor)
      BooModel.luau           monta os Boos com primitivas
      Types.luau
      Util/Format.luau        1.2K, 3.4M, mm:ss
      Util/Rarity.luau        sorteio ponderado por zona e sorte
    server/                   ServerScriptService.Server
      init.server.luau        bootstrap e contexto compartilhado
      Data/                   PlayerData (ProfileStore) e Leaderboards
      Monetization/           ProcessReceipt, Products, GamePasses, ReceiptStore
      Systems/                Plot, Boo, Character, Training, Combat, Rebirth,
                              DailyReward, Shop, AntiExploit, WorldBuilder
    client/                   StarterPlayerScripts.Client
      init.client.luau
      Controllers/            UIController, HUD, Panels, ShopUI,
                              EffectsController, InputController, State
```

O servidor é a autoridade. O cliente só envia pedidos (`RequestCapture`, `RequestSteal`,
`RequestUsePower` e afins) e recebe um snapshot leve (`DataUpdated`) e efeitos já
autorizados (`ReplicateEffect`). Não existe nenhum remote que conceda dinheiro ou itens.

## Como rodar

Pré-requisitos: Roblox Studio atualizado e [Rokit](https://github.com/rojo-rbx/rokit) instalado.

```bash
rokit install
```

```bash
wally install
```

```bash
rojo serve
```

No Studio, abra um place vazio, vá em **Plugins > Rojo > Connect**. O mapa é montado
sozinho quando você aperta **Play** (o `WorldBuilder` só constrói se não existir
`Workspace.StealABooWorld`).

Para gerar um arquivo de place sem o Studio aberto:

```bash
rojo build -o build/steal-a-boo.rbxl
```

Qualidade de código:

```bash
selene src
```

```bash
stylua src
```

## Testando no Studio

- **Save de verdade:** Game Settings > Security > *Enable Studio Access to API Services*.
  Sem isso o jogo usa um save em memória e avisa no Output e na tela.
- **Loja sem cobrar:** com IDs em `0`, cada item mostra *Configure o ID no Config* e um botão
  *Testar grátis (Studio)*. Ele usa o remote `StudioGrant`, que só é criado quando
  `RunService:IsStudio()` é verdadeiro e por isso não existe em produção.
- **Dois jogadores:** Test > Clients and Servers > 2 Players para testar roubo, slap e sustos.

## Configuração única

Tudo que você precisa mexer está em [`src/shared/Config.luau`](src/shared/Config.luau):
IDs, preços, balance da economia, Boos, zonas, poderes, sustos, rebirth, daily e sons.
A tabela é congelada em runtime. Mudou preço de produto Robux? Mude aqui e no Dashboard.

## Monetização

Nada passa de 249 Robux e a maior parte fica entre 19 e 79. Crie cada item no Creator
Dashboard com **exatamente** o nome e o preço abaixo e cole o ID no campo `id` do Config.

### Gamepasses

| Chave no Config | Nome | Preço (R$) | Descrição |
| --- | --- | --- | --- |
| `DoubleCash` | 2x Cash | 99 | Sua base gera o dobro de Cash para sempre. |
| `DoubleTraining` | 2x Training | 149 | Treino rende o dobro de Speed e Throw Power. |
| `ExtraSlots` | +4 Base Slots | 199 | Quatro slots extras permanentes na base. |
| `VIP` | VIP | 249 | Tag VIP, aura, +10% Cash e +2 slots na base. |

### Developer Products

| Chave no Config | Nome | Preço (R$) | Entrega |
| --- | --- | --- | --- |
| `Luck2x15` | Server Luck 2x (15 min) | 19 | Sorte 2x para o servidor |
| `Luck4x15` | Server Luck 4x (15 min) | 39 | Sorte 4x para o servidor |
| `Luck8x15` | Server Luck 8x (15 min) | 79 | Sorte 8x para o servidor |
| `Cash2x15` | 2x Cash pessoal (15 min) | 49 | Renda dobrada por 15 min |
| `LuckyThrows5` | 5 Super Lucky Captures | 39 | 5 capturas com sorte alta |
| `LuckyThrows10` | 10 Super Lucky Captures | 69 | 10 capturas com sorte alta |
| `SpeedRush3` | Speed Rush (3 usos) | 19 | 3 usos |
| `Invis1` | Invisibilidade (1 uso, 6s) | 29 | 1 uso |
| `SuperJump3` | Super Jump (3 usos) | 19 | 3 usos |
| `Slap3` | Boo Slap (3 usos) | 25 | 3 usos |
| `Freeze1` | Freeze (1 uso, 3s) | 49 | 1 uso |
| `ScareClassic3` | Susto Clássico (3 usos) | 19 | 3 usos |
| `ScareParty1` | Susto Festa (1 uso, área) | 39 | 1 uso |
| `DecoyBoo1` | Boo Isca (1 uso) | 29 | 1 uso |
| `BaseAlarm1` | Alarme da Base (1 uso, 60s) | 25 | 1 uso |
| `CashS` | Saco de Cash | 29 | +1.500 Cash |
| `CashM` | Baú de Cash | 79 | +6.000 Cash |
| `CashL` | Cofre de Cash | 149 | +15.000 Cash |

### Como o recibo é processado

`src/server/Monetization/ProcessReceipt.luau` é o único lugar que define
`MarketplaceService.ProcessReceipt`. Ele procura o produto pelo `ProductId` no Config
(ID `0` nunca bate), devolve `NotProcessedYet` se o jogador não estiver no servidor ou o
perfil não tiver carregado, entrega e grava o `PurchaseId` no perfil no mesmo passo, pede um
save imediato e só devolve `PurchaseGranted` quando o DataStore confirma. Se o mesmo recibo
voltar, o `PurchaseId` já gravado impede a entrega dupla.

## Checklist humano para publicar

1. Instalar o Roblox Studio atualizado e o Claude Code. Ligar o MCP do Studio
   (Assistant > MCP Servers > Enable Studio as MCP server) e o plugin Rojo.
2. Publicar o place pela primeira vez (File > Publish to Roblox) e anotar abaixo:
   - Universe ID: `preencher`
   - Place ID: `preencher`
3. Game Settings > Security > Enable Studio Access to API Services.
4. Game Settings > Places > Max Players: **8** (o número de plots).
5. Creator Dashboard > Monetization > Developer Products: criar cada item da tabela acima
   com o mesmo nome e preço, ícone 512x512, e colar o ID em `Config.Products.<chave>.id`.
6. Monetization > Passes: criar os 4 gamepasses com o mesmo nome e preço e colar os IDs em
   `Config.GamePasses.<chave>.id`.
7. Conferir que não sobrou `id = 0` nos itens que devem aparecer na loja.
8. (Opcional) Monetization > Shop: marcar produtos e passes como Listed só depois de o
   `ProcessReceipt` estar publicado e testado.
9. Testar compras no Studio (modo de teste da Roblox) ou com produtos a 1 R$ numa cópia de
   teste. Confirmar entrega, toast, persistência depois de sair e entrar, e que o mesmo
   recibo não entrega duas vezes.
10. Ícone, thumbnail, descrição e tags do jogo em pt-BR e inglês curto, sem citar outros
    jogos e sem prometer admin ou Robux grátis.
11. Responder o questionário de classificação etária com honestidade (sustos cômicos leves).
12. Publicar, ativar e fazer um playtest com 2 contas (roubo e compra).
13. Depois do lançamento: usar `[UPD]` no título quando houver conteúdo novo e acompanhar
    Analytics > Developer Products.

Prefere que o agente crie os produtos? Libere MCP Permissions > Money & monetization no
place publicado, peça explicitamente e desligue a permissão depois.

## Decisões de design

| Tema | Decisão |
| --- | --- |
| Requisito das zonas | `minStat` compara com o **maior** entre Speed e Throw Power. Speed vai até 16 (WalkSpeed 32), então a Tenda Secreta (24) exige Throw. |
| Portão | Começa aberto. O dono tranca por `GateLockSeconds` (40s) e depois o portão fica aberto pelo menos `GateOpenSeconds` (20s). Trancado, intrusos são expulsos e ninguém rouba. `GateCooldownSeconds` ficou só informativo (soma dos dois). |
| Server Luck | Afeta só sorteios (spawn, captura, carrossel), não a renda. Vence o maior multiplicador ativo e cada compra mantém o próprio tempo. |
| Sorte | Multiplica o peso das raridades Rare para cima. Comuns não mudam. |
| Custo do treino | Crescimento de 1.06 por treino (1.12 travava a progressão na Tenda Secreta). |
| Invisibilidade | Não dá para começar um roubo nem ficar invisível carregando um Boo. |
| Slap | O servidor valida e o cliente do alvo aplica o empurrão (ele é dono da física do próprio boneco). O efeito importante, soltar o Boo, é do servidor. |
| Novatos | Na primeira sessão ninguém rouba a pessoa por 2 minutos, e ninguém rouba o último Boo de uma base. |
| Daily | Dia contado em UTC (`floor(os.time() / 86400)`). |
| Sons | Todos em `0` até haver IDs licenciados. O jogo funciona em silêncio. |

## Convenção de commits

O histórico segue [Conventional Commits](https://www.conventionalcommits.org/pt-br/):
`feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `test`, com escopo quando ajuda
(`feat(boos): ...`). Mensagens em português, no imperativo e sem acentos no título.

## Créditos

Veja [`assets/CREDITS.md`](assets/CREDITS.md). Todo o visual é feito com primitivas e
materiais nativos da Roblox. Save por [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore),
de loleris / MAD STUDIO.
