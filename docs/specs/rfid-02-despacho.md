# Spec · RFID 02 · Despacho (check-out) com scan

Frente RFID do Event Pro, setor 2 de 4. Depende do setor 1 (fundação).

## Problem Statement

O despacho de equipamento pro evento só existe no app antigo, e lá ele tem três
defeitos graves mapeados no inventário:

1. Durante o scan, o painel de validação esmaga a própria lista de conferência:
   sobra uma linha cortada de uma lista de 35 itens, e o operador confere sem
   ver o que falta.
2. O medidor de progresso é decoração: marca 0 de N e 0% em qualquer evento,
   sempre, porque o valor é fixo no código.
3. Não existe conferência manual: tag que não lê mais QR rasgado deixam a
   finalização eternamente bloqueada, mesmo com o motivo de override já
   suportado pelo backend.

## Solution

Tela de despacho no Event Pro, na lei clara: a packing list fica visível o tempo
inteiro durante o scan, o progresso é real (contado do que foi validado), itens
com tag ilegível podem ser conferidos manualmente com justificativa, e a
confirmação vai numa transação única pelo endpoint de despacho do web, que é o
backend do app de campo.

## User Stories

1. Como operador, quero abrir o despacho de um evento e ver a packing list completa com quantidades, para saber o que carrego antes de escanear.
2. Como operador, quero escanear itens com o RFD40 e ver cada um validado na lista em tempo real, para conferir enquanto carrego.
3. Como operador, quero que a lista continue visível e rolável durante o scan, para nunca conferir às cegas.
4. Como operador, quero ver progresso real (X de Y itens, por item e total), para saber o quanto falta de verdade.
5. Como operador, quero que um item fora da packing list seja apontado na hora, para não embarcar equipamento errado.
6. Como operador, quero que tag repetida não conte duas vezes, para o número não mentir.
7. Como operador, quero ler QR code como alternativa quando a tag não responde, para não travar com tag danificada.
8. Como operador, quero conferir manualmente um item com tag e QR ilegíveis informando o motivo, para a finalização nunca ficar impossível.
9. Como Marcelo, quero que toda conferência manual registre a justificativa, para auditar depois quem liberou o quê e por quê.
10. Como operador, quero finalizar o despacho e ver o evento virar "em campo", para fechar o carregamento com um gesto.
11. Como operador, quero ser avisado ao finalizar com itens faltando, e decidir se sigo parcial, para embarque incompleto ser escolha consciente.
12. Como operador, quero que erro de rede na finalização preserve o que já validei, para não escanear 35 itens de novo.
13. Como Marcelo, quero que o despacho grave movimentações por unidade no banco, para o histórico contar a verdade do galpão.
14. Como equipe, queremos que a validação aponte de qual evento é um serial escaneado por engano, para resolver troca de carga na hora.

## Implementation Decisions

- A tela consome o mesmo endpoint transacional de despacho que o app antigo usa no web. O endpoint não muda; o contrato dele é a fronteira (regra da pendência 9.0: o território de API do web é intocável).
- Conferência manual usa o motivo de override que o cliente de API já suporta; nenhuma escrita nova no backend.
- ViewModel próprio com leitor e cliente de API injetados; a view não fala com SDK nem com rede.
- Decisão central de layout: scan e lista não disputam a mesma altura. O estado do scan é um elemento compacto fixo; a lista é dona do espaço.
- Progresso derivado do estado real de validação, nunca valor fixo.
- Estado visual na lei clara: validado, pendente, fora de lista e conferido manualmente são codificados por peso, posição, forma e rótulo, sem cor de acento. Conferido manualmente carrega marca própria visível (é informação de auditoria, não vergonha).
- Entrada pelo fluxo natural: detalhe ou linha do evento na aba Eventos. Se o detalhe do evento ainda não existir quando este setor for implementado, a entrada é ação direta na linha, sem criar tela paralela.

## Testing Decisions

- Costura: ViewModel com rede stubada na camada de URL e leitor em modo simulado emitindo tags de teste. Testa comportamento externo, não detalhe de view.
- Casos mínimos: tag válida valida o item certo; tag repetida não incrementa; tag de outro evento aponta o conflito; tag desconhecida aponta desconhecida; override exige motivo e marca o item; finalização monta o payload certo (incluindo overrides); finalização parcial exige confirmação; erro de rede não zera o estado local.
- Prior art: a suíte do setor 1 (injeção na fachada) e o padrão de stub de rede que nascer aqui vira o padrão dos setores 3 e 4.

## Out of Scope

- Retorno (setor 3), etiquetar e identificar (setor 4).
- Fila offline com sincronização (superfície nova mapeada no inventário, frente própria).
- Recibo do despacho (superfície nova, frente própria).
- Qualquer mudança de contrato nos endpoints do web.

## Further Notes

Os três defeitos do Problem Statement são teto de qualidade, não detalhe: se a
tela nova reproduzir qualquer um deles, o port falhou. Vale usar o inventário
como prova de contraste (antes e depois).
