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

<p align="center">
  <img src="assets/screenshots/overview.png" alt="Visão geral do parque" width="860">
</p>

---

## Sumário

- [Sobre o jogo](#sobre-o-jogo)
- [Galeria](#galeria)
- [Loop principal](#loop-principal)
- [Funcionalidades](#funcionalidades)
- [Controles](#controles)
- [Upgrades e combate](#upgrades-e-combate)
- [Balanceamento](#balanceamento)
- [Stack e arquitetura](#stack-e-arquitetura)
- [Como rodar](#como-rodar)
- [Testando no Studio](#testando-no-studio)
- [Configuração única](#configuração-única)
- [Monetização](#monetização)
- [CI/CD](#cicd)
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

## Galeria

| Praça central | Base com andares |
| --- | --- |
| <img src="assets/screenshots/plaza.png" alt="Praça" width="420"> | <img src="assets/screenshots/base.png" alt="Base" width="420"> |
| **Feirinha (zona de captura)** | **Tenda Secreta** |
| <img src="assets/screenshots/zone.png" alt="Zona" width="420"> | <img src="assets/screenshots/tent.png" alt="Tenda" width="420"> |

## Loop principal

1. **Treine** Speed (esteira) e Throw Power (alvo) na praça pagando Cash.
2. **Capture** Boos nas zonas. Zonas mais longe exigem mais status e têm Boos mais raros.
3. **Coloque** os Boos nos slots da sua base. Cada um gera Cash por segundo, que cai no cofre.
4. **Colete** o cofre pisando no pad dourado (ele tem limite: cheio, a renda para) e **construa andares** (até o 6º).
5. **Evolua** a base: Laboratório (Gerador, Cofre, Sorte, Segurança) e o pedestal de cada slot (tecla F).
6. **Roube** Boos de bases com o portão aberto e corra de volta para a sua.
7. **Defenda**: tranque o portão, use alarme, isca, slap, freeze e sustos, ou **soque o ladrão** (Q) e **tome o Boo de volta**.
8. **Rebirth** para multiplicar a renda para sempre.
9. **Volte todo dia** para o Daily e suba no ranking global.

## Funcionalidades

- 16 Boos originais em 7 raridades (Comum a Secreto), feitos só com primitivas
- Mapa gerado por código: terreno de grama com lago, morros e mata, praça, 8 bases e 4 zonas temáticas
- Bases com até 6 andares (52 slots), elevadores de pisar, cofre com limite e esteira de coleta
- Laboratório com 4 trilhas de upgrade e pedestais evolutivos por slot (níveis 1 a 10)
- Combate ao ladrão: socos, pegada, nocaute, tomar o Boo de volta e marcador "LADRÃO"
- Esteiras pagas 2x, 3x e 4x de renda por 2 minutos
- Céu noturno com lua, estrelas, nuvens rosadas e fogos de artifício
- Texturas originais geradas no Studio e modelos 3D gratuitos do Creator Store
- Efeitos sonoros e música licenciados (ProSoundEffects, APM e Roblox)
- Save com ProfileStore (session lock, Reconcile, BindToClose, mock no Studio)
- Roubo com carga visível, penalidade de velocidade, queda do Boo e retorno ao dono
- Proteção de novatos e regra do último Boo
- 9 consumíveis: Speed Rush, Super Jump, Invisibilidade, Slap, Freeze, Susto Clássico,
  Susto Festa, Boo Isca e Alarme da Base
- Opção "Reduzir sustos" para quem não curte o overlay
- Rebirth, Daily com sequência de 7 dias, ranking global com OrderedDataStore
- Loja com abas, 23 dev products e 5 gamepasses, todos lidos do `Config.luau`
- CI/CD no GitHub Actions: lint, testes, simulação de balanceamento, build e publicação na Roblox
- `ProcessReceipt` único e idempotente por `PurchaseId`
- Server Luck compartilhado com banner para todo o servidor
- Rate limit em todos os remotes e validação de distância, dono, cooldown e estado
- UI responsiva para celular e PC, tutorial de 4 passos na primeira sessão

## Controles

| Tecla / botão | Ação |
| --- | --- |
| WASD e espaço | Andar e pular |
| E (segurar) | Capturar, treinar, colocar, guardar ou roubar um Boo; tomar o Boo da mão de um ladrão |
| F | Evoluir o pedestal do Boo da sua base (custo aparece no prompt) |
| Q ou botão Bater | Socar o ladrão mais perto que esteja carregando um Boo roubado |
| 1 a 9 | Usar poderes e sustos da hotbar |
| L, B | Abrir a Loja, abrir a Bolsa |
| Pisar no pad dourado | Coletar o cofre |
| Pisar nos pads azul e laranja | Subir e descer de andar |

## Upgrades e combate

**Laboratório** (botão Lab no HUD). Cada trilha tem custo `baseCost x growth^nível`, pago com Cash do jogo:

| Trilha | Efeito por nível | Máx. |
| --- | --- | --- |
| Gerador | +8% de renda | 20 |
| Cofre | guarda +45s de renda | 15 |
| Sorte | +4% de chance de um sorteio extra com 3x de sorte | 15 |
| Segurança | roubar demora +0,12s, +1 de pegada a cada 2 níveis, portão trancado +3s | 10 |

**Pedestal**: cada slot evolui separado (tecla F perto do Boo), +25% de renda por nível até o 10 (x3,25).
O nível fica no slot: se o Boo for roubado ou guardado, o pedestal continua evoluído.

**Cofre com limite**: a renda guarda no máximo `segundos do cofre x renda por segundo`. Cheio, para de render
até você coletar (a cor do texto no HUD avisa). O passe **Coleta Automática** passa o cofre sozinho a cada 6s.

**Defesa contra o ladrão**:
1. Quem rouba fica com contorno vermelho e a etiqueta "LADRÃO!" visível através das paredes.
2. Qualquer jogador pode **socar** (Q): cada soco tira 1 de pegada (3 + Segurança do dono). Zerou, o Boo cai e o ladrão fica 1s atordoado.
3. Qualquer jogador pode **tomar** o Boo da mão do ladrão (segurar E por 1,2s). Se for o dono, o Boo volta direto para a base; se for outro jogador, ele passa a levar o Boo para a base dele.
4. Boo derrubado: só o dono pega nos primeiros 2,5s; depois qualquer um pode; em 10s sem ninguém, volta para o dono.
5. Os poderes continuam valendo: Slap, Freeze, Susto, Isca e Alarme.

## Balanceamento

O jogo ficou propositalmente mais lento e difícil: treino de +0,15 por vez com custo 1,045^n, zonas que pedem
mais status (8, 16 e 30), raros bem mais raros, andares até 20 bilhões e upgrades que somam centenas de milhões.
O simulador [`tools/balance/sim.js`](tools/balance/sim.js) lê o `Config.luau` e joga como um jogador **gratuito, ativo e
eficiente** (compra sempre o melhor retorno). Jogadores reais são mais lentos que isso.

```bash
node tools/balance/sim.js 100
```

| Marco | Tempo do jogador ideal |
| --- | --- |
| Corredor das Barracas (status 8) | 8 min |
| Terreno da Lua (status 16) | 20 min |
| 2º andar | 24 min |
| 3º andar e Tenda Secreta (status 30) | 1,1 h |
| 4º andar | 1,5 h |
| 1º Boo Secreto | 2,2 h |
| 5º andar | 4,5 h |
| 6º andar | cerca de 54 h |

Quer mudar o ritmo? Mexa no `Config.luau`, rode o simulador e o teste (`lune run tests/config-check`).

## Stack e arquitetura

| Ferramenta | Uso |
| --- | --- |
| [Rokit](https://github.com/rojo-rbx/rokit) | Instala as ferramentas nas versões do `rokit.toml` |
| [Rojo 7](https://rojo.space/docs/v7/) | Sincroniza `src/` com o Studio |
| [Wally](https://wally.run) | Gerenciador de pacotes (ProfileStore) |
| [ProfileStore](https://madstudioroblox.github.io/ProfileStore/) | Save de jogador com session lock |
| [Selene](https://github.com/Kampfkarren/selene) e [StyLua](https://github.com/JohnnyMorganz/StyLua) | Lint e formatação |
| [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) | Análise estática |
| [Lune](https://lune-org.github.io/docs) | Teste do `Config.luau` fora do Studio |
| GitHub Actions | CI (lint, testes, build) e deploy para a Roblox |

```
steal-a-boo/
  default.project.json        mapeamento Rojo
  rokit.toml  wally.toml      ferramentas e pacotes
  assets/                     logo, capturas, arte da loja e CREDITS.md
  tests/                      teste do Config (Lune)
  tools/                      gerador da arte da loja e simulador de balanceamento
  .github/workflows/          ci.yml e deploy.yml
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
      Systems/                Plot, Boo, Character, Training, Combat, Rebirth, Upgrade,
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
- **Salve o place (Ctrl+S):** os modelos do Creator Store (`ServerStorage.ExternalAssets`), os materiais e a graminha 3D do terreno (`Terrain.Decoration`) ficam guardados no arquivo do place.
- **Rojo e materiais:** se o `MaterialService` não sincronizar, pare e rode `rojo serve` de novo e reconecte o plugin (o projeto passou a mapear `src/materials`).
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
| `ExtraSlots` | +4 Base Slots | 199 | Quatro slots extras permanentes no térreo. |
| `AutoCollect` | Coleta Automática | 149 | O cofre da base passa sozinho para o Cash. |
| `VIP` | VIP | 249 | Tag VIP, aura, +10% Cash e +2 slots no térreo. |

### Developer Products

| Chave no Config | Nome | Preço (R$) | Entrega |
| --- | --- | --- | --- |
| `Sale50` | Promoção de Upgrades (10 min) | 59 | Upgrades, pedestais e andares pela metade do preço |
| `Belt2x` | Esteira 2x (2 min) | 15 | Renda dos Boos em dobro por 2 min |
| `Belt3x` | Esteira 3x (2 min) | 25 | Renda triplicada por 2 min |
| `Belt4x` | Esteira 4x (2 min) | 39 | Renda quadruplicada por 2 min |
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
| `CashS` | Saco de Cash | 29 | +8.000 Cash |
| `CashM` | Baú de Cash | 79 | +40.000 Cash |
| `CashL` | Cofre de Cash | 149 | +120.000 Cash |
| `CashXL` | Tesouro de Cash | 299 | +400.000 Cash |

### IDs criados na Roblox

Todos os produtos e passes foram criados via Open Cloud (MCP do Studio) com ícone próprio
(`assets/store`) e já estão no `Config.luau`.

| Chave | ID |
| --- | --- |
| `Belt2x` | 3730282380 |
| `Belt3x` | 3730282412 |
| `Belt4x` | 3730282417 |
| `Luck2x15` | 3730282423 |
| `Luck4x15` | 3730282426 |
| `Luck8x15` | 3730282434 |
| `Cash2x15` | 3730282437 |
| `LuckyThrows5` | 3730282442 |
| `LuckyThrows10` | 3730282448 |
| `SpeedRush3` | 3730282454 |
| `Invis1` | 3730282460 |
| `SuperJump3` | 3730282467 |
| `Slap3` | 3730282471 |
| `Freeze1` | 3730282478 |
| `ScareClassic3` | 3730282482 |
| `ScareParty1` | 3730282488 |
| `DecoyBoo1` | 3730282493 |
| `BaseAlarm1` | 3730282505 |
| `CashS` | 3730282513 |
| `CashM` | 3730282521 |
| `CashL` | 3730282529 |
| `DoubleCash` | 2079530254 |
| `DoubleTraining` | 2079356260 |
| `VIP` | 2079656255 |
| `ExtraSlots` | 2079332259 |

### Como o recibo é processado

`src/server/Monetization/ProcessReceipt.luau` é o único lugar que define
`MarketplaceService.ProcessReceipt`. Ele procura o produto pelo `ProductId` no Config
(ID `0` nunca bate), devolve `NotProcessedYet` se o jogador não estiver no servidor ou o
perfil não tiver carregado, entrega e grava o `PurchaseId` no perfil no mesmo passo, pede um
save imediato e só devolve `PurchaseGranted` quando o DataStore confirma. Se o mesmo recibo
voltar, o `PurchaseId` já gravado impede a entrega dupla.

## CI/CD

Dois workflows em `.github/workflows`:

| Workflow | Quando roda | O que faz |
| --- | --- | --- |
| `ci.yml` | Todo push e pull request | StyLua, Selene, teste do Config, simulação de balanceamento, `wally install` e `rojo build` (guarda o `.rbxl` como artefato) |
| `deploy.yml` | Push na `main` que mude `src/`, o projeto Rojo ou os pacotes, ou manual | Repete as validações (IDs zerados viram aviso e a loja mostra "Em breve"), gera o place e publica via Open Cloud |

Sem o secret abaixo o deploy só valida e gera o place, e avisa que **não publicou**.

**Ligar a publicação automática (uma vez):**

1. Abra [create.roblox.com/dashboard/credentials](https://create.roblox.com/dashboard/credentials) e clique em **Create API Key**.
2. Nome: `github-deploy`. Em **Access Permissions** adicione **Place Publishing** (`universe-places`), escolha o jogo
   **Steal a Boo!** e marque a operação **Write**. Para reiniciar servidores depois do deploy, adicione também **Universe**
   com **Write**.
3. Em **Accepted IP Addresses** use `0.0.0.0/0` (os IPs do GitHub Actions mudam) e crie a chave. Copie o valor (ele só aparece uma vez).
4. No GitHub: repositório > **Settings > Secrets and variables > Actions > New repository secret**. Nome `ROBLOX_API_KEY`, valor a chave.
5. (Opcional) Em **Variables**, crie `RESTART_SERVERS` = `true` para reiniciar os servidores a cada deploy.
   Isso expulsa quem está jogando, por isso vem desligado. Também dá para marcar a opção ao rodar o workflow à mão.

**Importante:** o repositório é a fonte da verdade. A publicação substitui o conteúdo do place pelo que o Rojo gera, então
edições feitas só no Studio e nunca commitadas se perdem. Os modelos 3D gratuitos são carregados por ID (`Config.ExternalAssets`)
e os materiais ficam em `src/materials`.

## Checklist humano para publicar

1. Instalar o Roblox Studio atualizado e o Claude Code. Ligar o MCP do Studio
   (Assistant > MCP Servers > Enable Studio as MCP server) e o plugin Rojo.
2. Publicar o place pela primeira vez (File > Publish to Roblox) e anotar abaixo:
   - Universe ID: `10775759574`
   - Place ID: `127475605109985`
3. Game Settings > Security > Enable Studio Access to API Services.
4. Game Settings > Places > Max Players: **8** (o número de plots).
5. Creator Dashboard > Monetization > Developer Products: criar cada item da tabela acima
   com o mesmo nome e preço, ícone 512x512, e colar o ID em `Config.Products.<chave>.id`.
6. Monetization > Passes: criar os 5 gamepasses com o mesmo nome e preço e colar os IDs em
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
| Requisito das zonas | `minStat` compara com o **maior** entre Speed e Throw Power. Speed vai até 16 (WalkSpeed 32), então a Tenda Secreta (30) exige Throw. |
| Portão | Começa aberto. O dono tranca por `GateLockSeconds` (40s) e depois o portão fica aberto pelo menos `GateOpenSeconds` (20s). Trancado, intrusos são expulsos e ninguém rouba. `GateCooldownSeconds` ficou só informativo (soma dos dois). |
| Server Luck | Afeta só sorteios (spawn, captura, carrossel), não a renda. Vence o maior multiplicador ativo e cada compra mantém o próprio tempo. |
| Sorte | Multiplica o peso das raridades Rare para cima. Comuns não mudam. |
| Cofre | A renda vai para o cofre da base e só vira Cash quando o dono pisa no pad dourado. O Cash vitalício do ranking conta na coleta. |
| Andares | Térreo com 12 slots (6 livres, 4 do passe ExtraSlots, 2 do VIP). Do 2º ao 6º andar custam 10K, 400K, 12M, 500M e 20B e têm 8 slots cada. Rebirth não derruba andares, upgrades nem pedestais. |
| Esteiras pagas | Vale o maior multiplicador ativo. Comprar de novo soma 2 minutos. |
| Boo inicial | O jogador novo começa com um MarshBoo já colocado no slot 1. |
| Custo do treino | Cresce 4,5% por treino feito (1,045^n). Chegar na Tenda Secreta (Throw 30) custa milhões de propósito. |
| Pedestal | Nível guardado no slot, não no Boo: roubar ou guardar o Boo não apaga o investimento do dono. |
| Promoção | Divide por 2 upgrades, pedestais e andares. Não afeta treino, rebirth nem carrossel. |
| Monetização | O jogo é gratuito e dá para terminar sem pagar, só que bem mais devagar. As compras aceleram (Cash, Promoção, esteiras, sorte) e a Coleta Automática tira o trabalho de voltar à base. Nenhum item pago sorteia prêmio com Robux. |
| Combate | Só dá para socar ou tomar o Boo de quem está carregando um roubado. Não existe soco entre jogadores normais. O soco funciona também na praça; poderes e sustos continuam proibidos lá. |
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
