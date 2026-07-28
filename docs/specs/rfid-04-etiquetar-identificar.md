# Spec · RFID 04 · Etiquetar e Identificar

Frente RFID do Event Pro, setor 4 de 4. Depende do setor 1 (fundação).

## Problem Statement

O estoque real tem mais de mil unidades sem tag RFID vinculada: invisíveis pro
scan, elas transformam qualquer despacho em conferência meio manual. O fluxo de
vincular tag existe só no app antigo, e com um defeito de fundo: a busca de item
baixa o catálogo inteiro pro aparelho pra filtrar localmente.

Na outra ponta, identificar um equipamento avulso ("que caixa é essa?") também
só existe no app antigo. No Event Pro, a aba Ler tag da barra nova está em
estado vazio esperando exatamente essa função.

## Solution

Duas capacidades irmãs sobre o mesmo leitor:

Etiquetar: buscar a unidade (por código interno, nome ou serial), ler uma tag
virgem e vincular, com proteção contra tag já usada.

Identificar: a aba Ler tag vira leitura avulsa. Aproximou o leitor, o app diz o
que é a unidade, a condição, o status e onde ela está designada; tag
desconhecida oferece o caminho direto pra etiquetar.

## User Stories

1. Como operador, quero buscar uma unidade por código interno, nome ou serial de fábrica, para achar rápido o que vou etiquetar.
2. Como operador, quero ler uma tag e vinculá-la à unidade escolhida em dois gestos, para etiquetar mil itens sem morrer de tédio.
3. Como operador, quero ser impedido de vincular uma tag que já pertence a outra unidade, e ver qual é, para nunca ter tag duplicada no estoque.
4. Como operador, quero re-etiquetar uma unidade com tag danificada substituindo o vínculo, com registro da troca, para manter rastreabilidade.
5. Como operador, quero etiquetar em sequência (busca, lê, vincula, próxima), para tratar a fila de itens sem tag como linha de produção.
6. Como Marcelo, quero ver quantas unidades seguem sem tag, para acompanhar o avanço da etiquetagem.
7. Como operador, quero apontar o leitor pra qualquer equipamento na aba Ler tag e ver o que é, para identificar caixa fechada sem abrir.
8. Como operador, quero ver na identificação o status e a designação da unidade (disponível, em campo, packed em qual evento), para saber se posso usar aquilo agora.
9. Como operador, quero que tag desconhecida na identificação ofereça "etiquetar agora", para transformar surpresa em cadastro.
10. Como operador, quero ler QR na identificação quando não estou com o leitor, para a função existir mesmo sem RFD40.
11. Como Marcelo, quero que leituras de identificação registrem scan no backend quando configurado, para o rastro de leitura existir.

## Implementation Decisions

- Identificar mora na aba Ler tag da barra (o destino já existe em estado vazio). Etiquetar entra como ação a partir da identificação de tag desconhecida e como ação de manutenção acessível na mesma aba; não ganha aba própria.
- Resolução de tag usa o caminho que o cliente de API já tem: endpoint de scan do web quando configurado, leitura direta do banco como fallback. Esse é o único fluxo com fallback legítimo, e ele já existe.
- Busca de unidade é paginada e filtrada no servidor; proibido baixar o catálogo inteiro pro aparelho (defeito conhecido do app antigo, não porta).
- Vincular tag escreve na unidade pelo caminho de escrita que o app antigo já usa; sem contrato novo no backend.
- Conflito de tag é validado antes de gravar, e a mensagem diz qual unidade já possui a tag.
- ViewModel com leitor e cliente de API injetados, mesmo desenho dos setores 2 e 3. Lei clara, zero acento.

## Testing Decisions

- Mesma costura dos setores 2 e 3: ViewModel com rede stubada e leitor simulado.
- Casos mínimos: busca retorna paginado e não pede catálogo inteiro; vincular grava na unidade certa; tag em conflito bloqueia e nomeia a dona; re-etiquetar substitui e registra; identificar resolve tag conhecida com status e designação; tag desconhecida oferece etiquetar; caminho QR resolve igual ao RFID.
- Prior art: suítes dos setores anteriores.

## Out of Scope

- Aba Catálogo completa (destino novo da barra, frente própria).
- Impressão física de etiqueta e QR.
- Histórico da unidade (frente própria).
- Leitura de inventário em massa (varrer prateleira inteira e reconciliar): fica pra depois do básico rodar em campo.

## Further Notes

Etiquetar é o multiplicador da frente inteira: cada tag vinculada aumenta o
valor do despacho e do retorno por scan. Se a ordem interna do setor precisar de
corte, Identificar sai primeiro (destrava a aba Ler tag), Etiquetar fecha o
setor.
