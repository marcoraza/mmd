'use server'

import { redirect } from 'next/navigation'

import { registeredMcpClient } from '@/lib/mcp-auth'
import { decideMcpAuthorizationCore } from '@/lib/mcp-consent-core'
import { createSupabaseCookieClient, getVerifiedUser } from '@/lib/supabase-ssr'

export async function decideMcpAuthorization(formData: FormData) {
  const supabase = await createSupabaseCookieClient()
  const target = await decideMcpAuthorizationCore(
    formData.get('authorization_id'),
    formData.get('decision'),
    {
      currentUserId: async () => (await getVerifiedUser())?.id ?? null,
      authorizationDetails: async (authorizationId) => {
        const { data, error } = await supabase.auth.oauth.getAuthorizationDetails(authorizationId)
        if (error || !data) return null
        return 'authorization_id' in data
          ? {
              state: 'pending',
              userId: data.user.id,
              clientId: data.client.id,
            }
          : { state: 'resolved', redirectUrl: data.redirect_url }
      },
      clientIsRegistered: async (clientId) => Boolean(await registeredMcpClient(clientId)),
      approve: async (authorizationId) => {
        const { data, error } = await supabase.auth.oauth.approveAuthorization(authorizationId, {
          skipBrowserRedirect: true,
        })
        return error || !data ? null : data.redirect_url
      },
      deny: async (authorizationId) => {
        const { data, error } = await supabase.auth.oauth.denyAuthorization(authorizationId, {
          skipBrowserRedirect: true,
        })
        return error || !data ? null : data.redirect_url
      },
    },
  )
  redirect(target)
}
