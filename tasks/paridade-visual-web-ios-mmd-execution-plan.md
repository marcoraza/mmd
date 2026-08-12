# Plano de execução: paridade visual Web e iOS MMD

Trava: `docs/operations/PARIDADE_VISUAL_WEB_IOS_MMD_GOAL.md`

1. Ler a task `MMD · iOS white redesign` e registrar arquivos, variantes e decisões ativas.
2. Criar snapshot isolado do working tree atual para preservar protótipos vivos sem interferir na sessão iOS.
3. Renderizar as superfícies iOS aprovadas e capturar estados relevantes.
4. Renderizar as rotas Web equivalentes em desktop e largura móvel.
5. Comparar tokens, tipografia, cor, superfícies, hierarquia, ícones, motion e densidade.
6. Separar divergência acidental de adaptação correta ao dispositivo.
7. Produzir crosswalk por primitive e matriz por tela.
8. Criar backlog de implementação Web com prioridade, arquivos prováveis e critério visual.
9. Rodar review design independente e remover recomendações genéricas.

Skills ativáveis:
- `taste-playbook`: routing visual e constraints.
- `taste-redesign`: auditoria do Web existente.
- `jakubkrehel-better-ui`: hierarquia e componentes.
- `tushar-remove-ai-slop`: padrões genéricos e excesso decorativo.
- `browser:control-in-app-browser`: prova renderizada.
- `hardikpandya-stop-slop`: clareza do relatório.

Condição de parada: outro agente consegue implementar a adaptação Web sem reinterpretar o iOS, e cada recomendação possui evidência renderizada.
