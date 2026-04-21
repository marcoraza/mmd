'use client'

import { useEffect, useRef } from 'react'
import { supabase } from '@/lib/supabase'

export function useRealtimeRefresh(
  channelName: string,
  tables: string[],
  onChange: () => void,
  debounceMs = 250,
) {
  const onChangeRef = useRef(onChange)
  const timeoutRef = useRef<number | null>(null)

  useEffect(() => {
    onChangeRef.current = onChange
  }, [onChange])

  useEffect(() => {
    const channel = supabase.channel(channelName)

    for (const table of tables) {
      channel.on(
        'postgres_changes',
        { event: '*', schema: 'public', table },
        () => {
          if (timeoutRef.current !== null) {
            window.clearTimeout(timeoutRef.current)
          }
          timeoutRef.current = window.setTimeout(() => {
            onChangeRef.current()
          }, debounceMs)
        },
      )
    }

    channel.subscribe()

    return () => {
      if (timeoutRef.current !== null) {
        window.clearTimeout(timeoutRef.current)
      }
      void supabase.removeChannel(channel)
    }
  }, [channelName, debounceMs, tables])
}
