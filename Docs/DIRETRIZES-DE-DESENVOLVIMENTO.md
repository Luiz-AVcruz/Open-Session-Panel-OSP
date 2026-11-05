# Como Filipe Deschamps pensa, constrói e mantém projetos

Síntese de engenharia e de condução de projetos, preparada para consulta humana e para orientar trabalho assistido por IA em diferentes repositórios.

## O que este documento procura preservar

O material estudado permite reconstruir uma maneira de tomar decisões: entender quem será atendido, escolher uma solução que as pessoas envolvidas consigam sustentar, construir em etapas, produzir evidência do comportamento e continuar responsável depois da entrega. Linguagem, arquitetura, testes e organização ganham sentido dentro dessa relação.

Essa reconstrução reúne as notas de aprendizado do curso Web, as duas aulas de IA da seção Box e consultas pontuais às aulas originais. As notas contêm elaboração para estudo; as transcrições têm origem em reconhecimento automático de fala. Este texto é uma síntese interpretativa, e não uma descrição exaustiva de todos os projetos do instrutor. As fontes e o alcance das leituras estão registrados ao final.

Esta síntese interpreta critérios para decidir conforme o contexto. A prioridade relativa de compreensão humana, capacidade de alteração, prazo, desempenho e custos deve ser definida em cada projeto. Uma escolha feita para um projeto específico não estabelece uma preferência global do responsável nem uma regra absoluta do instrutor.

Para aprofundar decisões de interface, fluxo e experiência, consultar também [Diretrizes de design e UX](DIRETRIZES-DE-DESIGN-E-UX.md). A aplicação considera o contexto e a incerteza; uma mudança técnica sem efeito na experiência não exige um processo de design.

## 1. Começar pelas pessoas e pelo efeito que o projeto deve produzir

Um projeto pode vencer a dificuldade técnica e continuar sem resolver uma necessidade. As notas sobre as duas muralhas — tecnologia e negócio — colocam essas perguntas lado a lado: conseguimos fazer funcionar e isso produz o efeito necessário para alguém?

Em “O que sobra para nós?”, a diferença entre a satisfação de quem construiu o primeiro formulário e a reação de quem o recebe ajuda a explicar essa distância. O esforço de aprender pertence à experiência de quem construiu. O benefício para outra pessoa precisa ser observado no uso. Entender conhecimentos, dificuldades e condições diferentes das próprias participa da descoberta do problema. [IA-S]

Por isso, antes de detalhar funcionalidades, vale escrever para quem se está construindo, que situação precisa melhorar e que resultado permitiria reconhecer essa melhora. A escrita ajuda a descobrir ligações frágeis entre a ideia e o problema. O planejamento amadurece quando pessoas reais conseguem examinar a proposta e mostrar o que foi entendido de forma incompleta.

Essa orientação também muda a avaliação do trabalho. Linhas de código, commits, tokens, tarefas encerradas e documentos produzidos podem ajudar a acompanhar atividade. Seu significado depende da relação com o resultado. Uma métrica usada como alvo isolado pode incentivar mais atividade sem melhorar a experiência, a confiabilidade ou a manutenção do produto.

Na interface, esse entendimento aparece na organização da informação, nos próximos passos reconhecíveis e na forma de comunicar falhas. A clareza para quem usa precisa ser examinada considerando os conhecimentos e as dificuldades dessas pessoas.

## 2. Escolher o modo de construir conforme o que já se conhece

Na aula sobre desenvolvimento orgânico, Deschamps distingue construir algo pela primeira vez de executar um caminho já conhecido. Quando o problema ainda está sendo descoberto, tentar especificar e montar o produto inteiro de uma vez exige acertar muitas hipóteses antes de receber retorno. O desenvolvimento orgânico reduz essa distância: uma parte nasce, alguém a examina, o entendimento muda e a próxima parte ganha uma direção melhor. [W08]

Isso inclui planejamento e limites. O retorno revela necessidades e também pode trazer sugestões incompatíveis ou complexidade desnecessária. A tarefa de quem conduz é decidir o que contribui para o objetivo e o que deve esperar. Toda sugestão aceita acrescenta algo que precisará ser compreendido, operado e mantido.

O modelo mais mecânico, chamado de “impressora 3D” na aula, também tem contexto de uso: um caminho conhecido pode permitir uma execução mais definida desde o início. A preferência por crescimento orgânico ao descobrir um produto não é uma proibição de planejar nem uma obrigação de redescobrir procedimentos já compreendidos.

O recorte de uma etapa deve permitir concluir e avaliar alguma coisa. Dividir o trabalho em arquivos ou tarefas pequenas ajuda apenas quando as partes preservam um resultado coerente. Requisitos essenciais continuam no escopo; as etapas organizam sua execução, sem apagá-los por conveniência.

## 3. Tratar a escolha técnica como uma decisão sobre continuidade

Na aula de arquitetura, a escolha de JavaScript para o TabNews é ligada ao domínio do instrutor, ao público que acompanhava seus conteúdos e à barreira de entrada para contribuições. O critério procurado era a capacidade real de pessoas diferentes modificarem o projeto. Essa justificativa não estabelece JavaScript como resposta universal. [W14-A]

A pergunta sobre tecnologia reúne fatores técnicos e humanos: a ferramenta atende ao comportamento necessário, quem sabe trabalhar com ela, como aprender o que falta, que documentação existe, quanto custa operá-la e o que aconteceria se a pessoa que concentra o conhecimento saísse? A história da infraestrutura PCI ilustra o risco de uma implementação sofisticada que a equipe não consegue manter com confiança. [W14-O]

Preferência pessoal e requisito funcional precisam ser reconhecidos separadamente. Uma ferramenta pode ser agradável para quem a propõe e difícil para as pessoas que darão continuidade ao trabalho. Outra pode ser conhecida e, ainda assim, trazer um contrato, uma licença ou uma condição de operação inadequada. Popularidade fornece sinais para investigar; a adequação depende do caso.

Aprendizado e operação também têm objetivos distintos. Implementar um mecanismo à mão pode expor fundamentos que uma biblioteca esconderia. Ao colocar esse mecanismo diante de usuários, passam a importar manutenção, experiência acumulada, riscos e capacidade de responder a falhas. O conhecimento do exercício deve melhorar a decisão de produção, mesmo quando a solução final for outra.

## 4. Distinguir arquitetura, modelagem e organização de pastas

Uma das distinções mais concretas da aula de arquitetura é que pastas não definem, por si, a arquitetura. Arquitetura envolve o escopo dos componentes e as interações entre eles: onde uma responsabilidade começa, onde termina e de que outras partes depende. Pastas e arquivos ajudam a encontrar e compreender essa estrutura. [W14-A]

Essa diferença evita duas ilusões. Uma árvore de diretórios bem apresentada pode esconder responsabilidades misturadas. Uma estrutura com poucos diretórios pode ter limites claros. A organização física deve tornar os limites reconhecíveis, sem substituí-los por aparência.

O exemplo de MVC no material sustenta a escolha de uma arquitetura simples acompanhada de boa modelagem. A própria aula menciona models que acumulavam responsabilidades, mostrando que o nome da arquitetura não garante uma implementação saudável. O exemplo é situado; não implica começar todo produto com MVC ou com um backend que ele ainda não precisa.

Há também uma revisão de decisão importante. A proposta inicial do TabNews separava mais radicalmente o núcleo e o framework. Ao investigar a execução dessa ideia com Next.js, o custo pareceu maior que o benefício. A proposta foi ajustada para aproveitar a integração do framework e preservar limites das regras de negócio. O princípio mantido foi a capacidade de mudar; a organização concreta foi negociada com o contexto. [W14-A]

Uma leitura de código útil deve conseguir descrever o fluxo: o que entra, o que é validado ou decidido, onde acontece o efeito e como o resultado volta. Isso revela misturas de responsabilidade com mais precisão que contar arquivos ou conferir se determinadas pastas existem.

## 5. Escrever código que permita continuar trabalhando

Legibilidade tem relação com ação. Um nome ajuda quando permite reconhecer a intenção e as condições de uma operação. Um limite ajuda quando uma alteração comum fica localizada e seus efeitos podem ser compreendidos. O código precisa permitir que outra pessoa descubra como continuar, corrigir uma falha ou substituir uma parte.

Modificabilidade inclui a potência real de uma pessoa ou equipe para fazer isso no curto, médio e longo prazo. Não depende apenas da linguagem ou da arquitetura. Entram nessa capacidade o conhecimento disponível, a clareza das regras, o ambiente de desenvolvimento, as verificações e o entendimento das consequências de uma mudança. [W14-O]

A procura pelo simples e bem feito exige trabalho de modelagem. A aula de overengineering descreve o custo de introduzir complexidade que se espalha e torna uma funcionalidade pequena difícil de acrescentar. Deixar faltar uma proteção essencial também prejudica a solução. A régua é a engenharia necessária ao contexto, com espaço para evoluir quando aparecer uma dificuldade concreta.

Repetição e abstração precisam desse mesmo julgamento. Em “Luto na programação”, o instrutor observa que partes inicialmente parecidas podem evoluir para responsabilidades distintas. Unificá-las cedo demais pode criar acoplamento. Por outro lado, repetir uma regra que precisa permanecer única pode permitir divergências. Para decidir, importa entender se existe a mesma regra ou apenas uma semelhança de escrita. [IA-L]

Uma abstração deve diminuir alguma dificuldade real de leitura ou alteração. Antes de criá-la, convém acompanhar uma mudança típica e observar o que ela tornaria mais claro. Se a proposta exige conceitos adicionais, desvios longos pelo projeto ou conhecimento concentrado para uma tarefa simples, seu benefício precisa ser reavaliado.

Não se extrai dessas aulas uma medida universal de tamanho de função, quantidade de camadas ou número aceitável de repetições. Esses sinais podem motivar investigação. A decisão depende da responsabilidade, do contrato e das alterações que o código precisa suportar.

## 6. Automatizar convenções para liberar atenção

Na aula de Prettier, a diferença entre ajudar a escrever e conferir o estado do projeto é demonstrada diretamente. EditorConfig orienta aspectos da escrita em editores compatíveis; ele não resolve, sozinho, todos os arquivos que já chegaram fora do formato. Uma extensão instalada em um editor também depende do ambiente de cada colaborador. [W10]

O formatador instalado no projeto e os comandos de conferência e correção tornam a operação reproduzível. A aula ainda trata o CI como o lugar em que essa conferência pode ser executada sem depender do cuidado individual. As funções são complementares: assistência durante a escrita, transformação dos arquivos e verificação compartilhada.

O benefício procurado é reduzir decisões repetitivas e ruído de revisão. Formatação consistente facilita enxergar mudanças de comportamento; ela não resolve modelagem, responsabilidade ou um contrato incorreto. Uma reformatação ampla deve ser reconhecível no histórico para não esconder a mudança funcional.

Ferramentas e configurações concretas continuam sujeitas ao contexto do projeto. A aula serve para compreender o mecanismo; suas versões, sinais de adoção e condições de uso pertencem ao momento apresentado. Ao adotar uma ferramenta hoje, é necessário conferir o contrato atual relevante. A escolha do formatador também não exige acrescentar dependências de execução ao produto.

## 7. Construir confiança em comportamentos e nas próprias verificações

Testes preservam conhecimento que ficaria dependente da memória de quem altera o sistema. Essa proteção ganha importância conforme as relações entre funcionalidades crescem. A finalidade é permitir mudanças com confiança sustentada pelo que foi observado.

A fronteira escolhida precisa corresponder ao comportamento importante. Duas partes corretas isoladamente podem falhar na interação. Se a necessidade passa por uma API e um banco, uma checagem restrita a uma função pode deixar de fora justamente a relação responsável pelo resultado. O custo de preparar e sustentar a verificação também participa da decisão; uma classificação de testes não escolhe sozinha pelo produto.

A confiança exige conferir o instrumento. Uma checagem que passa no caso correto precisa conseguir reprovar a condição errada que pretende detectar. Isso pode ser demonstrado com uma entrada inválida, uma falha controlada ou uma alteração temporária em ambiente de teste. O objetivo é conhecer o alcance da evidência, sem experimentar falhas onde suas consequências não estejam sob controle.

Ao corrigir um teste que falhou, é necessário distinguir regressão, expectativa antiga e mudança deliberada de contrato. Alterar a expectativa apenas para obter aprovação pode apagar o conhecimento que a verificação deveria proteger. Dados de exemplo e simulações também precisam preservar o comportamento da dependência que importa para o caso.

Uma execução aprovada tem limites de ambiente e cobertura. A entrega HTTP de uma página, sua aparência no navegador e a facilidade de uma pessoa encontrar informação são propriedades diferentes. O projeto precisa identificar qual delas foi observada e qual continua aberta.

## 8. Investigar e medir com uma pergunta concreta

Uma investigação começa separando o comportamento observado da explicação que ainda está sendo construída. Mensagem de erro, condição de reprodução, processo em execução e resposta de uma dependência fornecem evidências diferentes. A próxima verificação deve ser escolhida pela dúvida que pode esclarecer.

Esse cuidado também vale para melhorias. Antes de alterar algo para ficar mais rápido ou confiável, é preciso definir a situação de comparação e o efeito procurado. Uma solução mais elaborada pode não produzir esse efeito ou pode transferir o custo para outra parte, como manutenção ou estabilidade.

Relatos de uso complementam as medições técnicas. Quem executa um comando todos os dias ou tenta realizar uma tarefa na interface pode perceber atritos ausentes da leitura do código. Painéis e sinais de infraestrutura ajudam, mas precisam ser confrontados com requisições, logs e comportamento observado.

O resultado de uma investigação deve permitir a continuidade por outra pessoa: o que foi constatado, o que é hipótese, o que foi descartado e qual dúvida ainda muda a decisão. A documentação ganha valor quando reduz a necessidade de repetir o mesmo caminho.

## 9. Entregar uma parte coerente e acompanhar o que acontece depois

Uma etapa pequena deve alcançar um resultado que alguém consiga avaliar. Trabalhar em partes menores reduz o tempo entre hipótese e retorno e facilita perceber mudanças de entendimento. Em colaboração, integrar com frequência também expõe divergências antes que virem um conjunto difícil de conciliar.

Há uma diferença material entre código escrito, verificação local, versão publicada e efeito observado no uso. O encerramento de uma tarefa deve corresponder ao critério definido para ela. Um teste não executado, uma publicação ainda não confirmada ou um comportamento que depende de ambiente externo continua precisando de evidência própria.

O critério de suficiente evita um ciclo interminável de refinamento interno. Ele considera quem vai receber a entrega e quais condições essenciais precisam estar atendidas. Depois disso, o uso pode trazer informações que mais organização interna não produziria. Se uma condição essencial ainda falta, o desejo de encerrar a etapa não altera sua importância.

Conhecer o caminho até a operação ajuda a escrever mudanças que sobrevivam fora da máquina de desenvolvimento. Inclui saber como a versão chega ao ambiente real, que dependências podem falhar, onde observar o problema e quais formas de recuperação existem. Isso deve respeitar os acessos e as responsabilidades de cada ambiente.

## 10. Manter o projeto em condições de evoluir

Manutenção frequente e controlada reduz o acúmulo de decisões difíceis de relacionar. Atualizar dependências, reformar uma parte do código e mudar configuração no mesmo conjunto pode tornar a causa de uma falha menos evidente. Separar intenções facilita revisão, diagnóstico e recuperação.

Uma atualização precisa considerar compatibilidade e uso real. Alertas automáticos exigem interpretação sobre o componente afetado e seu alcance. Licenças e condições de distribuição também integram a decisão de adotar ou manter uma dependência. Uma escolha conhecida no curso ou em outro projeto não transfere automaticamente suas condições para o caso atual.

O histórico Git participa dessa manutenção. Um commit deve comunicar uma mudança coerente e manter juntas as partes que precisam viajar ou ser desfeitas juntas. Mensagem e documentação precisam ajudar alguém que não participou da conversa a entender o efeito e o motivo. Um recorte em commits pequenos não garante, por si, uma entrega pequena em produção.

Recuperação exige considerar o estado que existe depois da mudança. Novos dados e dependências podem ter surgido durante o uso; voltar o código não reconstrói automaticamente a situação anterior. O material sobre migrations apresenta preferência por correções adiante em determinado contexto, e não uma regra de que todo retorno é inadequado. A decisão deve comparar consequências e caminhos efetivamente conhecidos.

Um ambiente compreensível e recuperável favorece a experimentação. Operações importantes devem ter passos explícitos, destino identificado e resultado conferido. A proteção necessária aumenta com o impacto: separação de acessos e barreiras do próprio fluxo podem ser mais confiáveis que uma advertência que depende de ninguém se distrair.

## 11. Aprender, explicar e revisar sem concentrar o conhecimento

Saber executar e saber explicar são capacidades relacionadas, mas diferentes. A explicação deve partir de onde a dúvida está e aprofundar o mecanismo necessário. Um exemplo menor pode tornar uma relação visível antes de levá-la para o sistema completo. Essa atenção permite ao responsável participar das decisões e aos colaboradores assumir partes do trabalho.

O conhecimento de um projeto costuma estar distribuído. Registrar problema, intenção, dependências e critério de conclusão torna uma anotação utilizável por quem não esteve na conversa. A primeira captura pode ser incompleta; antes de virar instrução de execução, ambiguidades que mudem o resultado precisam ser esclarecidas.

Revisão exige identificar a preocupação concreta da outra pessoa e confrontar a proposta com evidência. Preferências, prestígio de uma tecnologia e defesa pessoal não resolvem a dúvida sobre o comportamento ou a manutenção. Quem usa e quem mantém o sistema oferece perspectivas que o autor sozinho não possui.

As notas de aprendizado pessoal entram nessa continuidade sem se transformarem em regras artificiais de código. Reconhecer limites ajuda a assumir compromissos viáveis e pedir apoio. Um erro pode produzir uma pergunta investigável e uma mudança de procedimento. Ritmo de aprendizado, espaço para experiências recuperáveis e interpretação de feedback influenciam a capacidade de continuar trabalhando.

## 12. Usar IA com critérios para julgar o que ela produz

“Luto na programação” tensiona o cuidado artesanal com o código diante da velocidade de produção e reescrita por IA. Os exemplos apresentados associam essa velocidade a outras capacidades: testes de comportamento já existentes, revisão de uma correção, comparação entre implementações e uma cena de estresse. A possibilidade de gerar mais código não é, sozinha, evidência de que a solução atende ao que se espera. [IA-L]

O laboratório narrado na aula permite comparar tentativas e devolver resultados ao processo de geração. O ensinamento transferível é definir critérios e manter uma forma de confrontar o resultado com eles. Reproduzir a escala narrada, usar muitos agentes ou reescrever tudo são escolhas que ainda precisam de necessidade, custo e condições próprias.

“O que sobra para nós?” liga intimidade com programação à capacidade de formular pedidos precisos, reduzir a desorganização do sistema e evitar tentativas que não chegam ao problema. O valor humano também aparece em compreender necessidades que a outra pessoa ainda não conseguiu formular. A responsabilidade por quem recebe o produto permanece com quem decide entregar. [IA-S]

Há um limite de atribuição importante: as aulas contêm relatos e previsões, inclusive números sobre migração e desempenho, cuja comprovação independente não foi feita para esta síntese. Esses casos ajudam a compreender o argumento do instrutor; não fornecem uma garantia sobre a capacidade de qualquer modelo, ferramenta ou projeto atual.

Um resultado produzido por IA deve poder ser relacionado ao problema, à mudança executada e à evidência obtida. Onde compreensão humana e manutenção direta são requisitos, a organização do código faz parte da aceitação. Onde uma alternativa menos confortável de ler traz um benefício necessário, esse compromisso precisa de critério, proteção e custo conhecidos. A decisão é contextual, e não uma licença geral para aceitar qualquer implementação.

## 13. Resolver tensões em vez de converter exemplos em dogmas

Os ensinamentos ficam mais úteis quando preservam os motivos das escolhas. Abaixo estão tensões recorrentes e a pergunta que impede uma aplicação mecânica.

| Tensão | Pergunta que orienta a decisão |
| --- | --- |
| Simplicidade e engenharia suficiente | O que a solução precisa proteger agora, e que complexidade foi acrescentada sem uma necessidade concreta? |
| Crescimento orgânico e execução planejada | Ainda estamos descobrindo o problema ou executando um caminho já conhecido? |
| Repetição e abstração | Existe a mesma regra que precisa evoluir junta, ou apenas trechos parecidos com razões diferentes para mudar? |
| Independência e integração com framework | Que limite facilita uma mudança provável, e quanto trabalho custa manter esse limite? |
| Testar, refinar e entregar | Que comportamento essencial falta demonstrar, e que melhoria pode ser orientada pelo próximo retorno de uso? |
| Legibilidade, prazo e reescrita | Quem precisa compreender e manter o resultado, que urgência existe e quais critérios sustentam o compromisso? |

Essas perguntas preservam uma diferença entre princípio e receita. MVC, Next.js, JavaScript, Prettier, integração contínua ou modelos de IA aparecem em contextos. O que se transfere para outro projeto é o raciocínio que permite avaliar se a escolha serve ali.

## 14. Critérios de adoção para trabalho assistido por IA

Adotar esta síntese exige conhecer as prioridades do projeto. Compreensão imediata, facilidade de alteração, prazo, desempenho e custos de operação e manutenção participam da decisão, sem uma ordem universal entre eles. Mais esforço inicial precisa de um benefício relevante para o caso; o responsável também pode preferir compreender a implementação depois da entrega, preservadas as condições necessárias de correção e verificação de quem a produz.

O investimento em organização segue esse mesmo critério. Mais documentação, pesquisa, abstrações ou testes não demonstram, por quantidade, que o trabalho ficou melhor. Cada esforço adicional deve esclarecer uma decisão, preservar um comportamento, facilitar uma alteração ou reduzir uma consequência relevante. Quando houver evidência suficiente para executar a próxima ação segura, a investigação deve dar lugar à execução.

Um ciclo de trabalho ajustável a essas prioridades é:

1. Entender o problema, os usuários, as restrições e o resultado esperado.
2. Inspecionar o caminho existente e os contratos que podem mudar a solução.
3. Explicar as decisões relevantes, resolver ambiguidades materiais e delimitar a etapa completa.
4. Implementar com responsabilidades reconhecíveis e complexidade proporcional.
5. Verificar o comportamento na fronteira adequada e registrar o alcance da evidência.
6. Revisar o efeito, atualizar a documentação necessária e registrar uma mudança coerente no Git quando o fluxo do projeto incluir commits.
7. Observar a entrega no ambiente que realmente importa e usar o retorno para o próximo ciclo.

O detalhamento desse ciclo e o momento das explicações dependem do projeto. Ele não exige uma aprovação humana para cada operação rotineira. O responsável deve participar das decisões que alteram objetivo, custo, risco ou forma de manter o projeto. As escolhas já autorizadas e as ações reversíveis necessárias continuam sendo executadas dentro do escopo.

## 15. Como reutilizar este documento em outro projeto

O corpo desta síntese é independente de linguagem, framework, domínio comercial e provedor. Pode ser levado para outro repositório como referência, preservando seus limites e definindo a política de adoção conforme o destino. As prioridades de outro projeto não são importadas automaticamente. Os caminhos locais das fontes são opcionais para consulta; não são necessários para entender as diretrizes.

No novo projeto, o `AGENTS.md` deve apontar para a localização escolhida e acrescentar somente o contexto que muda sua aplicação: objetivo, tecnologias existentes, contratos importantes, dados a proteger, comandos de verificação, critérios de entrega e restrições de publicação. Não é necessário reproduzir o documento inteiro nas instruções.

O bloco abaixo é uma adaptação operacional desta síntese para agentes. Ele não é uma citação do instrutor. Deve ser combinado com as instruções e autorizações específicas do repositório.

```text
Avalie compreensão, capacidade de alteração, prazo, desempenho e custos
conforme os requisitos e as prioridades explícitas do projeto. Ajuste o
momento das explicações à necessidade do responsável. Use as diretrizes
como critérios de decisão e demonstre sua aplicação no código e nos resultados.

Antes de alterar comportamento, entenda o problema, o resultado esperado,
o caminho existente e os contratos relevantes. Explique escolhas que mudem
custo, risco ou manutenção; resolva ambiguidades que exigem decisão humana.

Organize por responsabilidades e interações claras. Distingua arquitetura
de pastas. Justifique abstrações, dependências e desvios de convenção por
necessidades presentes. Preserve todos os componentes pedidos no escopo.

Faça mudanças completas e examináveis. Use convenções compartilhadas e
ferramentas de estilo adequadas, sem confundir formatação com correção.

Escolha verificações pelo comportamento e pela consequência da falha.
Exercite a fronteira relevante, conheça o que a checagem consegue detectar
e distinga validação local, integração, publicação e uso observado.

Produção por IA não substitui julgamento. Relacione cada mudança ao problema,
ao efeito e à evidência. Preserve dados, recuperação e compreensão humana
conforme os requisitos. Reescritas precisam de objetivo e limites definidos.

Registre decisões e alterações com contexto suficiente para a continuidade.
Conclua a etapa quando seus critérios forem atendidos. Acrescente pesquisa,
estrutura ou automação somente quando contribuírem para uma dúvida ou
necessidade concreta do trabalho atual.
```

## Fontes e alcance da síntese

Foram considerados o índice e as 49 notas temáticas de aprendizado do curso Web, as transcrições integrais de “Luto na programação” e “O que sobra para nós?” e os dois guias dessas aulas. No primeiro levantamento das notas, o agente principal leu 29 notas e o índice; o Luna leu integralmente outras 20 e forneceu sua avaliação. A redação e integração desta síntese são do agente principal.

Para esclarecer detalhes que mudam a orientação sobre código e desenvolvimento, foram lidas também quatro aulas Web completas: desenvolvimento orgânico, configuração do Prettier, overengineering e proposta de arquitetura e pastas. O inventário das notas aparece no apêndice; não foi feita uma leitura integral de todas as transcrições do curso Web.

As referências abaixo levam aos arquivos consultados neste computador. Atribuições específicas ao instrutor devem ser confrontadas com a aula correspondente quando houver dúvida de contexto ou fidelidade da transcrição. Os guias das aulas IA ajudam a explicitar ressalvas, mas continuam sendo material derivado.

- **W08:** [Programação “Orgânica” versus “Impressora 3D” — transcrição integral][W08].
- **W10:** [Configurar o Prettier — transcrição integral][W10].
- **W14-O:** [Uma história macabra sobre “Overengineering” — transcrição integral][W14-O].
- **W14-A:** [Proposta de Arquitetura e Pastas — transcrição integral][W14-A].
- **IA-L:** [Luto na programação — transcrição integral][IA-L].
- **IA-S:** [O que sobra para nós? — transcrição integral][IA-S].
- **G-L:** [Luto na programação — guia e aprendizados][G-L].
- **G-S:** [O que sobra para nós? — guia e aprendizados][G-S].

Base local das 49 notas e do índice:

```text
/home/luiz-avcruz/Misc/Obsidian Vaults/Luiz-AVcruz/Programação/Estudos/Cursos/curso.dev/Aprendizado subjetivo/
```

Cada nota tem sua própria seção de fontes, permitindo voltar à aula que originou um critério. Consultar a aula inteira é apropriado quando o contexto puder mudar uma orientação; não é necessário reler todo o curso para executar uma alteração já compreendida.

[W08]: </home/luiz-avcruz/Misc/Obsidian Vaults/Luiz-AVcruz/Programação/Estudos/Cursos/curso.dev/Transcrição/Dia 8/Programação "Orgânica" versus "Impressora 3D"/transcrição literal.md>
[W10]: </home/luiz-avcruz/Misc/Obsidian Vaults/Luiz-AVcruz/Programação/Estudos/Cursos/curso.dev/Transcrição/Dia 10/Configurar o Prettier/transcrição literal.md>
[W14-O]: </home/luiz-avcruz/Misc/Obsidian Vaults/Luiz-AVcruz/Programação/Estudos/Cursos/curso.dev/Transcrição/Dia 14/Uma história macabra sobre "Overengineering"/transcrição literal.md>
[W14-A]: </home/luiz-avcruz/Misc/Obsidian Vaults/Luiz-AVcruz/Programação/Estudos/Cursos/curso.dev/Transcrição/Dia 14/Proposta de Arquitetura e Pastas/transcrição literal.md>
[IA-L]: </home/luiz-avcruz/Misc/Obsidian Vaults/Luiz-AVcruz/Programação/Estudos/Cursos/curso.dev - IA/Transcrição/Box/Luto na programação/transcrição literal.md>
[IA-S]: </home/luiz-avcruz/Misc/Obsidian Vaults/Luiz-AVcruz/Programação/Estudos/Cursos/curso.dev - IA/Transcrição/Box/O que sobra para nós?/transcrição literal.md>
[G-L]: </home/luiz-avcruz/Misc/Obsidian Vaults/Luiz-AVcruz/Programação/Estudos/Cursos/curso.dev - IA/Transcrição/Box/Luto na programação/Luto na programação.md>
[G-S]: </home/luiz-avcruz/Misc/Obsidian Vaults/Luiz-AVcruz/Programação/Estudos/Cursos/curso.dev - IA/Transcrição/Box/O que sobra para nós?/O que sobra para nós?.md>

## Apêndice. Mapa das notas consultadas

Cada título abaixo corresponde a um arquivo no diretório das notas. A coluna de contribuição registra a interpretação incorporada a esta síntese; as seções indicam onde ela pode ser encontrada. Uma nota pode sustentar mais de uma orientação, e uma orientação pode reunir várias notas e aulas. Os títulos não constituem 49 regras novas nem requisitos para acrescentar funcionalidades.

A identificação de leitura preserva o levantamento inicial: o agente principal leu 29 notas e o índice; o Luna leu as outras 20. O índice organiza as notas e não é contado como uma nota temática. As fontes de cada nota permitem recuperar a aula original.

| Nota | Leitura inicial | Contribuição à síntese | Seção |
| --- | --- | --- | --- |
| Aprender a acompanhar a entrega até o uso em produção | Principal | Acompanhar a mudança até o ambiente real e o uso. | 9 |
| Aprender a ensinar e ajustar a profundidade da explicação | Principal | Ajustar a explicação ao conhecimento e à dúvida de quem aprende. | 11 |
| Assumir responsabilidade sem ultrapassar a própria capacidade | Luna | Dimensionar compromissos, reconhecer limites e buscar apoio. | 11 |
| Avaliar as consequências antes de desfazer uma mudança | Principal | Considerar dados, dependências e consequências da recuperação. | 10 |
| Buscar simplicidade sem cair em overengineering ou underengineering | Principal | Relacionar simplicidade, proteção necessária e custo de mudança. | 5 |
| Compreender fundamentos e história para avaliar novidades | Luna | Avaliar ferramentas compreendendo o mecanismo e o contexto. | 3 |
| Conhecer uma convenção antes de aceitar um desvio deliberado | Principal | Compreender a convenção antes de justificar uma exceção. | 6 |
| Considerar obrigações e confiança ao adotar dependências | Principal | Examinar licenças, condições de uso e continuidade. | 3, 10 |
| Construir confiança experimentando em condições seguras | Luna | Criar condições recuperáveis para aprender com experiências. | 10, 11 |
| Criar proteções que não dependam apenas da disciplina individual | Principal | Preferir barreiras proporcionais a depender apenas de atenção. | 10 |
| Definir o suficiente para entregar e aprender com o uso | Principal | Definir condições essenciais e aprender depois com o uso. | 9 |
| Demonstrar capacidade de aprender e reconhecer o que ainda falta | Luna | Explicitar conhecimento, evidência e limites em vez de aparentar domínio. | 11 |
| Desenvolver de forma orgânica e buscar retorno cedo | Principal | Reduzir a distância entre a primeira hipótese e o retorno. | 2 |
| Dimensionar a organização pelo benefício que ela produz | Principal | Justificar estrutura e documentação pelo que ajudam a compreender e mudar. | 4, 14 |
| Dimensionar o tratamento de falhas pelo impacto e pelo valor entregue | Principal | Dimensionar proteção e verificação pela consequência da falha. | 7, 10 |
| Enfrentar o desconhecido sem confundir a capacidade atual com um limite definitivo | Luna | Converter dificuldade atual em uma pergunta e um caminho de aprendizado. | 11 |
| Entender as duas muralhas de tecnologia e negócio | Luna | Relacionar viabilidade técnica e utilidade para alguém. | 1 |
| Escolher testes pelo risco e pelo comportamento que importa | Principal | Escolher a fronteira de verificação pelo comportamento importante. | 7 |
| Escrever a ideia para descobrir qual problema ela resolve | Luna | Usar a escrita para esclarecer problema, público e intenção. | 1 |
| Extrair conhecimento coletivo e registrar contexto suficiente | Principal | Registrar contexto suficiente para outra pessoa continuar. | 11 |
| Fazer manutenção contínua com mudanças controladas | Principal | Reduzir acúmulo com manutenção frequente e intenções separadas. | 10 |
| Integrar o trabalho com frequência para reduzir a distância entre pessoas | Luna | Expor divergências cedo por meio de integração frequente. | 9 |
| Investigar problemas sem inventar monstros no desconhecido | Principal | Separar observação e hipótese, escolhendo a próxima verificação. | 8 |
| Julgar metodologias pelo trabalho e pelo valor que ajudam a produzir | Luna | Avaliar processos pelo efeito no trabalho e no produto. | 2, 14 |
| Ler código pelas funções e responsabilidades que ele cumpre | Principal | Seguir o fluxo, os contratos e as responsabilidades do código. | 4, 5 |
| Limitar acessos e exposição de dados ao que é necessário | Principal | Restringir acessos e exposição ao necessário para o trabalho. | 10 |
| Manter um ritmo sustentável de aprendizado | Luna | Preservar continuidade e tempo para assimilar o aprendizado. | 11 |
| Medir resultados antes de declarar uma melhoria | Principal | Comparar o efeito pretendido com evidência relevante. | 8 |
| Orientar sem eliminar toda oportunidade de experimentar | Luna | Explicar sem retirar toda oportunidade de experimentar. | 11 |
| Padronizar para reduzir ruído e preservar atenção | Principal | Compartilhar e automatizar convenções para reduzir ruído. | 6 |
| Participar de uma comunidade com abertura e reciprocidade | Luna | Favorecer contribuição e circulação de conhecimento. | 3, 11 |
| Preparar um ambiente que permita experimentar e se recuperar | Principal | Tornar execução, experimentação e recuperação compreensíveis. | 10 |
| Preparar-se para falhas e verificar os sinais de saúde | Principal | Confrontar sinais de saúde com comportamento e caminhos de recuperação. | 8, 9, 10 |
| Projetar interfaces para que as pessoas consigam avançar | Principal | Organizar a experiência para que as pessoas consigam avançar. | 1 |
| Quebrar projetos grandes e abandonar o tudo ou nada | Luna | Dividir a execução em partes completas e avaliáveis. | 2, 9 |
| Reconhecer valor sem depender apenas do julgamento alheio | Luna | Examinar feedback sem transformar um julgamento isolado em medida total de capacidade. | 11 |
| Respeitar o tempo e ouvir a experiência de quem usa o produto | Luna | Observar esforço, dificuldades e retorno de quem usa. | 1, 8 |
| Revisar planos conforme o contato com a realidade | Luna | Revisar o plano quando a realidade muda o entendimento. | 2 |
| Separar função de preferência pessoal nas discussões técnicas | Principal | Discutir adequação funcional sem confundir preferência com requisito. | 3, 11 |
| Separar o exercício de aprender da escolha para operar um produto | Principal | Reconhecer a diferença entre explorar fundamentos e operar um produto. | 3 |
| Tomar decisões pelo contexto e sair da paralisia por análise | Luna | Usar o contexto para decidir e encerrar investigação suficiente. | 3, 14 |
| Tornar o progresso visível sem confundir marcação com entrega | Luna | Distinguir atividade registrada de entrega e efeito demonstrados. | 1, 9 |
| Trabalhar com revisão e feedback sem proteger o próprio ego | Luna | Examinar preocupações concretas e manter propostas revisáveis. | 11 |
| Transformar experiências difíceis em aprendizado | Luna | Extrair de erros e dificuldades perguntas e ajustes de procedimento. | 11 |
| Transformar procedimentos em processos reproduzíveis e rastreáveis | Principal | Explicitar passos, destinos e conferência do resultado. | 10 |
| Tratar a modificabilidade como um objetivo do software | Principal | Avaliar escolhas pela capacidade real de continuar alterando o sistema. | 3, 5 |
| Usar o histórico de mudanças como comunicação para outras pessoas | Principal | Comunicar intenção e agrupar mudanças coerentes no Git. | 10 |
| Usar testes para conseguir mudar o sistema com confiança | Principal | Preservar conhecimento de comportamentos para permitir alterações. | 7 |
| Verificar se os testes e as medições detectam falhas | Principal | Conferir se o instrumento reprova a falha que pretende detectar. | 7 |
