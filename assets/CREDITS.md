# Créditos e origem dos assets

Regra do projeto: nenhum mesh, textura, som, animação, ícone, nome ou código de outro jogo.
Tudo que não for primitiva do Studio precisa estar listado aqui com ID, autor e licença.

## Visual

| Item | Origem | Observação |
| --- | --- | --- |
| Todos os 16 Boos | Primitivas do Studio (Part, Ball, Cylinder, SpecialMesh Sphere) montadas em `src/shared/BooModel.luau` | Design original |
| Mapa (praça, bases, zonas, carrossel, roda-gigante, tenda) | Primitivas do Studio em `src/server/Systems/WorldBuilder.luau` | Design original |
| Materiais | Materiais nativos da Roblox (WoodPlanks, Fabric, Neon, Glass, Pavement etc.) | Built-in |
| Partículas | `ParticleEmitter` com a textura padrão do engine | Built-in |
| UI e rosto do susto | Frames, UICorner e texto criados por código | Sem imagens externas |
| Fontes | `FredokaOne`, `LuckiestGuy`, `GothamBold` (fontes da Roblox) | Built-in |
| Logo (`assets/logo.svg`) | Desenhado à mão para este projeto | Original |

## Áudio

Nenhum som está configurado ainda (`Config.Sounds.* = 0`). O jogo funciona em silêncio.
Para adicionar, use só áudio do Creator Store que você tem direito de usar e registre abaixo.

| Chave no Config | Asset ID | Nome no Creator Store | Autor | Licença / verificação |
| --- | --- | --- | --- | --- |
| Pop | — | — | — | — |
| RareSting | — | — | — | — |
| Alarm | — | — | — | — |
| Whoosh | — | — | — | — |
| Boo | — | — | — | — |
| Coin | — | — | — | — |
| Music | — | — | — | — |

## Bibliotecas

| Biblioteca | Versão | Autor | Link |
| --- | --- | --- | --- |
| ProfileStore | 1.0.3 (Wally `lm-loleris/profilestore`) | loleris / MAD STUDIO | https://github.com/MadStudioRoblox/ProfileStore |
| Rojo | 7.6.1 | rojo-rbx | https://rojo.space |
