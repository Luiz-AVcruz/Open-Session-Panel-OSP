# Instruções de desenvolvimento

## Contexto e alcance

- Responder no idioma da conversa. Explicar decisões relevantes com clareza e na profundidade necessária.
- Usar `Docs/PROJETO.md` para compreender o objetivo, o escopo, as restrições e as prioridades. Consultar as seções pertinentes de `Docs/DIRETRIZES-DE-DESENVOLVIMENTO.md` quando uma decisão precisar de aprofundamento; uma edição rotineira não exige reler o guia inteiro.
- Aplicar estas orientações ao trabalho de software e à sua documentação, dimensionando o esforço pela incerteza e pelo risco. Os campos `[a definir]` representam lacunas; preencher com fatos e decisões confirmadas, sem inventar comandos, resultados ou requisitos.
- Decidir entre compreensão imediata, prazo, modificabilidade, desempenho e custos conforme o projeto. Ajustar o momento das explicações à preferência do responsável. A compreensão técnica de quem executa e a evidência necessária de correção continuam exigidas.

## Entender e decidir

- Ligar cada mudança relevante ao problema, às pessoas atendidas e a critérios observáveis de conclusão. Preservar todos os componentes pedidos; uma etapa intermediária encerra o pedido somente quando esse recorte foi solicitado ou acordado.
- Inspecionar o caminho existente e os contratos que podem mudar a solução. Separar fatos, hipóteses e lacunas. Prosseguir quando houver informação suficiente para a próxima ação segura; perguntar quando a informação ausente exigir uma decisão do responsável.
- Escolher tecnologias por adequação, manutenção, operação e conhecimento disponível. Comparar alternativas que possam mudar a decisão; justificar dependências e custos concretos. Uma tecnologia usada em um exemplo não se torna obrigatória.
- Tratar arquitetura como responsabilidades, limites e interações. Usar pastas e nomes para tornar essa organização reconhecível; definir a estrutura conforme as necessidades do projeto.

## Interface e experiência de uso

- Quando a tarefa envolver interface, navegação, conteúdo, estados ou fluxo de pessoas, consultar as seções pertinentes de `Docs/DIRETRIZES-DE-DESIGN-E-UX.md`. O guia sintetiza os conteúdos de Rian Dutra e referências complementares de composição e acessibilidade; aplicar pelo contexto, sem impor pesquisa formal ou uma estética a toda edição.
- Definir a tarefa, o público, a informação prioritária e a expectativa criada por cada ação. Usar conteúdo confirmado e distinguir imagens ilustrativas, dados de exemplo e oferta real.
- Escolher composição, texto e interação por finalidade, identidade e custo de uso. Comparar alternativas quando a incerteza puder mudar a decisão; preservar orientação, autonomia, acessibilidade e recuperação de erros.
- Distinguir aprovação estética e comercial, verificação técnica e uso observado. Um build não aprova aparência ou usabilidade. Testes e pesquisa precisam orientar uma decisão; não presumir sucesso por elogios, silêncio ou mais tempo de sessão.

## Implementar e revisar

- Construir etapas completas e examináveis. Buscar retorno quando o problema ainda estiver sendo descoberto; reutilizar procedimentos quando o caminho já for conhecido.
- Reutilizar convenções e partes adequadas do repositório. Avaliar abstrações e refatorações pelo benefício, pelo risco de divergência e pelo custo; semelhança textual isolada não decide a extração.
- Dimensionar proteções e complexidade pelas consequências da falha. Preservar os dados, as restrições ainda necessárias e as alterações de outras pessoas. Mudanças destrutivas precisam estar abrangidas pela autorização do responsável.
- Usar as ferramentas de formatação e verificação existentes. Acrescentar ferramentas e automação para uma necessidade concreta; distinguir consistência de escrita e correção do comportamento.
- Relacionar o resultado produzido por IA ao problema e à evidência. Reescritas e experimentos precisam de objetivo, limites e condições de avaliação. Quantidade de código, documentos ou tarefas encerradas não mede sozinha o valor entregue.

## Verificar e entregar

- Escolher verificações pelo comportamento e pelo risco, na fronteira responsável pelo resultado. Exercitar a integração quando ela for relevante; simulações precisam preservar o contrato importante da dependência.
- Quando a capacidade da checagem for incerta ou decisiva, conferir se ela detecta a falha pretendida em condições controladas. Distinguir regressão, expectativa obsoleta e mudança deliberada de contrato antes de alterar um teste.
- Para estado, concorrência e ambientes externos, verificar a ordem das operações, a responsabilidade e a conclusão real. Planejar recuperação considerando também os dados e dependências produzidos após uma mudança.
- Distinguir implementação, validação local, publicação e uso observado. Relatar o que foi comprovado e o que continua aberto; um comando aprovado não demonstra uma condição de outra camada.
- Uma mudança pequena e segura não exige plano formal, documento novo, teste automatizado ou delegação por padrão. Encerrar a investigação e a verificação quando os critérios necessários estiverem atendidos; ampliar somente diante de uma dúvida ou necessidade concreta.

## Continuidade

- Atualizar a documentação existente quando a decisão, o comportamento ou o procedimento necessário para continuar tiver mudado. Criar documentos adicionais quando o uso justificar.
- Concluir uma implementação não equivale à aprovação do responsável. Seguir a política de commits e publicação de `Docs/PROJETO.md`; por padrão, manter propostas como alterações locais até sua avaliação, salvo autorização explícita diferente. Quando houver autorização para commits, revisar o conjunto e agrupar mudanças coerentes. Confirmar remoto e publicação antes de declará-los concluídos.
- Manter o próximo ponto de retomada compreensível: resultado atual, limites relevantes, decisões pendentes e próxima ação necessária. Ajustar as convenções quando a realidade do projeto justificar.
