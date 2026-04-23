import type { ReactElement } from 'react'

type IconKey =
  | 'search'
  | 'rfid'
  | 'qr'
  | 'box'
  | 'check'
  | 'x'
  | 'arrow'
  | 'plus'
  | 'bell'
  | 'chevron'
  | 'dot3'
  | 'calendar'
  | 'zap'
  | 'warn'
  | 'package'
  | 'dashboard'
  | 'chart'
  | 'event_wedding'
  | 'event_show'
  | 'event_corporate'
  | 'event_feira'
  | 'event_default'
  | 'chevron_left'
  | 'chevron_right'
  | 'cat_iluminacao'
  | 'cat_audio'
  | 'cat_energia'
  | 'cat_estrutura'
  | 'cat_efeito'
  | 'cat_video'
  | 'cat_acessorio'
  | 'cat_cabo'
  | 'star'
  | 'star_filled'
  | 'filter'
  | 'sort'
  | 'list'
  | 'kanban'
  | 'caretUp'
  | 'trash'

export const Icons: Record<IconKey, ReactElement> = {
  search: (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
      <circle cx="6" cy="6" r="4.5" stroke="currentColor" strokeWidth="1.4" />
      <path d="M9.5 9.5L12 12" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
    </svg>
  ),
  rfid: (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
      <path d="M3 11 A6 6 0 0 1 9 5 A6 6 0 0 1 15 11" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
      <path d="M5.5 11 A3.5 3.5 0 0 1 9 7.5 A3.5 3.5 0 0 1 12.5 11" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
      <circle cx="9" cy="11" r="1.3" fill="currentColor" />
    </svg>
  ),
  qr: (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <rect x="1" y="1" width="5" height="5" stroke="currentColor" strokeWidth="1.2" />
      <rect x="10" y="1" width="5" height="5" stroke="currentColor" strokeWidth="1.2" />
      <rect x="1" y="10" width="5" height="5" stroke="currentColor" strokeWidth="1.2" />
      <rect x="10" y="10" width="2" height="2" fill="currentColor" />
      <rect x="13" y="10" width="2" height="2" fill="currentColor" />
      <rect x="10" y="13" width="2" height="2" fill="currentColor" />
      <rect x="13" y="13" width="2" height="2" fill="currentColor" />
    </svg>
  ),
  box: (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
      <path d="M9 1L16.5 5v8L9 17 1.5 13V5L9 1z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round" />
      <path d="M1.5 5L9 9l7.5-4M9 9v8" stroke="currentColor" strokeWidth="1.3" />
    </svg>
  ),
  check: (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
      <path d="M2 7.5L5.5 11L12 3.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  x: (
    <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
      <path d="M2 2L10 10M10 2L2 10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  ),
  arrow: (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
      <path d="M2 7h10M8 3l4 4-4 4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  plus: (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
      <path d="M7 2v10M2 7h10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  ),
  bell: (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
      <path
        d="M7 1.5a3.5 3.5 0 0 0-3.5 3.5v2L2 9h10l-1.5-2V5A3.5 3.5 0 0 0 7 1.5zM5.5 11a1.5 1.5 0 0 0 3 0"
        stroke="currentColor"
        strokeWidth="1.3"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  ),
  chevron: (
    <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
      <path d="M3.5 2L6.5 5L3.5 8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  dot3: (
    <svg width="14" height="4" viewBox="0 0 14 4" fill="none">
      <circle cx="2" cy="2" r="1.3" fill="currentColor" />
      <circle cx="7" cy="2" r="1.3" fill="currentColor" />
      <circle cx="12" cy="2" r="1.3" fill="currentColor" />
    </svg>
  ),
  calendar: (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
      <rect x="1.5" y="3" width="11" height="9.5" rx="1.5" stroke="currentColor" strokeWidth="1.3" />
      <path d="M1.5 6h11M4.5 1.5v3M9.5 1.5v3" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
    </svg>
  ),
  zap: (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
      <path
        d="M8 1L2 8h4l-1 5 6-7H7l1-5z"
        stroke="currentColor"
        strokeWidth="1.3"
        strokeLinejoin="round"
        fill="currentColor"
        fillOpacity="0.15"
      />
    </svg>
  ),
  warn: (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
      <path d="M7 1.5l6 10.5H1L7 1.5z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round" />
      <path d="M7 5.5v3M7 10.5v0.01" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  ),
  package: (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <path d="M2 4.5L8 1.5l6 3v7L8 14.5l-6-3v-7z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round" />
      <path d="M2 4.5L8 7.5l6-3M8 7.5v7" stroke="currentColor" strokeWidth="1.3" />
    </svg>
  ),
  dashboard: (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
      <rect x="2" y="2" width="6" height="6" rx="1.5" stroke="currentColor" strokeWidth="1.3" />
      <rect x="10" y="2" width="6" height="6" rx="1.5" stroke="currentColor" strokeWidth="1.3" />
      <rect x="2" y="10" width="6" height="6" rx="1.5" stroke="currentColor" strokeWidth="1.3" />
      <rect x="10" y="10" width="6" height="6" rx="1.5" stroke="currentColor" strokeWidth="1.3" />
    </svg>
  ),
  chart: (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
      <path d="M3 15V5M9 15V2M15 15V9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  ),
  event_wedding: (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <circle cx="6" cy="9" r="3.8" stroke="currentColor" strokeWidth="1.3" />
      <circle cx="10" cy="9" r="3.8" stroke="currentColor" strokeWidth="1.3" />
    </svg>
  ),
  event_show: (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <rect x="6" y="1.5" width="4" height="7" rx="2" stroke="currentColor" strokeWidth="1.3" />
      <path d="M3.5 8a4.5 4.5 0 0 0 9 0M8 12.5V15" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
    </svg>
  ),
  event_corporate: (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <rect x="2" y="2.5" width="12" height="12" stroke="currentColor" strokeWidth="1.3" />
      <path d="M5 6h1.5M9.5 6H11M5 9h1.5M9.5 9H11M7 14.5v-3h2v3" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
    </svg>
  ),
  event_feira: (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <path d="M2 6.5L8 2l6 4.5V14H2V6.5z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round" />
      <path d="M5.5 14V9.5h5V14" stroke="currentColor" strokeWidth="1.3" />
    </svg>
  ),
  event_default: (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <rect x="2" y="3.5" width="12" height="10.5" rx="1.5" stroke="currentColor" strokeWidth="1.3" />
      <path d="M2 7h12M5.5 1.5v3M10.5 1.5v3" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
    </svg>
  ),
  chevron_left: (
    <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
      <path d="M7.5 2L4 6l3.5 4" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  chevron_right: (
    <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
      <path d="M4.5 2L8 6l-3.5 4" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  cat_iluminacao: (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <path d="M8 1.5v2M3 3l1.4 1.4M13 3l-1.4 1.4M2 7.5h2M12 7.5h2" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
      <circle cx="8" cy="8" r="3.2" stroke="currentColor" strokeWidth="1.3" />
      <path d="M6.5 11.5h3M7 13.5h2" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
    </svg>
  ),
  cat_audio: (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <path d="M7.5 2.5L4 5.5H1.5v5H4l3.5 3v-11z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round" />
      <path d="M10.5 5.5a3.5 3.5 0 0 1 0 5M12.5 3.5a6 6 0 0 1 0 9" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
    </svg>
  ),
  cat_energia: (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <path d="M9 1.5L3 9h4l-1 5.5L12 7H8l1-5.5z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round" />
    </svg>
  ),
  cat_estrutura: (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <rect x="2" y="2" width="12" height="12" stroke="currentColor" strokeWidth="1.3" />
      <path d="M2 2l12 12M14 2L2 14" stroke="currentColor" strokeWidth="1.3" />
    </svg>
  ),
  cat_efeito: (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <path d="M8 2v3M8 11v3M2 8h3M11 8h3M3.5 3.5l2 2M10.5 10.5l2 2M3.5 12.5l2-2M10.5 5.5l2-2" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
      <circle cx="8" cy="8" r="1.3" fill="currentColor" />
    </svg>
  ),
  cat_video: (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <rect x="1.5" y="4" width="9" height="8" rx="1" stroke="currentColor" strokeWidth="1.3" />
      <path d="M10.5 7l4-2v6l-4-2z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round" />
    </svg>
  ),
  cat_acessorio: (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <circle cx="8" cy="8" r="2.5" stroke="currentColor" strokeWidth="1.3" />
      <path d="M8 1.5v3M8 11.5v3M1.5 8h3M11.5 8h3M3.5 3.5l2 2M10.5 10.5l2 2M3.5 12.5l2-2M10.5 5.5l2-2" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
    </svg>
  ),
  cat_cabo: (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <path d="M2 12c2 0 2-8 4-8s2 8 4 8 2-8 4-8" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" fill="none" />
    </svg>
  ),
  star: (
    <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
      <path d="M6 1l1.55 3.15L11 4.65l-2.5 2.43.6 3.45L6 8.9 2.9 10.53l.6-3.45L1 4.65l3.45-.5L6 1z" stroke="currentColor" strokeWidth="1" strokeLinejoin="round" fill="none" />
    </svg>
  ),
  star_filled: (
    <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
      <path d="M6 1l1.55 3.15L11 4.65l-2.5 2.43.6 3.45L6 8.9 2.9 10.53l.6-3.45L1 4.65l3.45-.5L6 1z" fill="currentColor" stroke="currentColor" strokeWidth="1" strokeLinejoin="round" />
    </svg>
  ),
  filter: (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
      <path d="M1.5 2.5h11l-4 5v4l-3 1.5v-5.5l-4-5z" stroke="currentColor" strokeWidth="1.3" strokeLinejoin="round" />
    </svg>
  ),
  sort: (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
      <path d="M4 2v10M4 2l-2 2M4 2l2 2M10 12V2M10 12l-2-2M10 12l2-2" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  list: (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
      <path d="M2 3.5h10M2 7h10M2 10.5h10" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
    </svg>
  ),
  kanban: (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
      <rect x="1.5" y="2" width="3" height="10" rx="0.8" stroke="currentColor" strokeWidth="1.3" />
      <rect x="5.5" y="2" width="3" height="6" rx="0.8" stroke="currentColor" strokeWidth="1.3" />
      <rect x="9.5" y="2" width="3" height="8" rx="0.8" stroke="currentColor" strokeWidth="1.3" />
    </svg>
  ),
  caretUp: (
    <svg width="8" height="6" viewBox="0 0 8 6" fill="none">
      <path d="M1 5l3-3 3 3" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  trash: (
    <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
      <path d="M2 3.5h8M4.5 3V1.5h3V3M3 3.5l.5 7h5L9 3.5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
}
