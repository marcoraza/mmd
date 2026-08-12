const MCP_DATABASE_ROLE = 'mmd_mcp_executor'

export function mcpDatabaseConfiguration(
  value = process.env.MMD_MCP_DATABASE_URL,
  allowLocal = process.env.NODE_ENV !== 'production',
  supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL,
) {
  if (!value?.trim()) return null
  try {
    const url = new URL(value)
    if (url.protocol !== 'postgres:' && url.protocol !== 'postgresql:') return null
    const databaseUserParts = decodeURIComponent(url.username).split('.')
    const databaseUser = databaseUserParts[0]
    if (databaseUser !== MCP_DATABASE_ROLE || !url.password || url.pathname === '/') return null

    const localHost = url.hostname === '127.0.0.1' || url.hostname === 'localhost'
    const supabaseHost =
      /^db\.[a-z0-9]+\.supabase\.co$/.test(url.hostname) ||
      /^[a-z0-9-]+\.pooler\.supabase\.com$/.test(url.hostname)
    if ((!allowLocal || !localHost) && !supabaseHost) return null

    if (!localHost) {
      const projectUrl = new URL(supabaseUrl ?? '')
      const projectRef = projectUrl.hostname.match(/^([a-z0-9]+)\.supabase\.co$/)?.[1]
      const databaseProjectRef = url.hostname.startsWith('db.')
        ? url.hostname.split('.')[1]
        : databaseUserParts[1]
      if (!projectRef || databaseProjectRef !== projectRef) return null
    }

    return {
      connectionString: url.href,
      local: localHost,
    }
  } catch {
    return null
  }
}
