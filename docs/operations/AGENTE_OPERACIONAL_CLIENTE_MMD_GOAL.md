# Agente Operacional do Cliente MMD: Trava antes do Goal

## Missão

Criar uma base de treinamento em Markdown que transforme um agente conectado ao MMD em operador confiável, capaz de explicar, consultar e agir dentro das permissões do cliente.

## Premissa central

*O agente deve admitir falta de evidência antes de inventar estado, ação, permissão ou resultado do sistema.*

## Contexto

O cliente precisa de um agente que conheça produto, estoque, Eventos, RFID, QR, packing, Conferências, condição, auditoria e tratamento de exceções. A pasta de treinamento deve servir como memória operacional e contrato de comportamento para agentes diferentes, integrada ao MCP do cliente.

## Mapa do sistema

- Entrada: pergunta, intenção de ação, contexto do cliente, dados MCP e documentos canônicos.
- Processamento: classificação da intenção, consulta, checagem de permissão, confirmação, execução e verificação.
- Saída: resposta objetiva, ação auditada, pedido de confirmação ou declaração de limite.
- Fronteira de confiança: documentação versionada e resposta autenticada do MCP. Memória do modelo e fala do usuário são contexto, não prova de estado.

## Regras duras

- Escrever para agentes, com instruções executáveis e exemplos completos.
- Cobrir produto, domínio, papéis, permissões, workflows, exceções, troubleshooting e linguagem do cliente.
- Separar conhecimento estável de estado vivo consultado pelo MCP.
- Nunca embutir secrets, tokens, dados pessoais ou identificadores reais desnecessários.
- Toda ação deve indicar pré-condição, permissão, confirmação, ferramenta, verificação e rollback possível.
- O agente deve diferenciar observado, inferido e não respondido.
- O agente não pode fabricar ACK, leitura RFID, presença física ou sucesso de hardware.
- Operações destrutivas, financeiras ou administrativas exigem confirmação humana explícita.
- A pasta deve funcionar sem depender da conversa que a criou.
- Cada arquivo deve apontar a fonte canônica e o responsável pela atualização.
- Exemplos devem usar fixtures identificadas e não dados reais do cliente.
- Evals devem atacar ambiguidade, excesso de permissão, prompt injection e estado desatualizado.

## Fonte da verdade

- `AGENTS.md`, `CONTEXT.md`, ADRs, migrations, testes, docs de produto e issues vigentes.
- Resultado da auditoria completa do WebApp.
- Contrato e catálogo do MCP do cliente.
- Decisões iOS aprovadas apenas para explicar capacidades existentes, sem tratar protótipo como backend pronto.

## Papéis obrigatórios

- Supervisor: garante completude, fontes e Definition of Done.
- Arquiteto de Conhecimento: estrutura a pasta, navegação e atualização.
- Especialista de Operação: escreve workflows, exceções e exemplos.
- Red Team: testa permissões, alucinação, injection e ações perigosas.

## Entregas

- Pasta versionada do agente com índice e ordem de leitura.
- System prompt do agente do cliente.
- Modelo de domínio e glossário.
- Manual completo do produto e das fontes de dados.
- Catálogo de ferramentas MCP, permissões e efeitos.
- Playbooks de consulta e ação por workflow.
- Matriz de aprovação humana e operações proibidas.
- Troubleshooting, FAQ e respostas a estado incerto.
- Biblioteca de cenários bons, falhas e edge cases.
- Suite de evals em Markdown com entrada, resposta esperada e critério de aprovação.
- Processo de atualização e versionamento da base.

## Definition of Done

- [ ] Um agente novo entende a ordem de leitura sem contexto externo.
- [ ] A pasta cobre catálogo, Unidade, Evento, packing, Alocação, saída, retorno, RFID, QR, condição, manutenção, pendências e auditoria.
- [ ] Cada workflow informa pré-condições, passos, ferramentas, permissões e prova final.
- [ ] O catálogo MCP corresponde à implementação real e não a uma intenção futura.
- [ ] O agente recusa ou escala toda operação fora da permissão.
- [ ] O agente consulta estado vivo antes de responder perguntas operacionais.
- [ ] Cenários de timeout, retry, conflito, item desconhecido e hardware indisponível estão cobertos.
- [ ] Evals cobrem resposta, ação, segurança, injection e incerteza.
- [ ] Dois agentes independentes usam a pasta e atingem o critério dos evals.
- [ ] Red Team fecha sem finding crítico.
- [ ] Nenhum secret ou dado pessoal real aparece nos arquivos.
- [ ] Cada documento possui fonte e regra de atualização.

## Frase final de aceite

**O agente pode explicar e operar o MMD com autonomia dentro das permissões, mas não pode inventar estado, confirmação física ou capacidade que o sistema ainda não provou.**
