# Open Session Panel Beta

An independently written Teardown administration panel for solo and multiplayer. Development version **1.5.1**, by **Luiz-AVcruz**, uses Lua 5.1 and multiplayer scripting version 2. English is the default; Brazilian Portuguese is available.

This is the separate **beta** branch and Workshop item. The original release and its `main` branch remain unchanged. Beta preferences, player profiles, rules and roles use `savegame.mod.osp_beta.*`; no game saves or preferences were copied. Keep only one of the two panels enabled at a time.

## Appearance

**Appearance** is a personal tab available to every player, with collapsible Colors and Background sections. It contains the existing palettes and RGB editor, an optional Graphite palette and main-background opacity from 65% to 100%. Classic and 98% opacity remain the defaults. Changes apply locally and persist. Header/sidebar and popup surfaces keep their own opacity. Buttons use the original OSP styling. **Restore default appearance** restores these defaults without deleting custom RGB values; **Restore default palette** changes only the palette. Before loading a map, use **Mod Manager → Options → Appearance**, whose content scrolls above a fixed Back button.

## Panel and controls

Open with **P** or the pause menu. In **Settings → Panel tabs**, hide tabs you do not use; the remaining tabs move into the freed spaces. Settings always stays visible. The same controls are available from the Mod Manager Options, and choices are saved locally across missions and restarts. **Show all tabs** restores visibility without changing session rules or permissions. The centered panel adapts its layout to the available canvas instead of enlarging a fixed screen. Players, Session, Tools and Activity are administrative areas. **Settings** contains language, shortcut, panel mode and tab visibility; **About** contains version, license and source information. Both remain available to ordinary guests.

**Settings → Panel mode** selects Automatic, Singleplayer or Multiplayer. Automatic uses the native session type, including multiplayer hosts who are alone. Singleplayer keeps your player controls and global tools while hiding multiplayer controls. You can override detection locally; this changes presentation without granting permissions or erasing saved rules. Before loading a map, the selector is in **Mod Manager → Options → Interface**.

Settings sections can be collapsed by clicking their headers. All start collapsed, with graphical disclosure arrows; your choices persist locally. **Reset personal preferences** in Mod Manager Options collapses them again.

**Settings → Panel behavior** controls the selected player and opening tab. **Keep selection** is the default; alternatives return to yourself when closing the panel, or when leaving a tab and closing. Players, per-player Tools and Permissions share the selection. Inner popups do not reset it, and **Manage role** keeps its explicit target. The selection stays within the current map; new maps start on yourself. **Last used tab** is the default opening choice and persists between maps and restarts; **Always Players** is optional. Hidden or inaccessible tabs use the normal fallback. These personal controls are also in **Options → Interface**, which scrolls above a fixed Back button. Personal recovery resets both choices; **Show all tabs** only changes visibility.

Only the host can directly change the host. Host player-option changes are saved; players can also save an explicit disable of their own effects. Role management, map restart, explicit player reset and global tool policies can be delegated through the Admin category. A delegate may use the host as a teleport destination but cannot move or change the host. Bulk actions skip the host when issued by a delegate.

In **Players**, **Go to** and **Bring here** require selecting another player; both controls are disabled for your own selection. Delegates can still go to the host, and **Bring all** continues to skip its caller.

**Fly** enables collision-preserving flight: double-tap the logical Jump binding (Space by default) within 0.3 seconds to start/stop, then hold Jump to rise or Crouch to descend. Forward movement follows horizontal camera direction. Hold **Shift** to use the configured boost speed; releasing it restores normal flight speed. The **...** buttons beside Fly and Noclip open their independent normal and Shift speed fields (defaults 9 and 18 m/s for each mode, each bounded to 0.5–100). These are final speeds: the general player multiplier affects ordinary movement only. Host tuning persists per player; delegated tuning stays temporary and follows the corresponding Fly or Noclip permission scope. Fly and Noclip sit side by side. Their **...** buttons open a centered popup with the speed fields and hints. Click outside or use its X button to close; the background is blocked while it is open. Enter applies a value; closing discards only an unfinished edit. Changing a speed does not activate a mode. Shift selects the second configured speed, which may also be set lower than normal. **Noclip** keeps movement through geometry and its existing panel activation, with its own configurable Shift speed. It pauses while seated so vehicles can be entered and driven, then resumes on foot. Enabling either mode turns the other off. Only the ability is saved; active Fly ends on death, respawn, freeze, vehicle entry or a new mission. Existing Fly settings and custom-role grants keep their former meaning as Noclip. Announcements are entered in Session using ASCII keyboard characters (up to 240 bytes); clipboard and accented text input are not supported.

Buttons use their full visible rectangle and react on press. Holding or releasing does not repeat an action. Gameplay commands show immediate pending feedback and still wait for the server's acknowledgement.

Numeric fields combine a slider and editable number. Click the number to position the cursor and select/edit text, or drag the bar to adjust. Enter or clicking outside applies valid text; Escape cancels. Slider changes apply when you release the mouse. Values stay within each setting's range. Ctrl+A selects all; clipboard shortcuts are unavailable. The same controls are available in Mod Manager Options. Closing the panel, changing tabs or selecting another player cancels an unfinished numeric edit.

## Group actions

In **Players**, choose one player, everyone, a Role or a manual checkbox selection. Group controls cover invincibility, freeze, Fly, Noclip, Super strength, infinite ammo, healing and bringing players. Mixed effects offer explicit enable/disable choices. Other actions and numeric settings stay in individual mode. Role selection filters its current members; assigning another Role does not automatically change effects.

The host can choose **Present players only** or **Present and future players** in Settings. Future defaults apply to everyone or a Role without replacing saved individual choices. Manual selections and delegated actions affect present players only. Switching back to present players removes future defaults and keeps effects already applied. Closing the panel or leaving the tab clears the group selection.

## Super strength

**Player → Super strength** enables carrying heavier loose objects with the normal Grab button. Its **...** popup sets force (1–20×), maximum mass (1–100,000 in the game's mass scale) and optional throwing. Throwing starts off; when enabled, Use tool throws once at the configured speed (1–100 m/s). Force defaults to 1×, mass to 5,000 and throw speed to 20 m/s. Configuring these values does not enable the ability.

Your shortcut has no default key. Set it in your own Super strength popup or in **Mod Manager → Options → Personal shortcuts**. Host choices persist per player. Delegated activation and tuning remain temporary; explicitly disabling your own ability is saved. Commands use the Super strength role permission. Disabling the ability returns to normal grabbing. The temporary grip releases on death, vehicle entry, UI/context loss or an invalid object, and objects are never carried across missions. Held objects keep their mass and collisions; the server excludes occupied vehicles and player bodies. Native physics and multiplayer acceptance still require testing in Teardown.

## Infinite ammo

**Players → Infinite ammo** supplies the equipped, enabled tool and primes enabled empty tools using the game's standard ammo counter. It starts off. Open **...** to configure an optional personal shortcut. Host choices persist per player; delegated activation remains temporary. Commands follow the Infinite ammo role permission.

Ammo restoration is temporarily suspended. Disabling the ability stops replenishment and leaves the current stock, which may be 9,999. Saved restoration preferences are ignored and the old command is unavailable. Empty tools are supplied before selection, and tools with private ammo systems may be unaffected. Blocked tools and campaign unlocks are unchanged.

## Panel roles and permissions

The **Permissions** tab assigns a role to each player. It is available to the host and to delegates with role-management permissions. Built-in roles are Guest, Self only, Helper, Moderator and Administrator. **Self only** offers healing, confirmed self-kill, respawning, leaving vehicles, invincibility, Fly, Noclip, speed, Super strength, infinite ammo and tools for the caller; going to another player moves only the caller. Other players and the host are protected from changes by that role.

Select one or more players using the checkboxes, then choose the destination Role and confirm **Assign role**. **Select all** spans every page; **Clear** removes the selection. On wider panels, the player list and assignment controls sit side by side; narrower panels stack them. **Manage roles**, in the assignment block, opens the permission preview and role editor, with search and collapsible categories. Closing with X or clicking outside keeps an unfinished draft; **Continue editing** and **Discard** remain available in the compact view. Saving or a confirmed reset returns to assignment. On wide screens, role management sits beside the permission list; smaller screens use scrolling.

**Create role** starts a custom role using the selected role as a base. Use the player checkboxes in **Permissions** to assign the same Role to multiple players with one confirmation. Host access and delegated authority limits still apply. Every role can be edited under its existing ID. Up to **16 custom roles** are supported, with ASCII names of up to 40 characters. Targeted actions allow **Blocked / Self only / Any player**; bulk actions and session rules have separate on/off permissions. **Reset role** restores OSP defaults for supplied roles, or the name and permissions saved when a custom role was created. For older custom roles, the first state loaded by this update becomes that baseline. Supplied roles cannot be deleted.

Assignments and role changes are saved on the host across missions and restarts. Editing or resetting a role updates everyone assigned to it, including offline players when they reconnect. Deleting a custom role returns its linked players to Guest. Guests retain personal settings and appearance. Existing full-admin grants remain Administrator assignments.

**Admin** separates role assignment, custom-role creation, role editing/reset, custom-role deletion, global tool policies, player-option reset and map restart. Administrator includes all of these by default. Existing custom roles receive no new grants automatically. Delegates can only manage roles whose current and proposed permissions fit within their own, and cannot change the host's access. Role assignments, explicit player resets and global policies persist. Delegated player activation, tuning and actions on other players remain temporary. These permissions govern panel commands; they do not restrict ordinary actions in the game world.

## Player options between missions

The host's choices for a player are saved automatically: tool access, invincibility, Fly, Noclip, freeze, speed, Super strength, infinite ammo, ammo restoration and permission role. They are restored on a new map or reconnect. Freeze uses the player's new spawn position. Healing, killing, respawning and teleporting remain one-time actions. Delegates can save an explicit disable of their own invincibility, Fly, Noclip, Super strength, infinite ammo or freeze, and returning their own speed to 1×. The host can explicitly enable them again. Self activation, tuning and changes to other players remain temporary. Activating Fly or Noclip does not save the incidental suspension of the other mode. Granted session-rule changes are saved separately and persist.

**Settings → Effects on map load** offers the host **Start maps with effects off**, disabled by default. The next map load or restart clears saved and active player effects and returns speed to 1×, including players who join later. It preserves roles, Fly/Noclip and Super strength tuning, ammo-restoration preferences and tool rules. Effects can be enabled during that map; respawn does not disable them again. Changing the setting during play applies to the next map load.

The public game API does not expose a persistent account identity to mods. This panel assigns its own profile and stores its reference on the client, separately for each host. It does not identify players by their name or recyclable session number. A new or missing client profile starts without saved permissions; copied profiles are not authenticated identities. Keeping both the host's saved mod data and the client's profile reference is required. This mechanism supports normal clients, not anti-cheat enforcement.

**Players → Reset player options** removes that player's saved effects, speed, permission assignment and tool overrides. It restores the captured defaults on this map and preserves the host's global rules. Persistent controls wait for the client profile to connect, so a host change is not silently treated as temporary. Tool controls are grouped in **Tools**.

## Tools between missions

Tools can be filtered by **All / Vanilla / Mods**. Classification uses the verified IDs in the game's base catalog and mission tools, not their inventory slot. Tools shipped as optional built-in mods remain mods. A mod that reuses a vanilla ID shares that ID's classification; the game API does not expose a separate authoritative origin field.

The host's **Global rules** are saved per tool: game default, enabled or blocked. They apply to every player, including the host, across maps, respawns and late joins. Preferences for an absent mod tool are kept for when it returns. Search matches displayed names or IDs, ignoring case and common Latin accents, and combines with All/Vanilla/Mods. Result actions affect the exact matching IDs across every result page; category actions include the tools outside the search. Search text is retained within this mission only. Type with the ASCII keyboard (80 characters); Enter leaves the field, and X clears it.

**Actions** opens grouped operations; each row keeps its primary toggle and a **...** menu for secondary operations. Category enable/block buttons are always available. A separate enable/block row for search results appears beneath them while the search field contains text, before **Use defaults**; clearing the query hides that row. Category actions and defaults affect the whole category, while result actions affect only matching tools across all pages. The player mode also provides separate category/result rows for all current players. Both counts appear in the popup. With no matches, result buttons are disabled and category actions remain available. A lone button is centered within its row. Popups show scope and count, close by outside click or X and block background input. Group IDs are frozen when the popup opens; if any selected tool disappears, the server rejects the request before changing tools. Newly registered tools are not silently added. Legacy category commands remain available internally; the new selection commands never fall back to them.

**Selected player** changes made by the host are saved per player; delegate changes remain temporary. They cannot enable a globally blocked tool. A global rule change clears related personal overrides, including saved profiles of offline players; a personal restriction can subsequently narrow an enabled global rule. Resetting a global tool rule restores its state captured before the first intervention in the current map; subsequent maps follow their own defaults. Native campaign unlock data is never changed.

Player controls show contextual help after a 0.6-second hover, including reasons for unavailable actions. A small note beneath the player summary explains host persistence or delegated temporary changes once; individual hints do not repeat it. Hints disappear during editing, dialogs and scrolling.

## Personal shortcuts

The Mod Manager **Options** keep the complete list of optional keys for **Invincibility**, **Fly**, **Noclip**, **Super strength** and **Infinite ammo**, all unassigned by default. During a mission, set a key beside its action in **Players**: select yourself and open the **...** popup beside Invincibility, Fly, Noclip, Super strength or Infinite ammo. Invincibility has a small shortcut popup; Fly and Noclip keep their normal and Shift speed fields and show your shortcut in the same popup. That field appears only when you have selected yourself. When configuring another player's Fly or Noclip, the popup remains speed-only. The in-game Settings page no longer repeats the shortcut list.

These keys always act on your own player while the panel is closed, regardless of the selected player. They remain available while holding objects or using tools in normal gameplay. Fly grants/removes the ability, keeping double Jump to start/stop active flight. Keys are local preferences across hosts and missions. Clear a binding beside its action or use Options to clear the group; personal recovery also clears the group.

The panel rejects internal duplicate keys and collisions with its opening shortcut. Invalid/conflicting saved bindings remain inactive. Use one key without Shift/Ctrl/Alt and check game/other-mod bindings yourself. Editing, capture, interactive UI, pause, the map, vehicles and death block action shortcuts. Held keys do not repeat; simultaneous actions and presses while a request is pending are not queued. Roles and host persistence still apply. The server rejects an outdated toggle state rather than applying it blindly; notifications distinguish pending, confirmed, rejected and unknown outcomes. Shortcut notices fit their text, wrap longer messages and move below an active session announcement. No automatic retries occur.

## Numeric values

Click the value for movement speed, time scale, rain, fog or an RGB channel to type it. Enter or clicking outside applies valid text; Escape cancels. Values are rounded to the field precision and clamped to its range: player speed 0.5–3, Fly/Noclip speeds 0.5–100, time scale 0.1–2, rain 0–1, fog 10–1000 m and RGB 0–255. Decimal points and commas are accepted. The +/- buttons and RGB bars remain available. Commands still require the appropriate role permission.

## Settings before loading a map

Select **Open Session Panel Beta → Options** in the Mod Manager. This separate menu runs without a map, player or server. It changes language, the panel shortcut and the color palette using the same saved preferences as the in-game panel. **Restore personal preferences** returns to English, P and the Classic palette.

**Reset saved host options on this computer** requires confirmation and removes this computer's saved session rules, tool policies and player choices, including permission assignments and the map-load policy. It keeps custom role definitions, personal preferences, the host identity, profile identity references and profile slots. It does not modify another host or native campaign unlocks. Changes take effect on the next map load.

The install archive uses the folder **Open Session Panel Beta**, with spaces, for the local Mod Manager entry. The initial publication uses a new Workshop item restricted to friends. When updating an installed Beta, preserve its own `id.txt`; never reuse the original item's ID. The original item stays on `main` with its existing settings. Enable only one panel at a time.

## Color palettes

In the in-game **Appearance → Color palette**, choose Classic, Ocean, Forest, Violet, Light, Graphite or Custom. Before loading a map, open **Options → Appearance** in the Mod Manager. Both screens share the same personal preference, applied immediately and saved between missions.

Custom lets you choose each interface color with the previous/next role arrows, drag its RGB bars or use the +/- buttons for exact one-step adjustments. The hex value and color swatch are shown alongside the role. Background, header/sidebar, buttons, hover, selection, dividers, primary/secondary/disabled text, accent, danger and success are editable. Switching presets keeps the custom colors. A low-contrast warning helps identify hard-to-read combinations. **Restore default palette** has fixed contrast, and the main Options page also keeps **Restore personal preferences** readable regardless of the palette; both return to Classic without deleting your custom colors.

## Install and develop

The stable **1.5.0 release is complete**. This separate Beta branch carries the **1.5.1** development bundle. Promotion to `main` requires the author's explicit approval.

Players do not need Python or LuaJIT. Extract `dist/OpenSessionPanelBeta-1.5.1.zip` as its own folder in Teardown's local mods directory and enable **Open Session Panel Beta**. After updating an already loaded mod, reload the map to load the new scripts. Keep only one administration panel active while testing conflicting gameplay controls.

Before disabling or removing the mod, restore session/tool defaults as desired, then reload the map to clear temporary effects. A global mod's `server.destroy` callback is not guaranteed cleanup. Remove only this mod's folder; no game files or campaign saves are included.

Developer commands use Python 3's standard library and LuaJIT 2.1 (Lua 5.1 compatibility):

```sh
python3 tools/check.py
python3 tools/package.py
```

Packaging creates `OpenSessionPanelBeta-1.5.1.zip`, `OpenSessionPanelBeta-1.5.1-source.zip` and `SHA256SUMS`. Both contain readable source and licensing notices; there is no compilation or minification. Source repository: [Luiz-AVcruz/Open-Session-Panel-OSP, beta branch](https://github.com/Luiz-AVcruz/Open-Session-Panel-OSP/tree/beta).

Workshop assets are included in both archives. `preview.jpg` (512 × 512, below 1 MB) and `preview-menu.png` (512 × 292) use the logo supplied by Luiz-AVcruz, fitted with black padding. `WORKSHOP-DESCRIPTION.txt` keeps the complete Steam description and one-paragraph AI disclosure; `info.txt` contains only a short Mod Manager summary, without the source link or disclosure. The descriptions are validated independently as nonempty. The new Workshop item receives its own ID when the author publishes it; no ID is stored in this project or its archives.

## Verification and limits

Local checks exercise permissions, tool persistence, lifecycle, input, confirmations and asynchronous acknowledgements. A request waits for its matching server reply; after eight seconds without one, the panel reports an unknown outcome and never automatically retries the command.

Teardown's documented `ServerCall` API does not expose an authenticated sender identity. These role checks support ordinary game clients, not anti-cheat protection against altered clients. Normal multiplayer sessions require published, matching mod files. Offline tests and an illustrative UI rendering do not prove actual game rendering, callback ordering or network synchronization. The current evidence and remaining game checks are recorded in `Docs/PROJETO.md`.

## License

Original code is **AGPL-3.0-or-later**, with a narrow additional permission for the Teardown runtime/API. Read [LICENSE](LICENSE) and [ADDITIONAL-PERMISSION](ADDITIONAL-PERMISSION). The exception gives no rights to redistribute Teardown code or assets.

## Português

Em **Jogadores**, escolha uma pessoa, Todos, uma Role ou uma seleção manual por checkboxes. O alcance coletivo cobre efeitos, cura e trazer jogadores; demais ações e ajustes numéricos continuam individuais. O host pode definir se os comandos em Todos/Role também fornecem padrões para futuras entradas, respeitando escolhas individuais. Em **Permissões**, checkboxes permitem atribuir uma Role a vários jogadores de uma vez. Trocar de Role não concede nem remove efeitos automaticamente nesta versão.

Painel de administração por **Luiz-AVcruz**, com inglês padrão e opção de português brasileiro. Abra com **P** ou pelo menu de pausa. Configurações e Sobre são áreas separadas. O mod usa o HUD nativo do jogo.

**Configurações → Modo do painel** permite escolher Automático, Singleplayer ou Multiplayer. O modo automático usa o tipo da sessão, mesmo quando só o host está no multiplayer. Singleplayer mantém seus controles e as ferramentas globais, ocultando os controles de multiplayer. A escolha é local e persistente, sem conceder permissões ou apagar regras. Antes de carregar um mapa, use **Gerenciador de mods → Options → Interface**.

A aba **Aparência** reúne cores e opacidade do fundo (65–100%). O preset Grafite é opcional; Clássico e 98% de opacidade continuam como padrão. As mesmas opções ficam nas Options do gerenciador, sem mapa.

Os blocos de Configurações podem ser recolhidos pelo cabeçalho. Todos começam recolhidos, com ícones gráficos de seta, e suas escolhas ficam salvas localmente. A restauração de preferências pessoais nas Options do gerenciador recolhe todos os blocos.

Em **Configurações → Comportamento do painel**, escolha manter o jogador selecionado (padrão), voltar para si ao fechar ou voltar ao trocar de aba e fechar. A seleção é compartilhada por Jogadores, Ferramentas por jogador e Permissões e dura somente durante o mapa. A aba ao abrir pode ser a última usada (padrão) ou sempre Jogadores, respeitando visibilidade e acesso. As escolhas e a última aba persistem localmente. Os mesmos controles estão em **Options → Interface**, com rolagem e Voltar fixo. Restaurar preferências pessoais recupera esses padrões; Mostrar todas as abas continua afetando somente a visibilidade.

Os campos numéricos combinam slider e número editável. Clique no número para posicionar o cursor, selecionar e editar trechos, ou arraste a barra para ajustar. Enter ou clique fora aplica o texto válido; Esc cancela. O slider aplica ao soltar o mouse, respeitando a faixa de cada opção. Ctrl+A seleciona tudo; os atalhos de clipboard não estão disponíveis. O mesmo controle aparece nas Options do gerenciador.

Em **Jogadores**, **Ir até** e **Trazer aqui** exigem outro alvo; os dois controles ficam desabilitados para si mesmo. Delegados ainda podem ir até o host, e **Trazer todos** continua excluindo quem chamou.

**Jogador → Superforça** permite carregar objetos soltos pelo botão Agarrar. O botão **...** configura força (1–20×), massa máxima (1–100.000 na escala do jogo) e arremesso opcional, inicialmente desligado. Com arremesso ligado, Usar ferramenta lança uma vez à velocidade escolhida (1–100 m/s). O atalho pessoal começa sem tecla e também pode ser configurado nas Options. Os padrões são força 1×, massa 5.000 e velocidade de arremesso 20 m/s. Configurar não ativa a habilidade.

As escolhas do host por jogador persistem entre missões: ferramentas, invencibilidade, Fly, Noclip, congelamento, velocidade e role de acesso. O perfil é atribuído pelo mod e guardado no cliente para aquele host; não depende do nome ou número temporário da sessão. Alterações individuais de delegados continuam temporárias; regras de sessão autorizadas podem persistir. **Jogadores → Restaurar opções do jogador** limpa as escolhas pessoais e mantém as regras gerais.

Os atalhos pessoais de **Invencibilidade**, **Fly** e **Noclip** começam sem tecla atribuída. A lista completa fica em **Open Session Panel Beta → Options** no gerenciador de mods. Durante a missão, selecione a si mesmo em **Jogadores** e abra **...** ao lado da ação para configurar o atalho. Fly e Noclip mantêm seus campos de velocidade nesse popup; para outro jogador, esses popups mostram apenas as velocidades. As teclas são locais e sempre agem no próprio jogador com o painel fechado. Os avisos se ajustam ao texto, quebram mensagens longas e descem enquanto um anúncio de sessão está ativo.

Em **Jogadores → Munição infinita**, o contador padrão da ferramenta equipada é reabastecido. O botão **...** oferece restauração ao desligar (padrão ligado) e atalho pessoal sem tecla padrão. Ferramentas habilitadas com munição zerada são abastecidas antes de serem selecionadas. Restaurar devolve cada ferramenta à quantidade capturada antes da primeira reposição, com mínimo de 1 se estava vazia; desligar a restauração mantém o estoque fornecido. Morte ou reaparecimento pelo OSP encerra a captura atual. Ferramentas com munição própria podem não ser afetadas; interromper o mod abruptamente não garante restauração.

Ao desligar explicitamente um efeito em si mesmo, o jogador salva esse desligamento para as próximas missões, inclusive como convidado com a permissão correspondente. Voltar a própria velocidade para 1× também fica salvo. O host pode reativar o efeito depois. Ativar, ajustar valores ou alterar outros jogadores continua temporário para delegados.

Em **Configurações → Efeitos ao carregar mapa**, o host pode ativar **Começar mapas com efeitos desligados**, desativado por padrão. No próximo carregamento/reinício, os efeitos ficam desligados e a velocidade volta a 1× para todos, inclusive quem entrar depois. Roles, ajustes de voo/Superforça, preferência de restauração de munição e regras de ferramentas são preservados. É possível reativar efeitos durante a partida; reaparecer não os desliga novamente.

Em **Permissões**, marque uma ou várias pessoas na lista e escolha a Role a atribuir. Marcar todos considera todas as páginas e Limpar remove a seleção. A lista e o bloco da Role ficam lado a lado quando há largura; em telas estreitas, são empilhados. **Gerenciar Roles**, no bloco de atribuição, abre consulta, busca, categorias e editor. **Criar Role** inicia uma Role customizada com base na selecionada. Todas as Roles podem ser editadas; **Restaurar Role** recupera os padrões do OSP para as prontas ou o nome e as permissões da criação para as customizadas. Nas customizadas antigas, o primeiro estado carregado nesta atualização vira a base. As prontas não podem ser excluídas; há limite de 16 customizadas. Fechar pelo X ou por clique fora preserva o rascunho, com Continuar edição/Descartar na tela compacta. Editar ou restaurar altera todos os vinculados, inclusive após reconexão. Admin separa os poderes de gerenciamento e o Administrador recebe todos por padrão. Delegados não podem gerenciar Roles mais fortes, conceder permissões que não possuem ou alterar o acesso do host. Apenas em si permite morte confirmada somente do próprio jogador.

Os controles de ferramentas ficam em **Ferramentas**, com filtros Vanilla e Mods; ações de categoria abrangem os IDs registrados naquele momento. Restaurar padrões não muda os desbloqueios da campanha. Recarregue o mapa após atualizar. Persistência dos perfis e multiplayer real ainda precisam ser observados no jogo com os mesmos arquivos em todos os participantes.
