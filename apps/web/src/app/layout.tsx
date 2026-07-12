import type { Metadata } from 'next'
import { Inter_Tight, JetBrains_Mono, Instrument_Serif } from 'next/font/google'
import './globals.css'
import { AppShell } from '@/components/mmd/AppShell'

const interTight = Inter_Tight({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
  variable: '--font-inter-tight',
  display: 'swap',
})

const jetBrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  weight: ['400', '500'],
  variable: '--font-jb-mono',
  display: 'swap',
})

const instrumentSerif = Instrument_Serif({
  subsets: ['latin'],
  weight: ['400'],
  style: ['normal', 'italic'],
  variable: '--font-serif',
  display: 'swap',
})

export const metadata: Metadata = {
  title: 'MMD Estoque Inteligente',
  description: 'Gestão de estoque RFID · MMD Eventos',
}

const themeInitScript = `
(function(){try{var t=localStorage.getItem('mmd-theme');if(t==='dark'){document.documentElement.classList.add('dark');}}catch(e){}})();
`

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html
      lang="pt-BR"
      className={`${interTight.variable} ${jetBrainsMono.variable} ${instrumentSerif.variable}`}
    >
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeInitScript }} />
      </head>
      <body
        style={{
          margin: 0,
          padding: 0,
          minHeight: '100dvh',
          background: 'var(--bg-0)',
          color: 'var(--fg-0)',
          fontFamily: 'var(--font-sans-raw)',
        }}
      >
        <a href="#main-content" className="skip-link">
          Pular para o conteúdo principal
        </a>
        <AppShell>{children}</AppShell>
      </body>
    </html>
  )
}
