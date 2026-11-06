# Open Session Panel

An independently written Teardown administration panel for solo and multiplayer. Version **1.2.0**, by **Luiz-AVcruz**, uses Lua 5.1 and multiplayer scripting version 2. English is the default; Brazilian Portuguese is available.

## Panel and controls

Open with **P** or the pause menu. The centered panel adapts its layout to the available canvas instead of enlarging a fixed screen. Players, Session, Tools and Activity are administrative areas. **Settings** contains language, shortcut and the optional health indicator; **About** contains version, license and source information. Both remain available to ordinary guests.

Only the host can save player options and global tool policies, grant access, restart the map or directly change the host. A delegate may use the host as a teleport destination but cannot move or change the host. Bulk actions skip the host when issued by a delegate.

Flight uses the player's logical movement bindings and camera direction; jump ascends and crouch descends. Announcements are entered in Session using ASCII keyboard characters (up to 240 bytes); clipboard and accented text input are not supported.

Buttons use their full visible rectangle and react on press. Holding or releasing does not repeat an action. Gameplay commands show immediate pending feedback and still wait for the server's acknowledgement.

## Player options between missions

The host's choices for a player are saved automatically: tool access, invincibility, flight, freeze, speed and admin access. They are restored on a new map or reconnect. Freeze uses the player's new spawn position. Healing, killing, respawning and teleporting remain one-time actions. Changes made by a delegated admin are temporary and do not overwrite the host's saved choices.

The public game API does not expose a persistent account identity to mods. This panel assigns its own profile and stores its reference on the client, separately for each host. It does not identify players by their name or recyclable session number. A new or missing client profile starts without saved permissions; copied profiles are not authenticated identities. Keeping both the host's saved mod data and the client's profile reference is required. This mechanism supports normal clients, not anti-cheat enforcement.

**Players → Reset player options** removes that player's saved effects, speed, admin role and tool overrides. It restores the captured defaults on this map and preserves the host's global rules. Persistent controls wait for the client profile to connect, so a host change is not silently treated as temporary.

**Players → Mod tools** offers direct blocks for the selected player or everyone. The host's selected-player block is saved in that player's profile; the everyone shortcut creates a global rule including the host. A delegate's shortcut is temporary and excludes the host. Vanilla tools are preserved. Use Tools to enable tools again or restore their global defaults.

## Tools between missions

Tools can be filtered by **All / Vanilla / Mods**. Classification uses the verified IDs in the game's base catalog and mission tools, not their inventory slot. Tools shipped as optional built-in mods remain mods. A mod that reuses a vanilla ID shares that ID's classification; the game API does not expose a separate authoritative origin field.

The host's **Global rules** are saved per tool: game default, enabled or blocked. They apply to every player, including the host, across maps, respawns and late joins. Preferences for an absent mod tool are kept for when it returns. Category actions affect the currently registered tools in the selected filter.

**Selected player** changes made by the host are saved per player; delegate changes remain temporary. They cannot enable a globally blocked tool. A global rule change clears related personal overrides, including saved profiles of offline players; a personal restriction can subsequently narrow an enabled global rule. Resetting a global tool rule restores its state captured before the first intervention in the current map; subsequent maps follow their own defaults. Native campaign unlock data is never changed.

## Optional health indicator

The additional bar is an individual preference in Settings, **off by default**, saved between missions. Enabling it shows real player health and a percentage alongside the native HUD. Disabling it leaves the game's HUD alone. It neither replaces the native bar nor modifies health, regeneration or global HUD flags.

## Install and develop

Players do not need Python or LuaJIT. Extract `dist/OpenSessionPanel-1.2.0.zip` as its own folder in Teardown's local mods directory and enable **Open Session Panel**. After updating an already loaded mod, reload the map to load the new scripts. Keep only one administration panel active while testing conflicting gameplay controls.

Before disabling or removing the mod, restore session/tool defaults as desired, then reload the map to clear temporary effects. A global mod's `server.destroy` callback is not guaranteed cleanup. Remove only this mod's folder; no game files or campaign saves are included.

Developer commands use Python 3's standard library and LuaJIT 2.1 (Lua 5.1 compatibility):

```sh
python3 tools/check.py
python3 tools/package.py
```

Packaging creates an install ZIP, complete matching source ZIP and `SHA256SUMS`. Both contain readable source and licensing notices; there is no compilation or minification. Source repository: [Luiz-AVcruz/Open-Session-Panel-OSP](https://github.com/Luiz-AVcruz/Open-Session-Panel-OSP).

Workshop assets are included in both archives. `preview.jpg` (512 × 512, below 1 MB) and `preview-menu.png` (512 × 292) use the logo supplied by Luiz-AVcruz, fitted with black padding. `WORKSHOP-DESCRIPTION.txt` preserves the author's complete description and AI disclosure with paragraph breaks; `info.txt` contains the same words on one line for its key/value format. Editing the Steam page does not automatically update the local metadata file. Before publishing an update, check the description displayed by the game against this text. To replace the thumbnail, replace `preview.jpg` and use **Publish update**, preserving the existing `id.txt`. Packaging validates preview headers/size/dimensions and matching description content.

## Verification and limits

Local checks exercise permissions, tool persistence, lifecycle, input, confirmations and asynchronous acknowledgements. A request waits for its matching server reply; after eight seconds without one, the panel reports an unknown outcome and never automatically retries the command.

Teardown's documented `ServerCall` API does not expose an authenticated sender identity. These role checks support ordinary game clients, not anti-cheat protection against altered clients. Normal multiplayer sessions require published, matching mod files. Offline tests and an illustrative UI rendering do not prove actual game rendering, callback ordering or network synchronization. The current evidence and remaining game checks are recorded in `Docs/PROJETO.md`.

## License

Original code is **AGPL-3.0-or-later**, with a narrow additional permission for the Teardown runtime/API. Read [LICENSE](LICENSE) and [ADDITIONAL-PERMISSION](ADDITIONAL-PERMISSION). The exception gives no rights to redistribute Teardown code or assets.

## Português

Painel de administração por **Luiz-AVcruz**, com inglês padrão e opção de português brasileiro. Abra com **P** ou pelo menu de pausa. Configurações e Sobre são áreas separadas. O indicador adicional de vida começa desligado e preserva o HUD do jogo.

As escolhas do host por jogador persistem entre missões: ferramentas, invencibilidade, voo, congelamento, velocidade e admin. O perfil é atribuído pelo mod e guardado no cliente para aquele host; não depende do nome ou número temporário da sessão. Alterações de admins nomeados continuam temporárias. **Jogadores → Restaurar opções do jogador** limpa as escolhas pessoais e mantém as regras gerais.

Em **Jogadores → Ferramentas de mods**, há atalhos para bloquear ferramentas do alvo ou de todos. No host, o bloqueio coletivo inclui o próprio host e persiste. Em Ferramentas, os filtros separam Vanilla e Mods; ações de categoria abrangem os IDs registrados naquele momento. Restaurar padrões não muda os desbloqueios da campanha. Recarregue o mapa após atualizar. Persistência dos perfis e multiplayer real ainda precisam ser observados no jogo com os mesmos arquivos em todos os participantes.
