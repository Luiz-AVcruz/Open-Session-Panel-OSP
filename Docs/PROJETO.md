# Open Session Panel

## Objetivo e prioridades

Painel independente de administração de Teardown, modificável e redistribuível, por **Luiz-AVcruz**. Público: host, administradores nomeados e jogadores de sessões cooperativas. Prioridades desta revisão: cliques responsivos em todo o botão, atalhos de ferramentas de mods e persistência das escolhas do host por jogador.

A v1.0 foi implementada e copiada para mods locais. O log confirma seu carregamento; o usuário observou que o menu era grande, pouco adaptável e visualmente insatisfatório. O layout anterior de 1400×880 era redimensionado inteiro. A revisão 1.1 trata esses problemas sem alegar que os testes anteriores demonstraram usabilidade.

## Escopo da versão 1.2.0

- Jogadores: cura, morte confirmada, respawn, ir até/trazer jogador, retirada de veículo, congelamento, invencibilidade, voo e velocidade.
- Sessão: cura coletiva, trazer participantes, regeneração nativa, tempo, chuva, neblina, restauração de padrões, reinício confirmado e anúncios.
- Ferramentas: filtros Todas/Vanilla/Mods; regras gerais e escolhas por jogador persistentes quando feitas pelo host; alterações de delegados temporárias. Atalhos de bloqueio de ferramentas de mods por jogador e para todos, com confirmação do alcance.
- Perfis por jogador: ferramentas, invencibilidade, voo, congelamento, velocidade e admin salvos pelo host; restauração dos padrões pessoais sem remover regras gerais.
- Atividade: até cem ações, autor, alvo, resultado e contagem de afetados/ignorados.
- Interface: janela central limitada a 1120×720 unidades e a 85% da largura/82% da altura disponíveis; colunas e linhas adaptadas à área, navegação superior em telas estreitas; paginação/rolagem conforme o conteúdo.
- Configurações: idioma, atalho e indicador adicional de vida. Sobre: versão, autoria, licença e código. Ambas são acessíveis aos convidados. Anúncios ficam na seção Sessão.
- Indicador de vida adicional, individual, persistente e desligado no primeiro uso. Preserva integralmente a barra nativa; lê vida real sem alterar vida, regeneração ou flags globais de HUD.
- Inglês padrão e português brasileiro. Nome público e autoria: **Luiz-AVcruz**.

Permanecem fora da entrega: armadura, vida ampliada, dano de queda próprio, minimapa, substituição do HUD nativo, modo foto, kick/ban e integrações específicas com outros mods.

## Autoridade, dados e recuperação

Lógica de jogo no servidor, apresentação no cliente e dados serializáveis em `shared`. Somente o host nomeia administradores, altera diretamente o host, reinicia o mapa ou grava escolhas persistentes. Comandos temporários de administradores protegem o host também nas operações coletivas e não sobrescrevem as escolhas salvas do host.

A identidade de remetente do `ServerCall` não é autenticada pela API documentada: o modelo pressupõe clientes normais e não é anunciado como anticheat. Cada ação valida papel, alvo e argumento no momento de execução; respostas são correlacionadas por identificador. Após oito segundos sem resposta, o cliente indica resultado desconhecido, permite nova ação e ignora respostas antigas; nunca repete comandos automaticamente.

Idioma, atalho e indicador são preferências locais. Tempo, chuva, neblina, regeneração e políticas de ferramentas ficam na área própria do mod no host. Preferências anteriores são preservadas; indicador ausente significa desligado e política de ferramenta ausente significa padrão do jogo. Nenhum dado em `savegame.tool` é escrito.

Políticas de ferramentas são indexadas por ID codificado, sem depender do ID temporário do jogador. Aplicam-se ao host, participantes presentes, novos participantes, respawns e ferramentas registradas mais tarde. Ferramentas ausentes mantêm sua preferência. Bloqueio geral domina habilitação individual. Mudar uma política geral remove as substituições pessoais daquele ID, inclusive perfis salvos de jogadores offline; depois disso, uma restrição individual pode limitar uma política habilitada. O estado padrão remove a política e restaura o valor capturado antes da primeira intervenção no mapa atual; a próxima missão usa seus próprios padrões. Ações de categoria abrangem os IDs registrados no momento, sem criar uma regra para futuros IDs desconhecidos.

A classificação Vanilla usa os 17 IDs do catálogo base e camera/minigunmall/snowball, confirmados na instalação. Não usa grupos de inventário e não incorpora código do jogo. Outros IDs são Mods, inclusive exemplos opcionais fornecidos pelo jogo. Reutilizar um ID vanilla implica compartilhar sua classificação.

O host salva ferramentas e opções pessoais por perfil: invencibilidade, voo, congelamento, velocidade e admin. Ações pontuais, como cura e teleporte, não são repetidas ao carregar uma missão. Congelamento usa a posição de entrada do novo mapa. Restaurar um jogador limpa suas escolhas e retorna às bases capturadas neste mapa, mantendo as regras gerais. Alterações temporárias de delegados terminam na saída/recarga; IDs reutilizados não herdam permissões.

A [API pública 2.2.0](https://teardowngame.com/modding/api.html#GetPlayerName) expõe nomes e IDs de sessão, sem vínculo documentado com uma conta estável. O mod mantém um namespace persistente no host, emite um perfil por contador e guarda sua referência no cliente para aquele host. O handshake ocorre antes de liberar alterações persistentes do host; repetições retornam a mesma identidade na sessão. Cada entrada recebe um marcador sequencial do servidor, mantido entre contextos Lua: pedido e resposta precisam corresponder à entrada atual, evitando vinculação ou escrita por mensagens antigas. Perfil ausente/desconhecido recebe um perfil novo sem permissões; uma referência já em uso por outro participante recebe um perfil separado. Referências pessoais de perfil não ficam em `shared` nem no histórico; namespace e marcador de entrada são públicos. Eles não são credenciais criptográficas e o perfil enviado pelo cliente não é autenticado. Copiar/apagar dados locais, mudar de instalação ou trocar host pode perder ou copiar a referência; não é identidade de conta. A persistência real do armazenamento do cliente e a ordenação do handshake precisam de confirmação no motor.

Antes de remover o mod, restaurar regras conforme desejado e recarregar o mapa. `server.destroy` só é garantido para game modes e não é a base de recuperação deste mod global.

## Organização e comandos

Lua 5.1, scripting version 2 do Teardown, sem dependências no runtime. Código jogável em `mod/`, teste do contrato do servidor/cliente em `tests/`, ferramentas locais em `tools/`. A versão de produto é **1.2.0**; `version = 2` no manifesto continua significando a geração do scripting.

```sh
python3 tools/check.py
python3 tools/package.py
```

O empacotador produz ZIP instalável, ZIP de fontes e hashes determinísticos. O pacote não inclui `.git`, identificadores de Workshop, backups, tokens ou assets proprietários. Não é necessário Python para jogar.

## Licença e publicação

AGPLv3 ou posterior para o código próprio, com permissão adicional restrita ao runtime/API do Teardown. Manter o texto GNU e sua atribuição original; a identificação de autoria do projeto é Luiz-AVcruz. Código independente, sem copiar scripts ou assets do Admin Panel.

O pedido de Git autoriza versionamento local desta entrega. Não há remoto configurado nem publicação autorizada para um destino definido. A aceitação multiplayer normal depende de publicação autorizada e arquivos idênticos entre participantes.

## Verificação e próximo ponto de retomada

Registrar a seguir a evidência efetivamente obtida nesta revisão, distinguindo testes locais, prévia ilustrativa, instalação e observação dentro do jogo. O backup central da árvore de projeto e da cópia instalada da v1.0 foi compactado e validado antes das alterações.

Para testar no jogo: carregar sandbox somente com este painel administrativo; conferir Players/Session/Tools/Activity/Settings/About em EN/PT, foco de anúncio, modais, navegação e rolagem. Testar o indicador desligado/ligado, dano, cura, morte e respawn. Alternar políticas de Vanilla/Mods, trocar missão, entrar outro jogador e registrar ferramentas tardiamente. Restaurar padrões e confirmar que a próxima missão segue o jogo. Repetir com host/admin/convidado antes de afirmar suporte multiplayer observado.

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
