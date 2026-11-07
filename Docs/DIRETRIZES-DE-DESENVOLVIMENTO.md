# Diretrizes de desenvolvimento

Use estes critérios para compreender problemas, tomar decisões técnicas, construir, verificar e manter software. A aplicação depende do objetivo, das restrições, do risco e das pessoas que desenvolvem, usam e operam o sistema. Para mudanças na experiência de uso, consulte também as [diretrizes de design e UX](DIRETRIZES-DE-DESIGN-E-UX.md).

## 1. Começar pelas pessoas e pelo efeito esperado

Uma solução precisa ser tecnicamente viável e produzir um efeito útil para alguém. Antes de detalhar funcionalidades, identifique quem enfrenta a situação, o que precisa conseguir fazer, quais condições influenciam essa tarefa e que resultado permitiria avaliar a melhora.

Escrever o problema e o resultado esperado torna pressupostos examináveis. O retorno de quem usa ou conhece a situação pode revelar lacunas no entendimento. Não presuma que a satisfação de quem construiu ou aprendeu a ferramenta corresponde ao benefício de quem recebe o produto.

Linhas de código, commits, tarefas encerradas, documentos e volume de produção ajudam a descrever atividade. Seu significado depende da relação com o resultado. Uma métrica transformada em alvo isolado pode aumentar atividade sem melhorar utilidade, confiabilidade ou manutenção.

## 2. Escolher o modo de construir conforme o que já se conhece

Quando o problema ou a solução ainda são incertos, reduza o intervalo entre hipótese, implementação e retorno. Entregue uma parte que possa ser examinada e use o que foi observado para orientar a próxima etapa. Quando o caminho já é conhecido, planeje a execução de forma mais direta; não redescubra procedimentos sem necessidade.

O retorno pode revelar necessidades, mas também sugestões incompatíveis, custos ou complexidade desnecessária. Aceite mudanças quando contribuírem para o objetivo e considere o que acrescentam à operação e à manutenção.

Uma etapa deve terminar em um resultado coerente e avaliável. Dividir por arquivos ou tarefas pequenas só ajuda quando as partes continuam ligadas ao resultado necessário. Requisitos essenciais permanecem no escopo; as etapas organizam sua execução sem removê-los por conveniência.

## 3. Tratar escolhas técnicas como decisões sobre continuidade

Escolha linguagens, bibliotecas, serviços e plataformas pelo comportamento necessário e pela capacidade de sustentá-los. Considere conhecimento disponível, custo de aprendizado, documentação, compatibilidade, operação, licença, suporte e o efeito da saída de quem concentra conhecimento.

Preferência pessoal e requisito funcional são coisas diferentes. Popularidade pode indicar um ecossistema a investigar, mas não comprova adequação. Uma implementação sofisticada que a equipe não consegue operar com confiança pode criar mais risco que benefício.

Aprender fundamentos e operar um produto têm objetivos distintos. Implementar um mecanismo manualmente pode ajudar a compreender o que uma biblioteca oculta. Para colocar esse mecanismo em produção, compare manutenção, experiência disponível, segurança e capacidade de responder a falhas. O conhecimento do exercício deve informar a decisão, ainda que a solução final seja outra.

Pessoas, documentação e práticas de uma comunidade também fazem parte do ecossistema. Avalie que suporte existe, quais condições de uso se aplicam e se o projeto consegue manter a dependência quando a comunidade não puder fazê-lo por ele. Contribuição e suporte não devem ser presumidos como obrigação de terceiros.

## 4. Distinguir arquitetura, modelagem e organização de pastas

Arquitetura descreve responsabilidades, limites e interações: o que cada parte conhece, o que pode fazer e de que depende. Pastas e arquivos ajudam a localizar essa estrutura, mas não a definem. Uma árvore organizada pode esconder responsabilidades misturadas; poucos diretórios podem conter limites claros.

Modelos e padrões não garantem uma implementação saudável. Em MVC, por exemplo, um componente chamado `model` ainda pode acumular responsabilidades sem relação. Usar um framework integrado pode simplificar a solução; separar o núcleo do framework pode facilitar mudanças em certos contextos, mas acrescenta custo. Escolha os limites que protegem alterações prováveis sem criar camadas sem benefício demonstrável.

Uma leitura útil do código consegue acompanhar o fluxo: o que entra, onde é validado ou decidido, onde ocorre o efeito e como o resultado retorna. Essa descrição revela dependências e responsabilidades com mais precisão que contar arquivos ou conferir nomes de pastas.

## 5. Escrever código que permita continuar trabalhando

Legibilidade deve facilitar uma ação: entender a intenção, localizar uma regra, avaliar efeitos e fazer uma alteração. Bons nomes descrevem propósito e condições relevantes. Limites úteis mantêm uma mudança comum localizada e tornam seus efeitos compreensíveis.

Modificabilidade é a capacidade real de continuar alterando o sistema. Ela depende da clareza das regras, do conhecimento disponível, do ambiente, das verificações e da compreensão das consequências, além da linguagem ou arquitetura escolhida.

Busque a engenharia necessária ao contexto. Complexidade espalhada pode tornar uma alteração pequena cara; a falta de uma proteção essencial também pode tornar o sistema frágil. Acrescente estrutura quando uma dificuldade concreta exigir e mantenha espaço para evolução sem antecipar mecanismos hipotéticos.

Repetição e abstração precisam do mesmo julgamento. Trechos parecidos podem representar regras que evoluem separadamente; uma regra duplicada pode divergir quando deveria permanecer única. Antes de abstrair, acompanhe uma mudança provável e pergunte se a abstração melhora entendimento ou alteração o suficiente para compensar seus conceitos e acoplamentos.

Não há tamanho universal de função, número ideal de camadas ou quantidade fixa de repetições. Esses sinais podem iniciar uma investigação; a decisão depende da responsabilidade, do contrato e das mudanças que o código precisa suportar.

## 6. Automatizar convenções para liberar atenção

Convenções compartilhadas reduzem ruído e ajudam a concentrar a revisão no comportamento. EditorConfig pode orientar a escrita em editores compatíveis; um formatador pode corrigir arquivos existentes; comandos reproduzíveis e integração contínua podem conferir o padrão sem depender do ambiente de cada pessoa. Essas funções se complementam.

Conheça a convenção do projeto antes de propor um desvio deliberado. Justifique a exceção pelo contexto e mantenha-a compreensível para quem dará continuidade. Uma convenção não precisa ser preservada quando prejudica uma necessidade real, mas alterá-la sem considerar os demais colaboradores transfere custo para eles.

Formatação consistente não corrige modelagem, responsabilidade ou contrato incorretos. Uma reformatação ampla deve ser separável da mudança funcional quando isso tornar a revisão mais segura. Ferramentas de estilo só devem entrar na execução do produto quando houver uma necessidade concreta para isso.

## 7. Construir confiança em comportamentos e verificações

Testes preservam conhecimento sobre comportamentos e permitem mudar o sistema com mais confiança. Escolha a fronteira pela propriedade importante. Componentes corretos isoladamente ainda podem falhar na interação; quando o resultado depende de uma API e de um banco de dados, uma verificação unitária pode não cobrir o contrato entre eles.

Confira o próprio instrumento: uma verificação que passa no caso correto também deve reprovar a condição que pretende detectar. Use entradas inválidas, falhas controladas ou alterações temporárias em ambiente seguro. Não provoque falhas em sistemas reais quando as consequências não estiverem controladas.

Ao corrigir uma falha de teste, diferencie regressão, expectativa obsoleta e mudança deliberada de contrato. Alterar a expectativa só para obter aprovação pode apagar o comportamento que o teste deveria proteger. Simulações e dados de exemplo precisam preservar o comportamento da dependência relevante.

Uma execução aprovada tem limites de ambiente e cobertura. Responder a uma requisição, apresentar uma tela corretamente e permitir que alguém conclua uma tarefa são propriedades distintas. Registre qual delas foi observada e qual continua sem evidência.

## 8. Investigar e medir com uma pergunta concreta

Separe comportamento observado de explicações ainda hipotéticas. Mensagem de erro, condição de reprodução, processo em execução, resposta de uma dependência e relato de uso são evidências diferentes. Escolha a próxima verificação pela dúvida que pode esclarecer.

Para avaliar uma melhoria, defina a situação de comparação e o efeito pretendido. Uma solução mais complexa pode não produzir esse efeito ou pode transferir custo para manutenção, estabilidade ou operação. Compare condições equivalentes sempre que isso puder mudar a conclusão.

Relatos de uso complementam sinais técnicos. Quem repete uma tarefa ou opera o sistema pode notar atritos que não aparecem na leitura do código. Painéis, logs e métricas de infraestrutura ajudam a localizar problemas, mas precisam ser confrontados com requisições e comportamento observado.

Registre o que foi constatado, o que permanece hipótese, o que foi descartado e qual questão ainda pode mudar a decisão. Documentar a investigação é útil quando permite que outra pessoa continue sem repetir o mesmo percurso.

## 9. Entregar uma parte coerente e acompanhar o que acontece depois

Uma etapa deve produzir algo que possa ser avaliado conforme um critério definido. Partes menores reduzem o intervalo entre hipótese e retorno. Em trabalho compartilhado, integrar com frequência ajuda a encontrar divergências antes que fiquem difíceis de resolver.

Código escrito, verificação local, integração, publicação e efeito observado no uso são estados diferentes. O critério de conclusão precisa corresponder ao estado solicitado. Um teste não executado, uma publicação não confirmada ou um resultado que depende de ambiente externo ainda exige evidência própria.

Defina o suficiente para a entrega conforme quem a receberá e as condições essenciais. Depois que elas forem atendidas, o uso pode revelar mais que refinamento interno adicional. Se uma condição essencial ainda falta, a vontade de encerrar a etapa não altera sua importância.

Considere como a mudança chega ao ambiente real, que dependências podem falhar, onde observar problemas e como recuperar o serviço. Respeite os acessos e as responsabilidades de cada ambiente.

## 10. Manter o projeto em condições de evoluir

Manutenção frequente e controlada reduz decisões difíceis de relacionar. Alterar dependências, reformar código e mudar configuração no mesmo conjunto pode tornar a causa de uma falha menos clara. Agrupe mudanças por intenção e mantenha juntas as partes que precisam ser revisadas, instaladas ou recuperadas juntas.

Avalie alertas automáticos pelo componente afetado, sua exposição e seu uso real. Licenças e condições de distribuição integram a escolha de dependências. Uma decisão apropriada em outro projeto não transfere automaticamente seus requisitos para este.

Use o histórico Git para comunicar mudanças coerentes. A mensagem e a documentação devem ajudar quem não participou da conversa a entender intenção e efeito. Muitos commits pequenos não garantem, por si, uma entrega pequena ou segura em produção.

Planeje recuperação considerando dados e dependências que possam ter mudado depois da alteração. Reverter código não reconstrói automaticamente o estado anterior. Uma migração pode permitir reparo à frente ou retorno, conforme os contratos e os dados envolvidos; compare consequências e caminhos que foram realmente preparados.

Restrinja acessos e exposição de dados ao necessário. Procedimentos importantes devem indicar passos, destino e conferência do resultado. Quanto maior o impacto, mais a proteção deve depender de barreiras do fluxo e controles verificáveis, e menos de uma advertência ou da atenção individual.

## 11. Compartilhar conhecimento e revisar sem concentrá-lo

Explicações devem partir da dúvida existente e aprofundar o mecanismo necessário. Um exemplo pequeno pode esclarecer uma relação antes de aplicá-la ao sistema completo. Ensinar não exige retirar toda oportunidade de experimentar; exercícios devem ocorrer em condições proporcionais ao risco e com recuperação possível.

Registre problema, intenção, dependências e critério de conclusão para que alguém fora da conversa possa continuar. Capturas iniciais podem estar incompletas; esclareça ambiguidades que alterem o resultado antes de transformar uma anotação em instrução de execução.

Em uma revisão, identifique a preocupação concreta e avalie-a diante do comportamento, da evidência e da manutenção. Preferência, prestígio de uma tecnologia e defesa pessoal não respondem à questão técnica. Pessoas que usam e mantêm o sistema oferecem perspectivas distintas.

Use erros e feedback para formular perguntas verificáveis e ajustar procedimentos sem converter cada incidente em uma regra universal. Reconheça limites de conhecimento e capacidade, peça apoio quando necessário e mantenha um ritmo que permita aprender e continuar. A compreensão de quem executa deve atender às necessidades e prioridades explícitas do projeto.

## 12. Usar IA com critérios para julgar o resultado

A velocidade de geração não demonstra que uma solução atende ao problema. Relacione o que a IA produziu à mudança executada, ao comportamento esperado e à evidência obtida. Testes, revisão e comparação podem ajudar, desde que avaliem a propriedade relevante.

Defina objetivo, limites e condições de avaliação para geração, reescritas ou uso de agentes. Mais agentes, mais código ou uma reescrita completa não são benefícios por si. Onde compreensão humana e manutenção direta forem requisitos, inclua-os nos critérios de aceitação. Onde outra abordagem trouxer benefício necessário, conheça seus compromissos e formas de recuperação.

Desempenho, migração e produtividade variam com tarefa, dados, ferramenta, contexto e método de avaliação. Um relato ou uma previsão não estabelece uma garantia geral. Use evidência adequada à decisão atual e indique suas limitações.

## 13. Resolver tensões em vez de converter exemplos em regras

| Tensão | Pergunta que orienta a decisão |
| --- | --- |
| Simplicidade e engenharia suficiente | O que precisa ser protegido agora e que complexidade foi acrescentada sem necessidade concreta? |
| Construção iterativa e execução planejada | O problema ainda está sendo descoberto ou o caminho já é conhecido? |
| Repetição e abstração | Existe uma regra que deve evoluir junto ou apenas trechos parecidos com razões distintas para mudar? |
| Independência e integração com framework | Que limite facilita uma mudança provável e quanto custa mantê-lo? |
| Testar, refinar e entregar | Que comportamento essencial ainda falta demonstrar e que melhoria depende do próximo retorno? |
| Legibilidade, prazo e reescrita | Quem precisa compreender e manter o resultado, que urgência existe e qual evidência sustenta o compromisso? |

Tecnologias, padrões e ferramentas podem ser bons exemplos sem se tornarem receitas. Transfira o raciocínio que permite avaliar uma escolha, não a escolha isolada.

## 14. Aplicar os critérios ao trabalho assistido por IA

Conheça as prioridades do projeto. Compreensão, capacidade de alteração, prazo, desempenho e custos de operação e manutenção participam da decisão sem uma ordem universal. Um investimento maior precisa de benefício relevante. O responsável pode preferir compreender a implementação depois da entrega; isso não dispensa quem executa de entender o necessário para implementar e verificar a solução.

Documentação, pesquisa, abstrações e testes devem esclarecer decisões, preservar comportamentos, facilitar alterações ou reduzir consequências relevantes. Quantidade de artefatos não prova qualidade. Quando houver evidência suficiente para a próxima ação segura, execute-a e amplie a investigação somente diante de uma dúvida concreta.

Um ciclo de trabalho ajustável a essas prioridades é:

1. Entender o problema, as pessoas envolvidas, as restrições e o resultado esperado.
2. Inspecionar o caminho existente e os contratos que podem mudar a solução.
3. Resolver ambiguidades que exigem decisão e delimitar uma etapa completa.
4. Implementar com responsabilidades reconhecíveis e complexidade proporcional.
5. Verificar o comportamento na fronteira adequada e registrar o alcance da evidência.
6. Revisar o efeito e atualizar a documentação necessária; registrar uma mudança coerente no Git quando o fluxo do projeto incluir commits.
7. Observar a entrega no ambiente que importa e usar o retorno para o próximo ciclo.

O ciclo e o momento das explicações dependem do projeto. Ele não exige aprovação humana para cada operação rotineira. Envolva o responsável em decisões que alterem objetivo, custo, risco ou forma de manter o projeto. Execute ações reversíveis e autorizadas dentro do escopo.

## 15. Reutilizar estas diretrizes em outro projeto

Estas orientações podem acompanhar projetos de domínios e tecnologias diferentes. As prioridades do destino continuam próprias. No novo repositório, indique a localização escolhida em `AGENTS.md` e acrescente apenas o contexto que muda a aplicação: objetivo, tecnologias, contratos importantes, dados a proteger, comandos de verificação, critérios de entrega e restrições de publicação.

O bloco abaixo resume uma aplicação operacional dos critérios. Combine-o com as instruções e autorizações específicas do repositório.

```text
Avalie compreensão, capacidade de alteração, prazo, desempenho e custos
conforme os requisitos e as prioridades explícitas do projeto. Ajuste o
momento das explicações ao contexto do responsável. Use estas diretrizes
como critérios e demonstre sua aplicação no código e nos resultados.

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
