import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

/**
 * Combina classes Tailwind com merge correto de utilitários conflitantes.
 * Use em qualquer componente que aceite className como prop.
 *
 * cn('p-2 text-fg-1', condition && 'bg-glass-bg', extraClass)
 */
export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs))
}
