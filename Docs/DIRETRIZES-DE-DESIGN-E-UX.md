# Diretrizes de design e experiência de uso

Este guia transforma a leitura integral das 46 transcrições da seleção “Design e UX/Shorts”, de Rian Dutra, em critérios para projetar, implementar e revisar interfaces. Complementa as [diretrizes de desenvolvimento](DIRETRIZES-DE-DESENVOLVIMENTO.md). Aplica-se quando o trabalho altera a experiência de alguém com um produto ou serviço; não impõe um processo de design a toda tarefa técnica.

As referências R01–R46, ao final, permitem localizar cada conteúdo. Os textos locais são transcrições automáticas com revisão pontual, não conferência auditiva palavra por palavra. Esta síntese não equivale a assistir novamente aos vídeos ou verificar todas as pesquisas e histórias citadas pelo autor.

## 1. Começar pela tarefa e pelo contexto

Definir quem precisa fazer o quê, em qual situação e o que hoje dificulta esse resultado. A solicitação de uma tela ou botão pode descrever apenas o ponto em que o problema aparece. Percorrer também a origem da necessidade, o caminho até esse ponto e o que acontece depois. (R01–R03, R11, R14–R16, R46.)

Separar fatos observados, preferências, hipóteses e decisões comerciais. A preferência estética do responsável é um requisito legítimo quando faz parte do projeto; não deve ser apresentada como prova de comportamento de todo o público. Uma hipótese sobre conversão também não substitui uma orientação explícita sobre a marca.

Escolher prioridades e assumir renúncias. Uma página de apresentação precisa tornar a oferta reconhecível e permitir encontrar informação. Uma ferramenta operacional pode exigir velocidade, precisão e recuperação de erros. O mesmo padrão visual pode servir a uma e atrapalhar a outra.

Representar o percurso na menor forma que ajude a decidir: uma frase, uma sequência de passos ou um diagrama, conforme a complexidade. Considerar leitura, decisões, deslocamentos, preenchimento, espera, erros e recuperação; contar cliques sozinho não mede o esforço.

## 2. Investigar sem fabricar a resposta

Quando houver dúvida sobre necessidades ou dificuldades, perguntar por situações concretas: a última tentativa, o que a pessoa fez, onde parou e como resolveu. Perguntas que apresentam primeiro a solução ou pedem aprovação tendem a produzir respostas pouco discriminantes. (R04–R08, R12–R13.)

Combinar relato com observação de tarefas quando isso puder mudar a decisão. Observar também exige cuidado: a presença de quem pesquisa pode alterar o comportamento. Não interpretar uma entrevista, um teste acompanhado ou um evento isolado como acesso infalível à verdade.

A sondagem e os porquês ajudam a explorar explicações. Não são um detector de mentira nem exigem repetir cinco perguntas mecanicamente. Reformular com neutralidade, dar espaço à pessoa e confrontar a explicação com outras evidências. Interrogatório, indução e constrangimento não melhoram a qualidade da pesquisa.

Examinar a origem e os limites da amostra: quem participou, em qual contexto, em que período e com qual denominador. Elogios e intenção declarada de compra não comprovam demanda; reclamações podem ser relevantes mesmo quando vêm de poucas pessoas. Silêncio pode ter várias explicações, incluindo satisfação, indiferença ou abandono. (R06–R10.)

A profundidade acompanha a incerteza. Uma correção conhecida pode dispensar pesquisa nova. Quando a próxima decisão já estiver sustentada, implementar e avaliar seu efeito; não prolongar entrevistas ou documentação por obrigação de método.

## 3. Organizar informação para atenção limitada

A pessoa deve reconhecer rapidamente o assunto, o que pode fazer e por onde seguir. Usar linguagem familiar e tornar explícito o que a equipe já considera óbvio. Projetar para pressa, distração, conhecimento parcial e condições variadas de uso, sem atribuir essas dificuldades a defeitos da pessoa. (R17–R24.)

Priorizar a informação que sustenta a tarefa. Títulos, grupos, rótulos e espaçamento devem permitir leitura rápida; detalhes necessários continuam disponíveis. Texto conciso não significa esconder condições, riscos, preços ou consequências importantes.

Verificar se o desenho parece terminar antes do conteúdo real. Um painel de altura de tela, uma faixa ou um carrossel podem criar uma falsa impressão de completude. Tornar a continuidade perceptível por conteúdo, navegação ou sinais claros; não depender de a pessoa descobrir uma área escondida.

Informação presente no HTML ou visível na tela pode passar despercebida. Posicionar a orientação junto à decisão correspondente e avaliar se compete com elementos mais chamativos. Movimento, contraste e posições incomuns têm custo de atenção; utilizá-los com propósito, respeitando acessibilidade e a tarefa.

## 4. Dar direção à composição visual

O visual deve expressar o assunto e a identidade do produto. Antes de reutilizar um layout, identificar o que ele destaca, para quem foi pensado e quais comportamentos pressupõe. Uma composição pronta não passa a ser adequada apenas porque funcionou em outro negócio. (R23, R33–R35.)

Como complemento de composição, os princípios de escala, hierarquia, equilíbrio, contraste e agrupamento ajudam a revisar o desenho: destacar o que importa, aproximar elementos relacionados e distribuir o peso visual. Definir uma ordem de leitura e conferir se tamanho, cor e posição a sustentam. A referência complementar é [5 Principles of Visual Design in UX, do Nielsen Norman Group](https://www.nngroup.com/articles/principles-visual-design/).

Na implementação, escolher tipografia, paleta, alinhamentos e espaçamentos coerentes com a marca e com o conteúdo real. Variar a composição quando a informação muda, mantendo padrões reconhecíveis para ações equivalentes. Evitar tanto uma sequência automática de cartões genéricos quanto ornamentos sem função que disputem a atenção com a oferta.

Usar imagens para tornar o assunto concreto. Confirmar o que representam e os direitos de uso. Fotos, depoimentos, resultados, avaliações e produtos reais precisam de fonte. Um mock autorizado deve ser identificado como ilustrativo; não pode prometer um produto ou acabamento ainda não confirmado.

Esses critérios orientam decisões, não determinam uma estética universal. Uma interface pode ser expressiva e fácil de usar; aparência agradável e sucesso de tarefa precisam de avaliações próprias.

## 5. Fazer a ação cumprir a promessa

O texto, a aparência, o contexto e o destino de uma ação devem comunicar a mesma coisa. Um botão para consultar informação deve levar a essa informação; uma contratação, cobrança, assinatura ou saída para outro serviço precisa ser reconhecível antes do compromisso. Texto pequeno não deve contradizer a mensagem dominante. (R20, R40–R43.)

Pedir dados e esforço quando sua necessidade estiver clara. Explicar o que o produto oferece antes de exigir cadastro ou outro compromisso que a tarefa não requer. Aumentar confiança por clareza, funcionamento e condições compreensíveis; não presumir que todo produto precise de teste gratuito ou de um funil de captura.

Manter recusas e saídas compreensíveis. Não adotar constrangimento para rejeitar uma oferta, escolhas caras pré-selecionadas sem intenção do usuário, escassez inventada ou ofertas que não existem. Os exemplos de padrões sombrios no material são advertências, não técnicas a incorporar.

## 6. Comunicar estado e preservar controle

Quando houver processamento ou espera relevante, indicar o que está acontecendo e qual estado foi realmente atingido. Distinguir ação recebida, trabalho em andamento, conclusão, falha e possibilidade de repetir. Mostrar progresso mensurável quando existir; não inventar porcentagens ou afirmar conclusão antes do efeito real. (R25–R28.)

Dividir tarefas longas em partes quando isso reduzir esforço e permitir orientação. Mostrar etapas concluídas e o que falta, sem acrescentar um onboarding a um produto que já pode ser compreendido diretamente.

Atrito pode proteger decisões com consequências: confirmar exclusão definitiva, apresentar condições ou permitir revisão antes de compartilhar dados. Dimensionar a proteção pelo risco e pela possibilidade de desfazer. Não exigir confirmação para toda ação rotineira nem acrescentar demora artificial como regra de confiança.

Separar a duração real da percepção da espera. A orientação sobre o andamento deve ajudar a decidir e manter expectativas honestas; distrair ou enquadrar um intervalo não autoriza esconder a duração total ou um problema do serviço.

## 7. Comparar e testar com uma pergunta concreta

Quando a escolha visual ou de fluxo ainda estiver aberta, comparar alternativas que possam mudar a decisão. Elas podem ser descritas, esboçadas ou implementadas parcialmente; não é obrigatório construir várias aplicações completas ou um teste A/B para toda edição. (R19, R29–R30, R34–R35, R39, R43.)

Escolher uma tarefa observável e conferir se a pessoa consegue executá-la sem receber a resposta durante o teste. A familiaridade de quem construiu não comprova facilidade para outras pessoas. Registrar onde a pessoa hesitou, interpretou algo de outra forma, errou ou precisou de ajuda.

Separar três avaliações: aprovação estética e comercial do responsável, integridade técnica da implementação e resultado observado em uso. Uma não substitui as outras. Um build aprovado não mostra se a página está bem composta; uma opinião favorável sobre o visual não confirma uma tarefa concluída.

Usar os achados para mudar o produto. A existência de um teste não é uma melhoria por si. Revisar a hipótese quando a evidência a contradisser e repetir apenas a conferência afetada. Um pequeno diff pode mudar uma decisão importante; escolher a validação pelo efeito, não pelo número de linhas.

## 8. Incluir acessibilidade e adaptação na construção

Os critérios abaixo são complementos técnicos da W3C, não números atribuídos aos shorts:

- Para texto comum, conferir contraste mínimo de 4,5:1; para texto grande segundo a definição do critério, 3:1. Existem exceções, como logotipos. Conferir os estados e pares de cores efetivamente usados. [WCAG 2.2, contraste mínimo](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).
- Para conteúdo de rolagem vertical, conferir reorganização em largura equivalente a 320 pixels CSS, considerando as exceções do critério para conteúdos que precisam de duas dimensões. Não esconder cortes ou perda de informação com uma regra global de overflow. [WCAG 2.2, reflow](https://www.w3.org/WAI/WCAG22/Understanding/reflow.html).
- Conferir tamanho e espaçamento dos alvos. O critério AA estabelece 24 por 24 pixels CSS ou as condições de suas exceções; controles principais podem se beneficiar de áreas maiores. Isso não torna 44 pixels um mínimo universal. [WCAG 2.2, tamanho mínimo de alvo](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html).

Verificar também semântica, nomes acessíveis, teclado, foco perceptível, ampliação, ordem de leitura e preferências de movimento conforme o comportamento entregue. Tamanho de fonte, comprimento de linha e área de toque precisam funcionar em uso, além de existir no CSS.

Essas conferências isoladas não autorizam declarar conformidade integral com WCAG. Registrar os dispositivos, estados e condições observados e as limitações restantes.

## 9. Medir o resultado que importa

Definir qual decisão uma métrica pode orientar antes de instalar instrumentação. Origem de acesso, ações, percurso e abandono podem ajudar, mas precisam de contexto e de uma pergunta. Mais rolagem, mais cliques, mais sessões ou mais tempo podem representar interesse ou dificuldade. (R31–R33.)

Se houver retenção, churn ou valor de cliente, definir população, período, coorte e denominadores de forma consistente. Não transplantar métricas de assinatura para um produto de consulta eventual apenas porque aparecem em um exemplo.

Confrontar medidas com a tarefa e com relatos ou observação. Não afirmar causalidade a partir de uma coincidência. Evitar coleta e serviços de analytics por padrão: sua utilidade, custo, condições de privacidade e adequação pertencem ao projeto.

## 10. Tratar redesign e serviço como continuidade

Antes de mudar uma interface usada, identificar os hábitos, caminhos e compromissos que as pessoas já têm. Preservar pontos de orientação úteis e explicar alterações relevantes. Reação negativa pode indicar custo de adaptação ou um problema real; investigar em vez de descartar a crítica como resistência. (R09–R10, R36–R39.)

Uma transição gradual ou uma opção de voltar pode ajudar quando há necessidade e viabilidade. Manter duas interfaces permanentemente não é uma obrigação geral: avaliar custo, compatibilidade, suporte e possibilidade real de recuperação.

Projetar além da tela inicial: o que ocorre com arquivos, permissões, cobranças ou dados quando alguém sai de uma equipe, perde acesso ou encerra uma conta? Diferenciar remoção de acesso, transferência e exclusão. A interface deve refletir o contrato real do serviço e comunicar consequências antes da ação. (R44.)

## 11. Aplicar o mesmo critério ao trabalho com IA

Relacionar a solução ao objetivo humano e às consequências, mesmo quando a execução for delegada a um agente. IA não transforma uma tela produzida rapidamente em uma experiência validada. Ferramentas e patrocinadores citados nos vídeos são exemplos, não dependências obrigatórias. (R33, R45–R46.)

Definir o grau de autonomia, a participação desejada e as ações que exigem revisão conforme a tarefa e as autorizações existentes. Permitir examinar propostas ainda modificáveis. Encerrar a implementação não equivale à aprovação do responsável, nem autoriza automaticamente commit, push ou publicação.

Consultar o contexto do projeto para decidir quando explicar e quanto aprofundar. Este guia não exige que toda pessoa compreenda toda a implementação antes da entrega, nem estende uma preferência de aprendizado de um projeto para todos os outros.

## 12. Registrar apenas o que permite continuar

Em uma mudança relevante de interface, deixar compreensíveis a tarefa, a direção adotada, as informações confirmadas, as incertezas e como avaliar o resultado. Usar o documento de contexto e as instruções existentes; criar artefatos extras somente quando ajudarem a comparar, implementar ou validar.

Um registro curto pode responder:

1. Quem deve conseguir fazer o quê?
2. O que precisa aparecer primeiro e por quê?
3. Que informação ou ação deve ficar fácil de encontrar?
4. Que expectativa, erro ou consequência precisa ser tratada?
5. O que foi observado tecnicamente, visualmente e em uso?
6. O que ainda depende de conteúdo, decisão ou aprovação?

Selecionar as perguntas pertinentes. Não transformar esse roteiro em um formulário obrigatório para uma pequena correção conhecida.

### Aprender com as revisões visuais

Os critérios abaixo complementam as fontes com aprendizados da prática de revisão de projetos. Não definem uma estética universal nem são afirmações atribuídas a uma transcrição específica.

- Avaliar cada região e sua relação com o conjunto. Aplicar a mesma paleta não garante continuidade de composição; uma área final pode precisar de outro tratamento que a abertura.
- Separar a expressão da identidade dos papéis de leitura, títulos e ações. Uma fonte marcante no logotipo não precisa se repetir em todo o conteúdo. Ao mudar a aplicação tipográfica, conferir arquivos e pesos reais, escala, entrelinha, larguras e carregamento.
- Atribuir função às superfícies e cores. Alternar matizes próximos sem uma razão de agrupamento pode fragmentar a página. Contraste suficiente não demonstra, sozinho, conforto cromático; avaliar a combinação no conjunto e segundo o contexto.
- Distinguir margem geométrica de limite percebido. Identificar se a delimitação necessária pertence à página, à seção ou ao grupo de conteúdo. Uma moldura externa pode reduzir o aproveitamento da tela, mesmo quando o objetivo era apenas agrupar elementos. Conferir enquadramento, bordas, alinhamentos e contraste no conjunto; somar padding em cada camada pode reduzir desnecessariamente o espaço útil em telas estreitas.
- Dar às telas amplas uma composição própria quando o conteúdo justificar. Responsividade inclui largura útil, escala e densidade no desktop, além de empilhar no celular. Conferir o efeito dos tetos de largura em monitores grandes e distinguir uma prévia em janela estreita do uso em um aparelho real.
- Avaliar o logotipo junto ao fundo e à escala de aplicação. Conferir variantes originais antes de recolorir a marca; cada recurso pode exigir dimensões e janela de apresentação próprias. Uma versão adequada ao fundo claro não se torna adequada ao escuro apenas por manter o mesmo tamanho.
- Dimensionar o peso visual pelo conteúdo e pela tarefa. Uma superfície de alto contraste pode dominar mesmo com pouco texto. Não preencher espaço com frases, imagens ou alegações sem fonte para justificar um bloco grande.
- Distinguir legibilidade técnica de hierarquia percebida. Contraste suficiente e texto sem corte não provam que a informação importante recebeu tamanho, posição e espaço adequados.
- Repetir uma ação quando o percurso justifica. Remover duplicação imediata sem função, preservando acessos úteis depois de uma consulta ou decisão.
- Preservar trechos aceitos em uma avaliação parcial. Delimitar a alteração, conferir a transição com o trecho preservado e não tratar esse aceite como aprovação da página inteira ou autorização de publicação.

Registrar de forma curta a observação, a decisão, o resultado observado e o que continua pendente. Separar preferência do projeto de critério transferível: a rejeição de uma faixa escura em uma composição não torna faixas escuras inadequadas em todos os sites. Incorporar feedback ao registro existente, em vez de acumular recomendações sem conferir seus efeitos.

## Limites da interpretação

Os vídeos são exposições breves, com exemplos, humor e publicidade. Funcionam como fontes para raciocínio e hipóteses, não como demonstrações científicas de toda afirmação.

- R01, R07, R12 e outros itens têm trechos de ASR explicitamente incertos. Não reconstruir uma frase duvidosa como se tivesse sido conferida no áudio.
- R09 e R10 apresentam possibilidades diferentes para o silêncio do usuário. A síntese preserva a incerteza em vez de deduzir satisfação ou fracasso.
- “Mais texto é pior”, “não fazer pensar”, as três etapas de um exemplo e as formulações sobre atenção são orientações de contexto. Não autorizam ocultar conteúdo necessário ou retirar deliberação em escolhas importantes.
- O nome e o limiar de tempo em R26, as estatísticas em R28 e R37 e as explicações psicológicas citadas não foram auditados em suas pesquisas originais. Não viram metas numéricas universais ou garantias de resultado neste guia.
- O relato de Snapchat em R37 não estabelece, por si, a causa de uma variação financeira. O caso de Dropbox em R44 orienta a examinar contratos e comunicação; não descreve o comportamento atual de todo serviço semelhante.
- R38 recomenda escolha durante a transição. A aplicação precisa considerar a viabilidade de manter versões e o risco de cada mudança.
- R40 descreve padrões sombrios de modo crítico. R41 mostra uma discrepância entre promessa e destino; ambos sustentam clareza e autonomia.
- A transcrição de R43 registra inconsistência na identificação das variantes A e B. Preserva-se a comparação de estratégias; não se deduz uma variante vencedora, divisão real do experimento ou aumento comprovado de conversão.
- O futuro e os efeitos cognitivos discutidos em R45 têm caráter argumentativo e especulativo. Não se afirma uma perda inevitável de capacidade humana por usar IA.

O registro de fontes abaixo cobre os 46 textos lidos integralmente em 21/10/2026. Ele permite localizar o argumento original sem exigir acesso ao vault pessoal ou copiar as transcrições para um novo projeto.

## Mapa das 46 transcrições

| Referência | Conteúdo original | Aplicação e limite |
| --- | --- | --- |
| R01 | [Prioridades para iniciar um projeto](https://www.youtube.com/shorts/9yloa7FHXKI) | Priorizar, dividir o trabalho e assumir renúncias conforme o objetivo. |
| R02 | [Investigar o caminho até o problema](https://www.youtube.com/shorts/rSIlGftERlU) | Examinar o percurso até a dificuldade, além do ponto em que aparece. |
| R03 | [Definir o problema sem limitar as soluções](https://www.youtube.com/shorts/CCKYLDX9F6w) | Definir o problema mantendo alternativas de solução abertas. |
| R04 | [Observar o uso além das entrevistas](https://www.youtube.com/shorts/lL_2EKSzLWU) | Combinar entrevista e observação, considerando o efeito da presença de quem pesquisa. |
| R05 | [Sondagem e perguntas sobre causas](https://www.youtube.com/shorts/aXyvoiuRgnQ) | Usar sondagem neutra e triangulação; não tratar perguntas como detector de mentira. |
| R06 | [Viés de amostragem nas decisões de produto](https://www.youtube.com/shorts/_pt2sd8Eqj4) | Conferir amostra, contexto, denominadores e evidência ausente. |
| R07 | [Como a pesquisa pode produzir resultados enviesados](https://www.youtube.com/shorts/AmXXD7ug84Y) | Reconhecer vieses de confirmação, desejabilidade social e observação. |
| R08 | [Elogios e intenção de compra não comprovam demanda](https://www.youtube.com/shorts/-CdoTvOFxdI) | Distinguir elogio e intenção declarada de demanda e comportamento reais. |
| R09 | [Interpretar o feedback negativo com contexto](https://www.youtube.com/shorts/3jLlE2cC5c4) | Interpretar reclamações com contexto; silêncio não comprova satisfação. |
| R10 | [A ausência de reclamações pode esconder abandono](https://www.youtube.com/shorts/nciDqaf8Nrc) | Investigar a possibilidade de abandono silencioso sem presumir que ocorreu. |
| R11 | [Pesquisar antes de confiar no diagnóstico](https://www.youtube.com/shorts/6JUUWS2G6v4) | Pesquisar o suficiente para sustentar o diagnóstico relevante. |
| R12 | [Investigar o problema com o Teste da Mãe](https://www.youtube.com/shorts/i_k3pSGp3Hc) | Explorar experiências e tarefas concretas antes de pedir aprovação da ideia. |
| R13 | [Cinco porquês para explorar dificuldades de uso](https://www.youtube.com/shorts/NRCDbRKS9aQ) | Investigar as razões de uma escolha sem transformar os porquês em ritual. |
| R14 | [Escolher para quem o produto deve funcionar](https://www.youtube.com/shorts/KX96Ydx1ACs) | Definir o público prioritário sem usar foco como desculpa para excluir acessibilidade. |
| R15 | [Mapear o fluxo e seu custo de interação](https://www.youtube.com/shorts/6YOs0fBGCgo) | Mapear esforço de leitura, decisão, interação e implementação no fluxo. |
| R16 | [Orientação clara ao longo do fluxo](https://www.youtube.com/shorts/_q95g3rpH3U) | Tornar orientação e próximos passos reconhecíveis. |
| R17 | [Reduzir o esforço para aprender a interface](https://www.youtube.com/shorts/3aNYluox13o) | Reduzir aprendizado desnecessário; preservar deliberação em escolhas importantes. |
| R18 | [Projetar para condições difíceis de atenção e conhecimento](https://www.youtube.com/shorts/nnypDMg70cc) | Considerar atenção e conhecimento limitados sem depreciar a pessoa. |
| R19 | [Clareza, leitura rápida e testes de usabilidade](https://www.youtube.com/shorts/cPiqlRT5cVE) | Usar clareza, leitura rápida e testes; concisão não significa omitir informação necessária. |
| R20 | [Explicitar o que a equipe já considera óbvio](https://www.youtube.com/shorts/neNF-UQ8Dww) | Explicitar o contexto que só a equipe já conhece. |
| R21 | [Evitar que a tela esconda a existência de mais conteúdo](https://www.youtube.com/shorts/V9X3w4Hahq4) | Evitar falsa impressão de fim e conteúdo escondido sem sinal de continuidade. |
| R22 | [Informação visível pode passar despercebida](https://www.youtube.com/shorts/JHgAeBrycoE) | Conferir se a informação importante é percebida, não apenas se está presente. |
| R23 | [Organizar a interface para uma atenção limitada](https://www.youtube.com/shorts/qt2G5oXD2jI) | Dar prioridade visual ao necessário e reduzir competição pela atenção. |
| R24 | [Escrever de acordo com a tarefa e a pressa](https://www.youtube.com/shorts/jGFOcz3N20I) | Adaptar extensão e organização do texto à tarefa e à situação. |
| R25 | [Onboarding com etapas pequenas e progresso visível](https://www.youtube.com/shorts/OMN1UhgtZ9o) | Dividir uma entrada complexa e mostrar progresso real; três etapas são um exemplo. |
| R26 | [Comunicar o andamento durante a espera](https://www.youtube.com/shorts/ZLayvsGQhhs) | Comunicar andamento e incerteza sem adotar um limiar de tempo não verificado. |
| R27 | [Separar espera, duração e percepção de progresso](https://www.youtube.com/shorts/LSwXtaNmG_o) | Diferenciar duração real, espera e enquadramento; não ocultar a duração relevante. |
| R28 | [Atrito intencional em ações com consequências](https://www.youtube.com/shorts/yaP0UaTrxqU) | Aplicar atrito proporcional à consequência; não instituir demora artificial. |
| R29 | [Testar tarefas que parecem fáceis para quem construiu](https://www.youtube.com/shorts/c2gQ3d621kc) | Testar com quem não construiu, inclusive tarefas que parecem óbvias. |
| R30 | [Usar o resultado do teste para mudar o produto](https://www.youtube.com/shorts/olIAE3zGKVA) | Converter achados em decisões e mudanças; testar sozinho não melhora o produto. |
| R31 | [Interpretar dados sem confundir demora com sucesso](https://www.youtube.com/shorts/F2FDIl2_7PU) | Investigar percurso e abandono; permanência longa também pode significar dificuldade. |
| R32 | [Métricas de uso e engajamento com contexto](https://www.youtube.com/shorts/WMNjhuHmvQk) | Definir período, população e objetivo antes de adotar métricas de engajamento. |
| R33 | [Relacionar a interface aos resultados do produto](https://www.youtube.com/shorts/-zbU2lVYSRg) | Ligar desenho, descoberta e efeito no produto; ferramenta visual não garante qualidade. |
| R34 | [Reutilizar um padrão exige conferir o contexto](https://www.youtube.com/shorts/lQOQnzkb3Uk) | Conferir contexto antes de copiar padrões de outro negócio. |
| R35 | [Comparar alternativas antes de encerrar o design](https://www.youtube.com/shorts/W1oE5dFbic8) | Comparar alternativas relevantes antes de tratar uma proposta como definitiva. |
| R36 | [Considerar hábitos existentes ao mudar a interface](https://www.youtube.com/shorts/3Bt_zAMtvZA) | Considerar hábitos e custo de adaptação ao propor mudança. |
| R37 | [Redesign do Snapchat como estudo de decisão de produto](https://www.youtube.com/shorts/ty8S8S0Si8s) | Tratar o caso narrado como ilustração, sem atribuir causalidade financeira comprovada. |
| R38 | [Comunicar a transição e preservar o controle do usuário](https://www.youtube.com/shorts/yjV9IXmDRpM) | Comunicar transição e preservar controle conforme a viabilidade de manter versões. |
| R39 | [Pequenas alterações também precisam de validação](https://www.youtube.com/shorts/7La5vZQYins) | Validar pelo efeito da mudança, mesmo quando o diff for pequeno. |
| R40 | [Reconhecer padrões que pressionam escolhas](https://www.youtube.com/shorts/6keOsTUE3Dg) | Reconhecer e evitar constrangimento, escolhas induzidas e ofertas inexistentes. |
| R41 | [Fazer a promessa do botão corresponder ao destino](https://www.youtube.com/shorts/cgkvbBHPAqk) | Alinhar promessa dominante, ação e destino, sem condições contraditórias escondidas. |
| R42 | [Construir confiança antes de pedir mais dados](https://www.youtube.com/shorts/CeJZv4DpTo8) | Apresentar valor e finalidade antes de pedir dados ou compromisso desnecessário. |
| R43 | [Comparar caminhos de apresentação dos planos](https://www.youtube.com/shorts/PSy8RR3qyg4) | Comparar estratégias sem deduzir vencedor das variantes inconsistentes na transcrição. |
| R44 | [Continuidade do serviço e acesso aos arquivos](https://www.youtube.com/shorts/s1Z0rgHQftE) | Comunicar propriedade, permissões, transferência, exclusão e continuidade do serviço. |
| R45 | [Projetar a experiência além das telas e dos agentes de IA](https://www.youtube.com/shorts/yGTcmTKSpHo) | Projetar a experiência humana e o controle da automação; não tratar previsões como fatos. |
| R46 | [Organizar uma ferramenta em torno da tarefa real](https://www.youtube.com/shorts/FClYkopqN74) | Organizar a solução segundo a tarefa e o ambiente reais; o patrocinador não define a stack. |
