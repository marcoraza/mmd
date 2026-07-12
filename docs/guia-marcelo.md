# Guia de Demo: Marcelo, MMD Estoque

Atualizado em 2026-06-23 para o PRD MAR-171.

Objetivo: mostrar o sistema web funcionando como centro de controle do estoque.

## Roteiro de 10 minutos

1. Abrir o dashboard.
   - Mostrar visão geral de disponíveis, em campo, manutenção e patrimônio.
   - Explicar que a tela é o painel de controle do estoque.

2. Abrir o catálogo.
   - Buscar um item.
   - Abrir o detalhe.
   - Mostrar unidades, status, desgaste, valor e histórico.

3. Abrir Eventos.
   - Abrir um Evento de exemplo.
   - Mostrar packing list e alocação.
   - Explicar que é aqui que a equipe prepara a saída do evento.

4. Mostrar cabos como unidades.
   - Explicar que lotes viraram legado.
   - Explicar que o caminho futuro é cabo como unidade rastreável com QR/RFID próprio.

5. Gerar QR codes.
   - Selecionar poucas unidades.
   - Gerar PDF.
   - Mostrar que a folha sai pronta para impressão.
   - Abrir um QR pela rota `/s/[codigo]`, usando a ficha pública segura.
   - Explicar que QR público não mostra valor, serial, RFID, localização nem histórico.

6. Mostrar RFID.
   - Explicar que a tela já organiza tags e leituras.
   - Dizer que o RFD40 real entra depois do teste com SDK e aparelho.

## Frase honesta sobre RFID e iOS

O web é o centro operacional principal. O iOS já compila e roda no simulador, mas leitor Zebra real e TestFlight precisam de signing, RFD40, tags reais e teste em aparelho antes de serem vendidos como prontos.

## Pontos fortes para apresentar

- O estoque deixa de depender de planilha solta.
- Cada unidade tem código interno.
- QR PDF já vira material físico de operação.
- Evento, packing e movimentação ficam no mesmo fluxo.
- Supabase vira a fonte única de verdade.

## O que fica para a próxima etapa

- Parear e validar RFD40 real.
- Distribuir iOS via TestFlight ou ad-hoc.
- Validar Supabase real com login `editor/admin`.
- Provar uma ação real auditada gravando operador correto.
- Fechar dashboard com dados reais aplicados no Supabase.

## Checklist antes da reunião

- Produção pública abre: `https://mmd-zeta.vercel.app`.
- Produção pública deve permanecer em modo demo ou controlado até auth real estar validado.
- `/items` carrega dados demo.
- `/projetos` carrega dados demo.
- `/qrcodes` gera PDF.
- `/s/MMD-ILU-0001` abre ficha pública sem expor dados sensíveis.
- Não prometer RFID real sem teste em aparelho.
