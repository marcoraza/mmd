# Spec · RFID 03 · Retorno com avaliação de condição

Frente RFID do Event Pro, setor 3 de 4. Depende do setor 1 (fundação); herda
padrões do setor 2 (despacho).

## Problem Statement

O retorno de equipamento do evento só existe no app antigo e sofre do mesmo
defeito estrutural do despacho: o painel de scan esmaga a lista de conferência.
Além disso, o retorno é o momento em que a condição física do equipamento
precisa ser avaliada (estado e desgaste), e essa avaliação alimenta manutenção e
depreciação; hoje esse registro é frágil e o operador não tem caminho manual
quando uma tag volta danificada do evento, o que não é raro depois de montagem e
desmontagem.

## Solution

Fluxo de retorno no Event Pro, na lei clara: scan de volta com a lista sempre
visível, avaliação de condição por unidade (desgaste de 1 a 5, dano quando
houver), conferência manual com justificativa para tag que voltou ilegível, e
gravação transacional pelo endpoint de retorno do web. Ao final, cada unidade
volta pro estoque com status honesto: disponível ou manutenção.

## User Stories

1. Como operador, quero abrir o retorno de um evento em campo e ver tudo que saiu, para conferir a volta contra a ida.
2. Como operador, quero escanear as unidades que voltaram e ver a lista marcar em tempo real, para saber o que ainda está no caminhão.
3. Como operador, quero ver claramente o que saiu e não voltou, para cobrar o que falta antes de fechar.
4. Como operador, quero avaliar o desgaste (1 a 5) de uma unidade na volta, para o estoque saber a condição real de cada equipamento.
5. Como operador, quero marcar uma unidade como danificada com uma nota curta, para ela cair em manutenção em vez de voltar pra prateleira.
6. Como operador, quero um padrão rápido para a maioria (voltou bem, desgaste mantido), para não avaliar 35 itens um a um quando só 2 têm problema.
7. Como operador, quero conferir manualmente uma unidade cuja tag voltou ilegível, com justificativa, para a finalização nunca travar.
8. Como operador, quero ler QR como alternativa de identificação na volta, para tag danificada não parar a conferência.
9. Como operador, quero finalizar o retorno e ver as unidades voltarem a disponível (ou manutenção), para o estoque refletir a prateleira.
10. Como Marcelo, quero que o retorno grave movimentações por unidade com quem registrou, para auditoria de ponta a ponta.
11. Como Marcelo, quero que retorno parcial seja possível e explícito, para eventos que devolvem em levas não travarem o estoque.
12. Como operador, quero que erro de rede na finalização preserve o que já conferi, para não refazer a conferência da volta.

## Implementation Decisions

- A tela consome o endpoint transacional de retorno que já existe no web; contrato intocável, mesma regra do despacho.
- Avaliação de condição usa o sistema do produto: desgaste 1 a 5 e estado do ciclo de vida, com os mesmos rótulos do glossário. Depreciação é derivada no banco e na gestão web; o app de campo só registra desgaste e dano, nunca calcula valor.
- Default de volta: desgaste mantido e sem dano; o operador só toca no que fugiu do padrão.
- Mesmo desenho de dependências do despacho: ViewModel com leitor e cliente de API injetados; scan compacto fixo, lista dona do espaço; progresso real; override com motivo.
- Estado visual na lei clara, sem cor de acento: voltou, faltando, danificado e conferido manual são peso, forma e rótulo.

## Testing Decisions

- Mesma costura do setor 2: ViewModel com rede stubada e leitor simulado.
- Casos mínimos: scan marca a unidade certa; faltante aparece como faltante até o fim; avaliação de desgaste entra no payload; dano muda o destino da unidade para manutenção; override exige motivo; retorno parcial exige confirmação explícita; erro de rede preserva estado local.
- Prior art: suíte do setor 2; o formato de stub e os builders de fixture são os mesmos.

## Out of Scope

- Histórico da unidade (superfície nova mapeada no inventário, frente própria).
- Recalcular ou exibir depreciação no app de campo.
- Fila offline com sincronização.
- Mudança de contrato nos endpoints do web.

## Further Notes

Despacho e retorno são espelhos: mesma gramática de tela, direções opostas. Se a
implementação dos dois não compartilhar a maior parte dos componentes, algo foi
duplicado sem necessidade.
