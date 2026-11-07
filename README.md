# Open Session Panel

An independently written Teardown administration panel for solo and multiplayer. Development bundle **1.4.0**, by **Luiz-AVcruz**, uses Lua 5.1 and multiplayer scripting version 2. English is the default; Brazilian Portuguese is available.

## Panel and controls

Open with **P** or the pause menu. The centered panel adapts its layout to the available canvas instead of enlarging a fixed screen. Players, Session, Tools and Activity are administrative areas. **Settings** contains language, shortcut and the color palette; **About** contains version, license and source information. Both remain available to ordinary guests.

Only the host can save player options and global tool policies, grant access, restart the map or directly change the host. A delegate may use the host as a teleport destination but cannot move or change the host. Bulk actions skip the host when issued by a delegate.

**Fly** enables collision-preserving flight: double-tap the logical Jump binding (Space by default) within 0.3 seconds to start/stop, then hold Jump to rise or Crouch to descend. Forward movement follows horizontal camera direction. Hold **Shift** to use the configured boost speed; releasing it restores normal flight speed. The **...** buttons beside Fly and Noclip open their independent normal and Shift speed fields (defaults 9 and 18 m/s for each mode, each bounded to 0.5–100). These are final speeds: the general player multiplier affects ordinary movement only. Host tuning persists per player; delegated tuning stays temporary and follows the corresponding Fly or Noclip permission scope. Fly and Noclip sit side by side. Their **...** buttons open a centered popup with the speed fields and hints. Click outside, press Esc or use its X button to close; the background is blocked while it is open. Enter applies a value; closing discards only an unfinished edit. Changing a speed does not activate a mode. Shift selects the second configured speed, which may also be set lower than normal. **Noclip** keeps movement through geometry and its existing panel activation, with its own configurable Shift speed. Enabling either mode turns the other off. Only the ability is saved; active Fly ends on death, respawn, freeze, vehicle entry or a new mission. Existing Fly settings and custom-role grants keep their former meaning as Noclip. Announcements are entered in Session using ASCII keyboard characters (up to 240 bytes); clipboard and accented text input are not supported.

Buttons use their full visible rectangle and react on press. Holding or releasing does not repeat an action. Gameplay commands show immediate pending feedback and still wait for the server's acknowledgement.

## Panel roles and permissions

The host's **Permissions** tab assigns a role to each player. Built-in roles are Guest, Self only, Helper, Moderator and Administrator. **Self only** offers healing, respawning, leaving vehicles, invincibility, Fly, Noclip, speed and tools for the caller; going to another player moves only the caller. Other players and the host are protected from changes by that role.

The default view selects a player and role and shows a read-only permissions preview. **Create custom role** copies the selected role into a separate editor; **Edit custom role** opens that editor for an existing custom role. Name, capability, save and delete controls appear only in the editor. Saving returns to assignment with the saved role selected; discarding returns without writing changes. Up to **16 custom roles** are supported, with ASCII names of up to 40 characters. Targeted actions allow **Blocked / Self only / Any player**. Bulk actions, announcements, each session rule and resetting all session rules have separate on/off permissions. Built-ins are read-only; save a custom copy before assigning it.

Assignments and custom roles are saved on the host across missions and restarts. Editing a role changes access for all linked players on their next command. Deleting it revokes those assignments, including offline profiles. Guests retain Settings and About. Existing full-admin grants remain Administrator grants; the quick admin button still grants full delegated access or revokes panel access.

Granting access, managing roles, resetting saved player options, restarting the map, changing the host and setting global tool policies remain host-only. A role cannot grant those powers. These permissions govern panel commands; they do not restrict ordinary actions in the game world.

## Player options between missions

The host's choices for a player are saved automatically: tool access, invincibility, Fly, Noclip, freeze, speed and permission role. They are restored on a new map or reconnect. Freeze uses the player's new spawn position. Healing, killing, respawning and teleporting remain one-time actions. Player changes made by a delegate are temporary and do not overwrite the host's saved choices. Granted session-rule changes are saved separately and persist.

The public game API does not expose a persistent account identity to mods. This panel assigns its own profile and stores its reference on the client, separately for each host. It does not identify players by their name or recyclable session number. A new or missing client profile starts without saved permissions; copied profiles are not authenticated identities. Keeping both the host's saved mod data and the client's profile reference is required. This mechanism supports normal clients, not anti-cheat enforcement.

**Players → Reset player options** removes that player's saved effects, speed, permission assignment and tool overrides. It restores the captured defaults on this map and preserves the host's global rules. Persistent controls wait for the client profile to connect, so a host change is not silently treated as temporary. Tool controls are grouped in **Tools**.

## Tools between missions

Tools can be filtered by **All / Vanilla / Mods**. Classification uses the verified IDs in the game's base catalog and mission tools, not their inventory slot. Tools shipped as optional built-in mods remain mods. A mod that reuses a vanilla ID shares that ID's classification; the game API does not expose a separate authoritative origin field.

The host's **Global rules** are saved per tool: game default, enabled or blocked. They apply to every player, including the host, across maps, respawns and late joins. Preferences for an absent mod tool are kept for when it returns. Search matches displayed names or IDs, ignoring case and common Latin accents, and combines with All/Vanilla/Mods. Group actions affect the exact matching IDs across every result page. Search text is retained within this mission only. Type with the ASCII keyboard (80 characters); Enter/Esc leave the field, and X clears it.

**Actions** opens grouped operations; each row keeps its primary toggle and a **...** menu for secondary operations. Popups show scope and count, close by outside click/Esc/X and block background input. Group IDs are frozen when the popup opens; if any selected tool disappears, the server rejects the request before changing tools. Newly registered tools are not silently added. Legacy category commands remain available internally; the new selection commands never fall back to them.

**Selected player** changes made by the host are saved per player; delegate changes remain temporary. They cannot enable a globally blocked tool. A global rule change clears related personal overrides, including saved profiles of offline players; a personal restriction can subsequently narrow an enabled global rule. Resetting a global tool rule restores its state captured before the first intervention in the current map; subsequent maps follow their own defaults. Native campaign unlock data is never changed.

## Numeric values

Click the value for movement speed, time scale, rain, fog or an RGB channel to type it. Enter applies and Esc cancels; clicking another control discards the unfinished edit. Values are rounded to the field precision and clamped to its range: player speed 0.5–3, Fly/Noclip speeds 0.5–100, time scale 0.1–2, rain 0–1, fog 10–1000 m and RGB 0–255. Decimal points and commas are accepted. The +/- buttons and RGB bars remain available. Commands still require the appropriate role permission.

## Settings before loading a map

Select **Open Session Panel → Options** in the Mod Manager. This separate menu runs without a map, player or server. It changes language, the panel shortcut and the color palette using the same saved preferences as the in-game panel. **Restore personal preferences** returns to English, P and the Classic palette.

**Reset saved host options on this computer** requires confirmation and removes this computer's saved session rules, tool policies and player choices, including permission assignments. It keeps custom role definitions, personal preferences, the host identity, profile identity references and profile slots. It does not modify another host or native campaign unlocks. Changes take effect on the next map load.

The install archive uses the folder **Open Session Panel**, with spaces, for the local Mod Manager entry. Keep a single local copy enabled. Renaming an older local folder changes its settings namespace, so existing local preferences must be transferred with the game closed. Workshop updates keep their existing item identity. The Workshop ID remains in the installed `id.txt`; do not delete it when updating.

## Color palettes

In the in-game **Settings**, choose Classic, Ocean, Forest, Violet, Light or Custom. Before loading a map, open **Options → Color palette** in the Mod Manager. Both screens share the same personal preference, applied immediately and saved between missions.

Custom lets you choose each interface color with the previous/next role arrows, drag its RGB bars or use the +/- buttons for exact one-step adjustments. The hex value and color swatch are shown alongside the role. Background, header/sidebar, buttons, hover, selection, dividers, primary/secondary/disabled text, accent, danger and success are editable. Switching presets keeps the custom colors. A low-contrast warning helps identify hard-to-read combinations. **Restore default palette** has fixed contrast, and the main Options page also keeps **Restore personal preferences** readable regardless of the palette; both return to Classic without deleting your custom colors.

## Install and develop

All current work belongs to the **1.4.0 development bundle**. Commits record ongoing changes; the product version stays at 1.4.0 until Luiz-AVcruz explicitly closes this bundle. Packaging or installing a revision does not automatically bump it.

Players do not need Python or LuaJIT. Extract `dist/OpenSessionPanel-1.4.0.zip` as its own folder in Teardown's local mods directory and enable **Open Session Panel**. After updating an already loaded mod, reload the map to load the new scripts. Keep only one administration panel active while testing conflicting gameplay controls.

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

Painel de administração por **Luiz-AVcruz**, com inglês padrão e opção de português brasileiro. Abra com **P** ou pelo menu de pausa. Configurações e Sobre são áreas separadas. O mod usa o HUD nativo do jogo.

As escolhas do host por jogador persistem entre missões: ferramentas, invencibilidade, Fly, Noclip, congelamento, velocidade e role de acesso. O perfil é atribuído pelo mod e guardado no cliente para aquele host; não depende do nome ou número temporário da sessão. Alterações individuais de delegados continuam temporárias; regras de sessão autorizadas podem persistir. **Jogadores → Restaurar opções do jogador** limpa as escolhas pessoais e mantém as regras gerais.

Em **Permissões**, o host pode usar Convidado, Apenas em si, Ajudante, Moderador e Administrador, ou criar até 16 roles customizadas. Cada ação individual aceita bloqueio, apenas em si ou qualquer jogador; ações coletivas, anúncios e regras têm permissões próprias. Editar uma role altera todos os vinculados; excluí-la revoga o acesso inclusive de perfis offline. Os vínculos persistem entre missões. Gerenciar acesso/roles, alterar o host, restaurar perfis, reiniciar mapas e definir políticas gerais de ferramentas continua exclusivo do host.

Os controles de ferramentas ficam em **Ferramentas**, com filtros Vanilla e Mods; ações de categoria abrangem os IDs registrados naquele momento. Restaurar padrões não muda os desbloqueios da campanha. Recarregue o mapa após atualizar. Persistência dos perfis e multiplayer real ainda precisam ser observados no jogo com os mesmos arquivos em todos os participantes.
