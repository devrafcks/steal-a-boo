# Créditos e origem dos assets

Regra do projeto: nenhum mesh, textura, som, animação, ícone, nome ou código de outro jogo.
Tudo que não for primitiva do Studio está listado aqui com ID, autor e origem.

## Feito para este projeto

| Item | Origem |
| --- | --- |
| 16 Boos | Primitivas do Studio montadas em `src/shared/BooModel.luau` |
| Mapa, bases com 4 andares, zonas, carrossel, roda-gigante, tenda, balões, arbustos | Primitivas em `src/server/Systems/WorldBuilder.luau` e `PlotService.luau` |
| Terreno (grama, morros, lago) | `Terrain` gerado por código no `WorldBuilder` |
| UI, rosto do susto, fogos de artifício, esteiras animadas | Criados por código no cliente |
| Logo (`assets/logo.svg`) | Desenhado à mão |
| Fontes | `FredokaOne`, `LuckiestGuy`, `GothamBold` (fontes nativas da Roblox) |

## Materiais gerados (Roblox Studio Assistant, `generate_material`)

Gerados a partir de descrições originais e salvos em `src/materials/*.model.json`.

| MaterialVariant | Base | ColorMap | NormalMap | MetalnessMap | RoughnessMap |
| --- | --- | --- | --- | --- | --- |
| BooCandyPlanks | WoodPlanks | 71843591294002 | 103625364024698 | 112891402790413 | 82892406081727 |
| BooStarTiles | Pavement | 101196824472343 | 123902941798004 | 117637722671917 | 108335762801546 |
| BooTentStripes | Fabric | 96935710853660 | 125886466789648 | 130589785479313 | 123818459802065 |
| BooPeachCobble | Cobblestone | 138649069211098 | 103255826825710 | 93311703226550 | 81066546965095 |
| BooConveyor | Rubber | 114561853488161 | 120773771922199 | 131860847294669 | 92440669175346 |

## Modelos 3D gratuitos do Creator Store

Ficam em `ServerStorage.ExternalAssets` (dentro do arquivo do place). Os scripts que vieram
junto foram removidos e as peças foram ancoradas. Se a pasta não existir, o mapa usa versões
feitas com primitivas.

| Nome no jogo | Asset ID | Nome no Creator Store | Autor |
| --- | --- | --- | --- |
| Tree | 12549617200 | Low Poly Tree | Remadex Development |
| Bench | 393609716 | Park Bench | AeliteOfficial |
| PopcornCart | 1489187264 | Popcorn Cart | detonador665 |
| StringLights | 9320917020 | Cute Star String Lights | aka_TheCat |

## Áudio (Creator Store, bibliotecas licenciadas para experiências Roblox)

| Chave no Config | Asset ID | Nome | Publicador |
| --- | --- | --- | --- |
| Pop | 9112872244 | Small Bubbles Water Surface Float Up Pop 6 (SFX) | ProSoundEffects |
| RareSting | 9116394545 | Magic Glows Soft Clusters Of Chiming Hits 1 (SFX) | ProSoundEffects |
| Alarm | 9113041445 | Acme Whistle Wind Hurricane Siren 15 (SFX) | ProSoundEffects |
| Whoosh | 9126283592 | Wood Swish Ruler Whoosh Fast Movement In Air (SFX) | ProSoundEffects |
| Boo | 9119197913 | Slide Whistle 2 (SFX) | ProSoundEffects |
| Coin | 9113849306 | Coins Or Keys Jingle 1 (SFX) | ProSoundEffects |
| Slap | 9114771792 | Hand Slap Claps 3 (SFX) | ProSoundEffects |
| Freeze | 9125611419 | Ice Freeze Large Piece Crackles Liquid Nitro (SFX) | ProSoundEffects |
| Poof | 9125640290 | Magic Poofs Short Breathy Bursts Wheezy Punc (SFX) | ProSoundEffects |
| Purchase | 10066947742 | RBLX UI Purchase (SFX) | Roblox |
| Click | 15675059323 | Roblox_UI_Bright_Click | Roblox |
| Spring | 12222124 | Short spring sound.wav | Roblox |
| Music | 1838796580 | Carnival | APMOfficial |

## Bibliotecas

| Biblioteca | Versão | Autor | Link |
| --- | --- | --- | --- |
| ProfileStore | 1.0.3 (Wally `lm-loleris/profilestore`) | loleris / MAD STUDIO | https://github.com/MadStudioRoblox/ProfileStore |
| Rojo | 7.6.1 | rojo-rbx | https://rojo.space |
