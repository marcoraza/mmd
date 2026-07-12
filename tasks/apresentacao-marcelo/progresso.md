# Progresso: deck index.html (como o sistema funciona por dentro)

Arquivo servido como dev: preview "deck" (launch.json), porta 4321. Abre direto no navegador também (index.html).

Direção: didática, item a item. O sócio precisa ENTENDER, não se impressionar. Sem frases de efeito.

## Seções (todas verificadas em desktop + mobile)
- [verificado] Hero: subtítulo explicativo + índice navegável + 4 números âncora
- [verificado] As 3 partes do sistema: diagrama de camadas (apps -> motor -> banco)
- [verificado] O que é o Supabase: o que é / como funciona + analogia
- [verificado] As tabelas do banco, uma a uma: 12 cards (nome, nome técnico, contagem real, o que guarda)
- [verificado] Como o banco funciona no dia a dia: 4 comportamentos
- [verificado] O que é o motor: o que é / como funciona + 4 exemplos de regra
- [verificado] Tipo vs unidade física + barras por categoria
- [verificado] Cálculo de valor: 3 medidas + fórmula + exemplo numérico (R$520)
- [verificado] Loop passo a passo: diagrama + 5 cards em 3 colunas (você faz / motor faz / no banco)
- [verificado] Web e campo, mesma regra
- [verificado] RFID: fluxo ponta a ponta + plano de teste + status
- [verificado] Segurança e papéis + auditoria
- [verificado] Estado honesto: pronto vs por ativar
- [verificado] Resumo em cinco frases

## Verificação
- [verificado] Servido via preview "deck" (porta 4321), console sem erro
- [verificado] Full-page desktop (1280) sem quebra, 12 tabelas + 5 passos presentes
- [verificado] Full-page mobile (coluna única) sem estouro horizontal
- [verificado] Barras preenchem, count-up chega nos valores reais
- [verificado] Números batem com inventario-motor.md
- [verificado] Zero em-dash

## Notas
- Renomeado de motor-mmd.html para index.html (pra servir como dev na raiz).
- Diagrama do loop tem min-width 720 com scroll horizontal interno em telas estreitas (proposital).
- Reveal visível por padrão + rede de segurança no load (não depende de scroll).
