# Spec · RFID 01 · Fundação: serviço, leitor e modos honestos

Frente RFID do Event Pro, setor 1 de 4. Origem: port do MMDEstoque na lei clara
Ponte de cinza (handoff event-pro-2, seções 6 e 7; inventário das telas antigas).

## Problem Statement

O Event Pro não lê tag nenhuma. O leitor Zebra RFD40, que é o coração da operação
de galpão, só funciona no app antigo, que está a caminho da aposentadoria. Sem a
fundação de RFID no app novo, nenhum fluxo de campo (despacho, retorno,
etiquetar, identificar) pode ser portado, e o critério 1 da aposentadoria do
MMDEstoque fica travado.

Agravante herdado: a versão original do serviço caía silenciosamente em modo
simulado quando o SDK Zebra não estava disponível. Em campo, isso mente: o
operador vê "lendo" sem ler nada.

## Solution

A camada de serviço de RFID do MMDEstoque portada para o Event Pro: uma fachada
observável que as views consomem, com três modos explícitos (simulado, Zebra,
Zebra indisponível) e nunca um fallback silencioso. O leitor RFD40 conecta via
Bluetooth, com pareamento e status vivendo em Ajustes, ditos na lei clara: estado
por rótulo e peso, sem semáforo.

## User Stories

1. Como operador de galpão, quero parear o leitor RFD40 por Bluetooth dentro do app, para não depender do app antigo.
2. Como operador, quero ver em Ajustes se o leitor está conectado, desconectado ou indisponível, para saber se posso confiar no scan antes de começar.
3. Como operador, quero que o app diga "Zebra indisponível" quando o SDK não existe no build, para nunca ver leitura simulada achando que é real.
4. Como operador, quero que o gatilho físico do RFD40 dispare a leitura, para operar com uma mão só.
5. Como operador, quero ver o nível de bateria do leitor quando conectado, para não começar um evento com leitor morrendo.
6. Como desenvolvedor, quero um modo simulado explícito no simulador, para desenvolver e demonstrar fluxos sem hardware.
7. Como desenvolvedor, quero que o modo simulado emita tags de teste realistas, para exercitar validação de packing sem galpão.
8. Como Marcelo (dono da operação), quero que a conexão sobreviva a ida e volta de background, para o leitor não cair no meio de um despacho.
9. Como operador, quero reconectar com um toque quando a conexão cair, para não refazer pareamento no meio do trabalho.
10. Como equipe, queremos que qualquer tela futura de scan consuma o mesmo serviço, para o comportamento do leitor ser um só no app inteiro.

## Implementation Decisions

- Portar a camada de serviço do MMDEstoque como está na versão commitada no momento da implementação: protocolo de gerenciamento, implementação Zebra, implementação simulada e a fachada observável que as views consomem.
- Três modos de runtime explícitos: simulado (pedido pelo desenvolvedor), Zebra (SDK presente), Zebra indisponível (SDK ausente). Proibido fallback silencioso de Zebra para simulado; a implementação indisponível não emite tag nenhuma. Este requisito absorve o refinamento em voo na frente RFID do MMDEstoque.
- SDK Zebra linkado condicionalmente por disponibilidade de import, espelhando a configuração de projeto do MMDEstoque (framework e permissões de Bluetooth no Info.plist).
- Pareamento e status do leitor vivem em Ajustes (que abre pelo avatar). A aba Ler tag é assunto do setor 4.
- Status na lei clara: rótulo em texto com peso ("Conectado" firme, "Desconectado" e "Zebra indisponível" com o peso e a cor de texto secundário da escala de cinza), sem verde, âmbar ou vermelho.
- Nasce o target de testes do Event Pro neste setor; os setores seguintes herdam.

## Testing Decisions

- Costura: a fachada observável com implementação injetada por fábrica. Testa comportamento externo: modo resolvido por cenário, transições de estado de conexão, fluxo de tags chegando ao observador, ausência total de emissão no modo indisponível.
- Portar e adaptar a suíte de testes de RFID que já existe no MMDEstoque (prior art direto).
- Regra herdada de lição do projeto: teste não escreve em UserDefaults padrão do app host sem restaurar; suíte isolada ou tearDown que restaura.
- Passada em device real com RFD40 é verificação manual documentada (checklist), não teste automatizado.

## Out of Scope

- Telas de fluxo: despacho (setor 2), retorno (setor 3), etiquetar e identificar (setor 4).
- Aposentadoria do MMDEstoque (tem critérios próprios na Fase 2 do handoff).
- Registro de scan no backend (entra nos setores de fluxo).
- Qualquer mudança no projeto Supabase ou nos endpoints do web.

## Further Notes

O working tree do repositório tem trabalho de RFID não commitado no MMDEstoque
(outra frente). Esta spec não depende dele: o requisito de "sem fallback
silencioso" está registrado aqui como comportamento, e o port referencia o
estado commitado na hora da implementação.
