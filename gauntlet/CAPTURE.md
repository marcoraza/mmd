# CAPTURE.md: detalhe do evento

Servidor próprio do gauntlet:

```sh
cd /Users/marko/Projects/mmd/tasks/evidence/home-2.0
python3 -m http.server 8933 --bind 127.0.0.1
```

Saúde obrigatória:

```sh
curl -s -o /dev/null -w "%{http_code}\n" \
  "http://127.0.0.1:8933/prototipo-eventpro-c-finalizacao.html?tab=eventos&scene=event-detail"
```

O resultado deve ser `200`.

Captura por rodada, com `NN` substituído pelo número:

```sh
HASH=$(git rev-parse --short HEAD)
node /Users/marko/code/agent-hub/skills/raza-gauntlet/tools/capture.mjs \
  --url "http://127.0.0.1:8933/prototipo-eventpro-c-finalizacao.html?tab=eventos&scene=event-detail&v=$HASH" \
  --out "/Users/marko/Projects/mmd/gauntlet/rounds/NN" \
  --name detalhe-evento \
  --sizes 390x844,1440x1000 \
  --scheme light \
  --require-from /Users/marko/Projects/mmd
```

Gate fixo, calibrado na Rodada 0:

```sh
for f in /Users/marko/Projects/mmd/gauntlet/rounds/NN/detalhe-evento-*.png; do
  node /Users/marko/code/agent-hub/skills/raza-gauntlet/tools/evidence-gate.mjs "$f" --max-blank 0.80
done
```

Saída esperada: PNG mobile 390x844 e PNG de contexto 1440x1000, ambos em tema claro.
