# Open Session Panel

## Objetivo e prioridades

Painel independente de administração de Teardown, modificável e redistribuível, por **Luiz-AVcruz**. Público: host, administradores nomeados e jogadores de sessões cooperativas. Prioridades desta revisão: permissões granulares do painel, roles gerenciadas pelo host e persistência das escolhas por jogador.

A v1.0 foi implementada e copiada para mods locais. O log confirma seu carregamento; o usuário observou que o menu era grande, pouco adaptável e visualmente insatisfatório. O layout anterior de 1400×880 era redimensionado inteiro. A revisão 1.1 trata esses problemas sem alegar que os testes anteriores demonstraram usabilidade.

## Escopo da versão 1.4.0

- Jogadores: cura, morte confirmada, respawn, ir até/trazer jogador, retirada de veículo, congelamento, invencibilidade, Fly com colisão, Noclip e velocidade.
- Sessão: cura coletiva, trazer participantes, regeneração nativa, tempo, chuva, neblina, restauração de padrões, reinício confirmado e anúncios.
- Ferramentas: filtros Todas/Vanilla/Mods; regras gerais e escolhas por jogador persistentes quando feitas pelo host; alterações de delegados temporárias. Controles concentrados em Ferramentas, com confirmação do alcance.
- Permissões: roles prontas e até 16 customizadas; capacidades por ação e alvo, atribuição por jogador, edição e exclusão pelo host.
- Perfis por jogador: ferramentas, invencibilidade, Fly, Noclip, congelamento, velocidade e role de acesso salvos pelo host; restauração dos padrões pessoais sem remover regras gerais.
- Atividade: até cem ações, autor, alvo, resultado e contagem de afetados/ignorados.
- Interface: janela central limitada a 1120×720 unidades e a 85% da largura/82% da altura disponíveis; colunas e linhas adaptadas à área, navegação superior em telas estreitas; paginação/rolagem conforme o conteúdo.
- Configurações: idioma, atalho e paleta de cores, também acessíveis antes de carregar um mapa pelo botão Options do gerenciador, com recuperação de preferências/regras locais. Sobre: versão, autoria, licença e código. Ambas são acessíveis aos convidados. Anúncios ficam na seção Sessão.
- Inglês padrão e português brasileiro. Nome público e autoria: **Luiz-AVcruz**.

Permanecem fora da entrega: armadura, vida ampliada, dano de queda próprio, minimapa, substituição do HUD nativo, modo foto, kick/ban e integrações específicas com outros mods.

## Autoridade, dados e recuperação

Lógica de jogo no servidor, apresentação no cliente e dados serializáveis em `shared`. Somente o host atribui acesso, cria/edita/exclui roles, restaura perfis, altera diretamente o host, reinicia o mapa ou grava escolhas persistentes por jogador e políticas gerais de ferramentas. Regras de sessão (tempo, chuva, neblina e regeneração) podem ser alteradas e persistidas também por delegados que tenham a capacidade correspondente. Comandos temporários de delegados protegem o host também nas operações coletivas e não sobrescrevem as escolhas salvas do host.

A identidade de remetente do `ServerCall` não é autenticada pela API documentada: o modelo pressupõe clientes normais e não é anunciado como anticheat. Cada ação valida papel, alvo e argumento no momento de execução; respostas são correlacionadas por identificador. Após oito segundos sem resposta, o cliente indica resultado desconhecido, permite nova ação e ignora respostas antigas; nunca repete comandos automaticamente.

Idioma, atalho e paleta são preferências locais. Tempo, chuva, neblina, regeneração e políticas de ferramentas ficam na área própria do mod no host. Preferências anteriores são preservadas; política de ferramenta ausente significa padrão do jogo. Nenhum dado em `savegame.tool` é escrito.

Políticas de ferramentas são indexadas por ID codificado, sem depender do ID temporário do jogador. Aplicam-se ao host, participantes presentes, novos participantes, respawns e ferramentas registradas mais tarde. Ferramentas ausentes mantêm sua preferência. Bloqueio geral domina habilitação individual. Mudar uma política geral remove as substituições pessoais daquele ID, inclusive perfis salvos de jogadores offline; depois disso, uma restrição individual pode limitar uma política habilitada. O estado padrão remove a política e restaura o valor capturado antes da primeira intervenção no mapa atual; a próxima missão usa seus próprios padrões. Ações de categoria abrangem os IDs registrados no momento, sem criar uma regra para futuros IDs desconhecidos.

A classificação Vanilla usa os 17 IDs do catálogo base e camera/minigunmall/snowball, confirmados na instalação. Não usa grupos de inventário e não incorpora código do jogo. Outros IDs são Mods, inclusive exemplos opcionais fornecidos pelo jogo. Reutilizar um ID vanilla implica compartilhar sua classificação.

O host salva ferramentas e opções pessoais por perfil: invencibilidade, Fly, Noclip, congelamento, velocidade e role de acesso. Ações pontuais, como cura e teleporte, não são repetidas ao carregar uma missão. Congelamento usa a posição de entrada do novo mapa. Restaurar um jogador limpa suas escolhas e retorna às bases capturadas neste mapa, mantendo as regras gerais. Alterações temporárias de delegados terminam na saída/recarga; IDs reutilizados não herdam permissões.

A [API pública 2.2.0](https://teardowngame.com/modding/api.html#GetPlayerName) expõe nomes e IDs de sessão, sem vínculo documentado com uma conta estável. O mod mantém um namespace persistente no host, emite um perfil por contador e guarda sua referência no cliente para aquele host. O handshake ocorre antes de liberar alterações persistentes do host; repetições retornam a mesma identidade na sessão. Cada entrada recebe um marcador sequencial do servidor, mantido entre contextos Lua: pedido e resposta precisam corresponder à entrada atual, evitando vinculação ou escrita por mensagens antigas. Perfil ausente/desconhecido recebe um perfil novo sem permissões; uma referência já em uso por outro participante recebe um perfil separado. Referências pessoais de perfil não ficam em `shared` nem no histórico; namespace e marcador de entrada são públicos. Eles não são credenciais criptográficas e o perfil enviado pelo cliente não é autenticado. Copiar/apagar dados locais, mudar de instalação ou trocar host pode perder ou copiar a referência; não é identidade de conta. A persistência real do armazenamento do cliente e a ordenação do handshake precisam de confirmação no motor.

Antes de remover o mod, restaurar regras conforme desejado e recarregar o mapa. `server.destroy` só é garantido para game modes e não é a base de recuperação deste mod global.

## Organização e comandos

Lua 5.1, scripting version 2 do Teardown, sem dependências no runtime. Código jogável em `mod/`, teste do contrato do servidor/cliente em `tests/`, ferramentas locais em `tools/`. A versão de produto é **1.4.0**; `version = 2` no manifesto continua significando a geração do scripting.

```sh
python3 tools/check.py
python3 tools/package.py
```

O usuário informou que publicou a revisão anterior e abriu o bundle de desenvolvimento **1.4.0**. Manter esse número até ele dizer que o bundle está encerrado. Não incrementar por edição, commit, empacotamento ou instalação; não reescrever o histórico Git.

O empacotador produz ZIP instalável, ZIP de fontes e hashes determinísticos. O pacote não inclui `.git`, identificadores de Workshop, backups, tokens ou assets proprietários. Não é necessário Python para jogar.

## Licença e publicação

AGPLv3 ou posterior para o código próprio, com permissão adicional restrita ao runtime/API do Teardown. Manter o texto GNU e sua atribuição original; a identificação de autoria do projeto é Luiz-AVcruz. Código independente, sem copiar scripts ou assets do Admin Panel.

O usuário indicou `https://github.com/Luiz-AVcruz/Open-Session-Panel-OSP.git` como destino Git. Esse é o remoto `origin`, com branch `main` e autoria Luiz-AVcruz. O envio ao repositório é autorizado; publicar no Workshop é uma operação separada. A aceitação multiplayer normal depende dos mesmos arquivos entre participantes e de testes no jogo.

## Verificação e próximo ponto de retomada

Registrar a seguir a evidência efetivamente obtida nesta revisão, distinguindo testes locais, prévia ilustrativa, instalação e observação dentro do jogo. O backup central da árvore de projeto e da cópia instalada da v1.0 foi compactado e validado antes das alterações.

Para testar no jogo: carregar sandbox somente com este painel administrativo; conferir Players/Session/Tools/Permissions/Activity/Settings/About em EN/PT, foco de texto, modais, navegação e rolagem. Atribuir uma role limitada, testar ações permitidas/bloqueadas, editar/revogar e trocar missão. Testar dano, cura, morte e respawn. Alternar políticas de Vanilla/Mods, entrar outro jogador e registrar ferramentas tardiamente. Restaurar padrões e confirmar que a próxima missão segue o jogo. Repetir com host/delegado/convidado antes de afirmar suporte multiplayer observado.

### Evidência obtida na revisão 1.1

- `python3 tools/check.py` passou: sintaxe Lua 5.1, 136 asserções do servidor e 5.558 do cliente. Contagens incluem traduções, geometria e escopos, não representam esse número de cenários no motor.
- Testes do cliente cobrem cinco formatos de canvas e os dois idiomas, controles alcançáveis por rolagem/paginação, modal e respostas atrasadas, filtros, persistência do indicador em nova instância Lua e histórico preenchido.
- Testes do servidor cobrem missão nova, IDs de jogador novos, ferramenta ausente/retornando entre atualizações, prioridade global/individual, restauração inclusive de estado inicial falso, alcance de categorias e recusas de permissão. Escritas persistentes ficam no namespace do mod.
- Revisão independente orientou correções de contagem para categorias sem alterações elegíveis, bloqueio de ferramenta registrada entre atualizações e detalhes perdidos no histórico. Nenhum achado concreto permaneceu no recorte final.
- Prévia ilustrativa gerada com as chamadas de desenho do Lua, métricas/fontes e fundo simulados. Foram inspecionados Jogadores, Ferramentas, Configurações, Sobre, Sessão e indicador de vida em EN/PT e tamanhos distintos. As montagens estão em `dist/previews/`; não são screenshots do Teardown.
- Nove arquivos da cópia local foram atualizados e relidos; seus hashes coincidem com o ZIP instalável. Arquivos alheios foram preservados. O mod não foi ativado e a sessão não foi reiniciada automaticamente. É necessário recarregar o mapa para carregar os scripts novos.
- Renderização, entrada e ordenação real dos scripts no Teardown, partida solo observada e multiplayer real continuam pendentes. Não houve commit, push ou publicação.

### Entrada e perfis 1.2.0

Relato no jogo: a maioria dos botões só selecionava sobre o texto e a resposta parecia atrasada. O helper desenhava fundo/hover por uma geometria própria, mas decidia ativação com `UiBlankButton` depois do texto recortado. A documentação não especifica a fase de ativação desse controle; a causa exata do comportamento nativo não foi observada diretamente.

A entrada passou a usar o próprio retângulo do botão, limitado à parte visível do viewport, e a borda de pressionamento `InputPressed("lmb")`. A amostra é obtida antes do desenho de texto. Cada desenho consome no máximo um pressionamento e define explicitamente alinhamento superior esquerdo. Segurar e soltar não repetem ações. Confirmações continuam exigindo um novo pressionamento, e pedidos de jogo continuam aguardando o ACK correspondente.

O mock anterior ativava o controle nativo já no pressionamento e ignorava diferenças entre pressionar/segurar/soltar. O teste passou a separar essas fases e admitir retorno de clique nativo apenas na soltura. O requisito de responder no pressionamento falhou com o código anterior e passou após a correção; isso demonstra o contrato da implementação, sem reproduzir por completo o motor. Casos adicionais cobrem os quatro cantos fora do texto, EN/PT, tamanhos distintos, RPC único, botões desabilitados, limite de rolagem e arrastar/soltar o clique de abertura sobre a confirmação.

A sensação de resposta e o clique real precisam ser reconferidos no Teardown após recarregar o mapa. Não houve automação da sessão aberta.

O mock de `InputClear` também foi corrigido para apagar o evento de mouse, como permite o contrato da API. Isso expôs o clique de Enviar perdido durante digitação: a captura de texto/atalho em `tick` limpava o mouse antes de `draw`. Eventos de mouse agora seguem para os botões. Um teste adicional falhou quando a última letra e o clique ocorriam no mesmo frame; o pressionamento é amostrado antes da captura de teclado e descartado ao terminar o desenho, preservando a letra e o clique sem repetir a ação. O cliente mostra pedido enviado antes de chamar o servidor, permitindo que um ACK síncrono substitua corretamente essa mensagem.

Os testes de perfil usam armazenamento compartilhado entre contextos Lua novos, trocam o ID e nome do participante, mantêm o perfil anterior e verificam que o novo ocupante do ID antigo recebe padrões. Cobrem efeitos, velocidade fracionária, false explícito sobre padrão true, admin/revogação, regras de ferramentas, perfil duplicado simultâneo, exclusão de substituições offline, ferramentas registradas entre atualizações e restauração sem remover regras gerais. O mock do registro respeita filhos imediatos em `ListKeys` e exclusão recursiva em `ClearKey`. Isso demonstra a lógica local; não autentica contas nem comprova persistência no jogo.

Para aceitação no jogo: host alterar ferramentas/efeitos/admin de um convidado; trocar missão mantendo os dados locais; conferir restauração e reentrada com ID diferente. Revogar admin, trocar mapa e confirmar a revogação. Restaurar opções do jogador, trocar mapa e conferir padrões com regras gerais preservadas. Testar os atalhos de Mods sem alterar vanilla e repetir cliques nos cantos dos botões, incluindo Enviar com campo em foco.

Evidência local da 1.2.0: sintaxe Lua 5.1, 7.906 asserções do cliente com UI simulada e 182 do servidor passaram. A revisão independente conferiu o contrato de armazenamento e apontou a falta de correlação na identificação; o marcador por entrada foi acrescentado e os testes agora rejeitam pedidos/respostas antigos de outra entrada ou missão. As contagens incluem geometria e traduções, sem equivaler a esse número de cenários no motor. As prévias `dist/previews/1.2.0-*.png` mostram os atalhos e a confirmação em 1024×768 com métricas simuladas.

O backup central anterior à revisão contém a árvore de projeto e a instalação 1.1, compactadas, comparadas e verificadas por hash. A atualização local preserva os nove arquivos de distribuição correspondentes ao ZIP; a sessão aberta não é reiniciada. O recibo de instalação e a verificação dos pacotes ficam junto do backup central. Os pacotes de instalação e fonte são reproduzíveis pela árvore extraída de fontes. Git registra a entrega localmente com autoria Luiz-AVcruz, sem remoto, push ou publicação.

Limites da prova: o motor precisa confirmar armazenamento local do cliente, resposta dos cliques, posição do congelamento após spawn e ordenação real de remoção/reentrada. O mock de remoção cobre o frame corrente, e o de velocidade/input respeita valores imediatos por frame conforme a API; não reproduz todas as ordens possíveis do jogo. Não houve teste solo ou multiplayer observado desta versão. Recarregar o mapa é necessário para carregar os scripts atualizados.

### Preparação das imagens do Workshop

O usuário forneceu capturas reais de Jogadores e Ferramentas da versão 1.2.0. Elas demonstram a apresentação dessas telas no jogo, sem provar os comportamentos de persistência/multiplayer. A captura de Ferramentas foi convertida para `mod/preview.jpg` (1024×1024 com margens, abaixo de 1 MB); Jogadores foi ajustada para `mod/preview-menu.png` (512×292 com margens), referenciada em `info.txt`. As capturas originais em Downloads foram preservadas. Não houve geração de logo nem alteração do conteúdo da interface capturada.

O empacotador inclui as duas imagens nos ZIPs de instalação e fontes e recusa imagens ausentes, JPEG acima de 1 MB ou PNG com dimensões incorretas. A versão de código permanece 1.2.0. A miniatura é provisória e pode ser substituída em uma atualização do Workshop, preservando `id.txt`. A preparação das imagens não executou publicação no Workshop. Posteriormente, o usuário forneceu o destino Git; as prévias e a referência ao repositório são versionadas juntas.

### Logo e descrição do autor

As prévias provisórias de capturas foram substituídas pela logo fornecida pelo usuário em `Downloads/Logo.png`: JPEG de 512×512 para Steam e PNG de 512×292 para o menu, com margens pretas e sem geração de imagem. O original foi preservado. A descrição editada na Steam não havia sido transferida ao `info.txt` local, que ainda continha somente o resumo original. O conteúdo completo fornecido pelo autor foi copiado sem reescrita para `mod/WORKSHOP-DESCRIPTION.txt`, incluindo os parágrafos de divulgação do uso de IA; no `info.txt`, o mesmo texto fica em uma linha. O empacotador inclui esse arquivo nos dois ZIPs e verifica a igualdade do conteúdo normalizado.

A interface local do publicador lê `mods.publish.description`; a documentação informa que título/descrição/tags são preenchidos a partir de `info.txt`. Isso não comprova se o motor preserva as quebras de parágrafo da descrição remota durante uma atualização. O autor deve conferir o texto na tela de Publish update antes do envio e usar o arquivo completo para restaurar os parágrafos na Steam, se necessário. O `id.txt` instalado identifica o item existente e deve ser preservado; não entra nos ZIPs ou no Git. Esta entrega prepara os arquivos, sem executar upload ao Workshop.

### Versão 1.3.0: opções no menu principal

`options.lua` é uma entrada legada `draw()` do gerenciador, sem `#version 2`, jogador, mapa ou servidor. Inclui apenas helpers comuns e traduções. Permite idioma, captura do atalho validado e indicador de vida nas mesmas chaves usadas pelo cliente; oferece restauração das três preferências e uma restauração separada das regras de host deste computador com confirmação. Essa última limpa regras de sessão, ferramentas e escolhas de jogadores; recria os marcadores de existência dos perfis e preserva hostid, contadores e referências de identidade. Não altera hosts remotos, dados nativos ou preferências pessoais. Mudanças valem no próximo mapa.

O checker compila as duas entradas e executa o teste específico do menu em contexto sem API de jogador/servidor. O empacotador inclui options.lua nos dois arquivos e usa a raiz instalável `Open Session Panel`, com espaços. A interface do gerenciador usa `listname`, separado do `name` dos detalhes, e a lista local acompanha a pasta. A API não documenta o formato do ID após renomear a pasta. Nesta instalação, o teste do usuário abrindo Options e alternando o indicador confirmou a mudança de `local-opensessionpanel` para `local-open-session-panel`. Portanto, a renomeação exige transferir as preferências com o jogo fechado, mantendo a identidade do host, dos perfis e a referência do Workshop. A entrada do Workshop e seu id.txt não devem ser alterados.

Verificação da 1.3.0: sintaxe das entradas principal e Options, 8.066 asserções do cliente simulado, 184 do menu sem mapa e 182 do servidor passaram. A árvore extraída de fontes reproduziu os dois ZIPs byte a byte. O usuário abriu Options sem carregar um mapa e gravou a alteração temporária do indicador; não houve erro de Lua no log consultado. A posição e os textos também foram inspecionados em uma prévia sintetizada a partir das chamadas reais de desenho, sem apresentá-la como captura do jogo. A migração do namespace deve ser registrada no recibo central, separadamente dos arquivos distribuídos.

A migração local foi concluída com o processo do jogo encerrado: somente a subárvore OSP foi transferida para o identificador confirmado, incluindo identidade do host, perfis, referências e contadores. O indicador temporariamente ativado no teste foi restaurado ao valor anterior, desligado. O namespace antigo foi removido depois de provar igualdade do conteúdo no destino e igualdade byte a byte de todo o conteúdo fora desses dois nós. Backups comprimidos e recibo com hashes ficam na pasta central de backups, fora do mod, Git e pacotes. O id.txt do Workshop foi preservado.

### Iteração do bundle: paletas pessoais

`scripts/theme.lua` concentra presets, validação/persistência de RGB hexadecimal, contraste e o editor compartilhado. Não altera servidor nem regras de jogo. Clássica preserva o visual anterior; Oceano, Floresta, Violeta e Clara são alternativas. Personalizada permite as doze funções visuais por barras RGB arrastáveis, ajustes unitários, amostra e código hexadecimal. A seleção e as cores ficam em savegame.mod.osp.theme, compartilhadas entre Settings da partida e Options do gerenciador. Trocar presets não remove as cores personalizadas; restaurar preferências/paleta volta à Clássica sem apagar essas cores.

O cliente fornece coordenadas, recorte do viewport e consumo do mouse ao editor; a tela de Options fornece seu contexto sem mapa. Ambos usam o mesmo editor e respeitam soltura do mouse, bloqueio por modal e cancelamento de arrasto ao sair. Avisos de contraste e o botão de recuperação têm cores fixas para permitir recuperar uma paleta ilegível. Cores salvas inválidas usam o padrão, e valores RGB inválidos são rejeitados. Não há editor de transparência nesta entrega.

Verificação: testes de presets/contraste, RGB, persistência entre instâncias, dados inválidos, arrastar/soltar, recorte, recuperação e integração com as duas telas. Prévias sintéticas das chamadas reais de desenho foram inspecionadas em Oceano, Clara e Personalizada. O resultado visual e o arrasto no motor ainda precisam ser observados no Teardown.

### Iteração do bundle: remoção do indicador adicional de vida

O HUD adicional foi retirado por não fazer parte da proposta administrativa. Foram removidos sua renderização, os controles de Settings e Options e as referências na descrição distribuída. O HUD nativo não é alterado. O campo de vida na ficha do jogador, cura e regeneração continuam existindo como controles administrativos. A chave antiga health_hud não é lida nem escrita pelo mod; pode permanecer inerte no save, sem migração ou alteração de dados do jogo. Testes ligam essa chave antiga e confirmam que não há HUD extra, inclusive em uma nova instância. Os registros de versões anteriores acima são históricos.

Permissões verificadas: o host e os administradores nomeados têm acesso às funções administrativas. Convidados têm Settings e Sobre. Nomeação/revogação de admin, reinício de mapa, alterações diretas no host, persistência de escolhas por jogador e políticas gerais de ferramentas são exclusivos do host. Alterações individuais de delegados são temporárias; regras de sessão como clima, tempo e regeneração podem ser alteradas e persistidas também por eles. Não houve mudança de permissões nessa etapa.

### Iteração do bundle: permissões por ação e roles do host

A nova aba Permissões é exclusiva do host. Convidado, Apenas em si, Ajudante, Moderador e Administrador são roles prontas, somente leitura. O host cria uma cópia editável, com nome ASCII de até 40 caracteres, salva e atribui a um participante. A biblioteca admite 16 roles customizadas. Ações com alvo usam bloqueado/apenas em si/qualquer jogador; ações coletivas, anúncios, tempo, chuva, neblina, regeneração e restauração de todas as regras têm capacidades separadas. A role Apenas em si permite ir até outro jogador porque essa ação move somente o autor. Não concede alteração do destino. Não há restrição de ações normais no mundo.

`scripts/permissions.lua` define o vocabulário, os presets e a avaliação compartilhada. O servidor continua validando cada comando no momento da execução; os botões desabilitados no cliente apenas refletem a autorização. Gerenciamento de acesso/roles, alterações do host, restauração de perfis, reinício de mapa e políticas gerais de ferramentas são exclusivos do host e não podem ser delegados. A aba Jogadores perdeu os atalhos redundantes de bloqueio de ferramentas de mods; os filtros e controles individuais/coletivos continuam em Ferramentas.

Roles customizadas ficam em `savegame.mod.osp.templates`, com contador de IDs separado, e vínculos em `players.<perfil>.role`. Sem esse campo, a antiga flag admin é convertida em Administrador ou Convidado. Um papel explícito desconhecido é tratado como Convidado. Atribuir um acesso limitado grava admin=false para que uma versão anterior não interprete esse vínculo como acesso total. Editar uma role altera as autorizações de todos os vinculados no próximo comando. Excluir revoga vínculos online e offline; IDs excluídos não são reutilizados. Restaurar opções de host por Options remove os vínculos, mas preserva a biblioteca de roles e as identidades existentes.

`scripts/permissions_ui.lua` mantém o rascunho do host e envia as alterações pelo caminho de comando e resposta existente. Roles têm versão para recusar gravação/exclusão baseada em cópia antiga. A resposta aceita é mantida até a atualização de shared chegar, evitando perder a seleção ou reexibir role excluída por atraso de replicação. Nomes e capacidades inválidos são recusados; roles prontas não podem ser sobrescritos. Sair da tela cancela a captura de nome.

Verificação local: sintaxe Lua 5.1 e testes de autorização no servidor, aliases de ferramentas, autoaplicação versus outros alvos, proteção do host, revogação imediata, regras separadas, migração de admin, nova instância Lua, exclusão com perfil offline, limite da biblioteca e conflitos de versão. O cliente simulado cobre EN/PT, layouts estreito/largo, fluxo de cópia/edição/atribuição/exclusão, confirmação desatualizada, respostas antes da replicação, captura de texto e acesso por capacidade. Options confirma que a recuperação apaga vínculos e preserva roles. Prévias sintéticas da interface foram inspecionadas em 1024×768 e 1920×1080. Uma leitura independente apontou captura de nome ao fechar o painel; a correção ganhou cobertura de regressão. O desenho nativo, a persistência efetiva e a propagação multiplayer ainda precisam ser observados no jogo com os mesmos arquivos nos participantes.


### Iteração do bundle: editor de roles, Fly/Noclip e números digitáveis

A aba continua Permissões/Permissions. Os conjuntos de acesso são chamados Role/Roles nos dois idiomas. A tela inicial serve para selecionar jogador, consultar a role atual, escolher/atribuir uma role e ver uma prévia somente leitura. Criar role customizada ou Editar role customizada abre um editor separado, sem seleção de jogador ou atribuição. Nome, capacidades editáveis, salvar, descartar/recarregar e excluir aparecem apenas nesse editor. Salvar retorna à atribuição com a role aceita selecionada, mesmo antes de shared atualizar. Descartar retorna sem gravar.

Fly agora habilita voo com o colisor normal do personagem; dois pressionamentos do salto lógico em até 0,3 segundos alternam o voo ativo. O movimento horizontal usa a orientação horizontal da câmera, Saltar sobe e Agachar desce. O servidor mantém flyMode=false, não altera CollisionMask nem teleporta o personagem para voar. A velocidade é aplicada no update de física, compensando GetGravity() apenas para o personagem naquele passo. Noclip mantém o comportamento anterior, com flyMode nativo e direção completa da câmera. Habilitar um modo desabilita o outro. Congelamento, morte, respawn e entrada em veículo encerram o voo ativo; o duplo salto precisa ser repetido. A habilidade concedida pelo host persiste; estar voando não persiste.

Compatibilidade de movimento: o antigo campo de jogador fly é interpretado como Noclip. O novo Fly usa flight; noclip e fly legado são espelhados quando o host salva. Roles customizadas antigas que concediam fly passam a conceder Noclip, sem receber automaticamente a capacidade nova. Em roles novas/editadas, permissions.flight guarda a capacidade Fly, permissions.noclip guarda Noclip e permissions.fly espelha apenas Noclip. A presença de permissions.noclip distingue o formato novo. Não há alteração direta no save durante a instalação; a leitura e as gravações normais do mod cuidam da compatibilidade.

Os valores de velocidade (0,5–3), escala de tempo (0,1–2), chuva (0–1), neblina (10–1000 m) e canais RGB (0–255) podem ser digitados. Enter confirma e selecionar outro controle descarta a edição incompleta. O valor é arredondado conforme a precisão do campo e limitado à faixa permitida. Ponto e vírgula decimal são aceitos; entrada vazia/inválida não grava. Os botões de ajuste e barras continuam disponíveis. A edição usa scripts/number_input.lua, compartilhado entre o painel e Options; controles de gameplay mantêm a validação de acesso no servidor.

Verificação desta etapa: testes locais de modos separados, descarte/ACK e captura de nome; limites e confirmação de números; migração dos dois modos de movimento e capacidades; duplo salto, pausa/UI, velocidade diagonal, gravidade, congelamento, veículo e morte/respawn. A revisão independente encontrou voo ativo sobrevivendo a respawn explícito ou kill+heal antes de outro tick; os comandos e a transição de vida passaram a cancelá-lo, com regressões dos dois casos. Prévias sintéticas da atribuição, do editor de roles e dos campos numéricos foram inspecionadas em 1024×768 e 1920×1080. O mock comprova os parâmetros e a aritmética; não comprova a ordem interna do controlador de personagem do motor. Conferir no jogo: parede e teto seguram Fly, o personagem paira sem deriva, dois saltos alternam sem repetir ao segurar, e Noclip atravessa a mesma parede. Aparência nativa, hover, colisão e sincronização multiplayer continuam pendentes de observação.


### Ciclo 1 do bundle 1.4.0: velocidades finais de Fly e Noclip

O usuário confirmou colisão e comandos de Fly no jogo antes desta revisão. O ciclo aprovado conclui o ajuste pendente de Fly e acrescenta o mesmo fluxo ao Noclip. Não inclui outros itens do backlog.

Cada modo tem seus próprios valores normal/Shift: padrões 9/18 m/s, faixa 0,5–100, duas casas decimais. São velocidades finais, independentes do multiplicador geral do jogador, que continua funcionando no movimento normal. Shift seleciona o segundo valor enquanto estiver pressionado; soltar restaura o normal. O segundo valor pode ser menor por escolha do usuário. Sem direção de movimento, Shift não causa deslocamento; a compensação de gravidade do Fly não é multiplicada.

Fly e Noclip ficam lado a lado na mesma linha. Os botões de reticências ao lado dos toggles On/Off abrem um popup central com campos e instruções do modo selecionado, separado da rolagem da página. Clique fora ou X fecham a janela sem acionar controles ao fundo; fechar descarta apenas o valor ainda não confirmado. Reutilizam NumberInput: Enter confirma e selecionar outro controle descarta a edição incompleta. Aceitam ponto/vírgula decimal e limitam o valor à faixa permitida. Configurar não ativa o modo. Duplo salto do Fly, ativação atual do Noclip, colisão e exclusão mútua dos modos permanecem.

O servidor mantém flight_speed/flight_boost e acrescenta noclip_speed/noclip_boost por perfil. Campos ausentes ou inválidos usam os padrões; não há migração destrutiva. Identidades, roles e flags legadas permanecem. Os comandos fly_speed/fly_boost e noclip_speed/noclip_boost usam a capacidade correspondente, incluindo alcance, proteção do host e identificação antes de persistir. Escolhas do host persistem; delegados alteram temporariamente. Restaurar o jogador devolve os quatro padrões; alternar modos não apaga seus ajustes.

Validação local cobre velocidades finais, Shift/soltura, diagonais, repouso, restauração do multiplicador de caminhada, independência dos modos, nova missão/ID, dados inválidos e autorização. A UI cobre os dois idiomas, alinhamento dos toggles, popup em 640×480/1024×768/1920×1080, campos inteiros visíveis, fechamento externo/Esc/X, bloqueio de cliques e rolagem ao fundo, limites e captura de alvo. Prévias sintéticas do popup foram inspecionadas; aparência e interação nativas ainda dependem de observação no jogo. A confirmação anterior de colisão não prova as novas velocidades/Shift ou a sincronização multiplayer: conferir no jogo cada modo normal/Shift, multiplicador geral 2× sem alterar o voo e persistência após missão. O pacote e a instalação continuam com fonte legível e identidade do Workshop preservada.

Backlog restante, para ciclos posteriores após avaliar este: impedir Bring here no próprio jogador; pesquisar ferramentas e reorganizar Tools; melhorar identificação dos botões Close/navegação; tamanho de fonte/janela; importar/exportar configurações; dicas contextuais globais; shortcuts opcionais sem padrão; ocultar/mostrar abas com reajuste da navegação. Não há plano de implementação desses itens neste ciclo.


### Ciclo 2 do bundle 1.4.0: busca e ações de Tools

Busca local por nome traduzido/ID, literal, sem distinção de caixa ou acentos latinos comuns, combinada com Todas/Vanilla/Mods. Entrada ASCII até 80 caracteres; Enter deixa o campo, X limpa. Termo permanece nesta missão ao navegar/reabrir, sem gravar no save. Alterar termo/categoria reinicia paginação. Lista mostra encontrados/total da categoria e estado vazio específico.

Ações em grupo e secundárias foram reunidas em popups, preservando toggle principal por linha. Regras globais oferecem ativar/bloquear/padrões; modo por jogador distingue alvo selecionado e todos os presentes (exceto host para delegados). Popup congela IDs de todas as páginas, categoria, consulta e alvo; as confirmações exibem contexto e quantidade. Clique fora ou X fecham sem acionar controles ao fundo. A busca não interfere na digitação de anúncios, roles ou números.

Os novos comandos tools_selection/tools_selection_all/tool_policy_selection recebem IDs explícitos e categoria. Não há fallback para comandos amplos de categoria. Servidor valida seleção não vazia, densa, única, limitada ao catálogo e compatível com categoria antes de alterar estado. Ferramenta removida causa indisponibilidade, ferramenta nova não entra automaticamente. Mantêm capacidades, proteção do host, persistência, bloqueio global dominante e limpeza de overrides offline somente dos IDs envolvidos. Comandos antigos e namespace de save não mudam. Histórico registra quantidade validada sem copiar a consulta ou lista arbitrária.

Validar no jogo uma busca com duas ferramentas encontradas e uma fora: aplicar uma ação em grupo deve preservar a terceira, incluindo quando os resultados ocuparem várias páginas. A verificação automatizada e as prévias sintéticas não substituem essa observação nem o teste multiplayer. Outros itens do backlog permanecem fora deste ciclo.

Limitação observada pelo usuário no jogo: Esc abre a pausa nativa e, ao voltar, o painel ou popup pode continuar aberto. As dicas orientam usar Fechar no painel e X ou clique fora nos popups. O tratamento existente de Esc permanece, mas não é anunciado como forma garantida de fechamento ou cancelamento. Os testes locais de Esc citados acima simulam a entrada e não demonstram sua captura no motor.

Nas ações em grupo de Ferramentas, os botões Ativar/Bloquear categoria permanecem visíveis e atuam na categoria inteira, independentemente da pesquisa. Com texto na busca, uma linha adicional Ativar/Bloquear resultados aparece entre a categoria e Usar padrões. Sem texto, essa linha desaparece; com texto e zero correspondências, fica desabilitada. Não há seletor de alcance. As duas listas de IDs são congeladas ao abrir o popup, e o cabeçalho mostra suas contagens. Padrões afeta a categoria inteira e permanece centralizado com largura normal. No modo por jogador, há linhas distintas de categoria/resultados tanto para o selecionado quanto para todos os presentes; a altura do popup se ajusta para acomodá-las dentro do painel. Confirmações usam os IDs e a contagem do botão acionado, incluindo a consulta apenas nas ações de resultados. Pesquisa, comandos explícitos, permissões e validação do servidor são preservados. Testes locais cobrem os dois idiomas, 640×480/1024×768/1920×1080, ordem e limites dos controles, pesquisa vazia/sem correspondências, IDs que surgem após abrir, envio de seleções de categoria/resultados e permissões delegadas/revogadas. A aparência nativa desta revisão ainda precisa de observação no jogo.
