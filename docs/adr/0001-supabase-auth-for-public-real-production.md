# Supabase Auth for public real production

Produção real pública vai usar Supabase Auth, em vez de depender só de Vercel Authentication, senha compartilhada ou URL privada. No produto existem dois perfis humanos: equipe operacional, que opera o estoque no dia a dia, e admin, que gerencia usuários e ações destrutivas. A decisão existe porque dados reais de estoque, valores, localização e movimentações não podem ficar protegidos apenas por obscuridade.
