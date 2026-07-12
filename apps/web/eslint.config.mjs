import { defineConfig, globalIgnores } from 'eslint/config'
import nextVitals from 'eslint-config-next/core-web-vitals'
import nextTs from 'eslint-config-next/typescript'
import reactCompiler from 'eslint-plugin-react-compiler'
import jsxA11y from 'eslint-plugin-jsx-a11y'

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  // jsx-a11y recomendado (34 regras). eslint-config-next já registrou o plugin
  // (6 regras como warning). Aqui adicionamos só as rules do recommended,
  // re-registrar `plugins: { 'jsx-a11y': jsxA11y }` aqui dispara
  // `Cannot redefine plugin "jsx-a11y"` no ESLint 9, então depende mesmo da
  // ordem dos spreads acima. Manter `nextVitals` e `nextTs` antes desta entry.
  {
    rules: jsxA11y.flatConfigs.recommended.rules,
  },
  // Pré-requisito antes de ativar React Compiler em next.config.ts.
  // Detecta componentes/hooks com padrões incompatíveis (mutação direta, refs misturadas, etc).
  {
    plugins: {
      'react-compiler': reactCompiler,
    },
    rules: {
      'react-compiler/react-compiler': 'error',
    },
  },
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    '.next/**',
    'out/**',
    'build/**',
    'next-env.d.ts',
    // Design handoff mocks: standalone JSX servidos como assets, não fazem parte do build.
    'public/**',
  ]),
])

export default eslintConfig
