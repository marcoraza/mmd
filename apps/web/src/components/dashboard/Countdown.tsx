'use client'

import { useEffect, useState } from 'react'

function format(diffMs: number): string {
  if (diffMs <= 0) return 'agora'
  const totalMinutes = Math.floor(diffMs / 60000)
  const days = Math.floor(totalMinutes / (60 * 24))
  const hours = Math.floor((totalMinutes % (60 * 24)) / 60)
  const minutes = totalMinutes % 60
  if (days > 0) return `em ${days}d ${hours}h`
  if (hours > 0) return `em ${hours}h ${minutes}m`
  return `em ${minutes}m`
}

export function Countdown({ startsAt }: { startsAt: string }) {
  const target = new Date(startsAt).getTime()
  const [label, setLabel] = useState(() => format(target - Date.now()))

  useEffect(() => {
    const tick = () => setLabel(format(target - Date.now()))
    tick()
    const id = setInterval(tick, 30_000)
    return () => clearInterval(id)
  }, [target])

  return <span>{label}</span>
}
