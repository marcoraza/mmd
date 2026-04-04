'use client'

import { useEffect, useState } from 'react'
import { Search } from 'lucide-react'

interface SearchInputProps {
  value: string
  onChange: (value: string) => void
  placeholder?: string
  className?: string
}

export function SearchInput({ value, onChange, placeholder = 'Buscar...', className = '' }: SearchInputProps) {
  const [local, setLocal] = useState(value)

  useEffect(() => {
    const timeout = setTimeout(() => onChange(local), 300)
    return () => clearTimeout(timeout)
  }, [local, onChange])

  useEffect(() => {
    setLocal(value)
  }, [value])

  return (
    <div className={`relative flex items-center ${className}`}>
      <Search
        size={14}
        style={{ position: 'absolute', left: 0, color: '#999999' }}
      />
      <input
        type="text"
        value={local}
        onChange={(e) => setLocal(e.target.value)}
        placeholder={placeholder}
        style={{
          fontFamily: '"Space Mono", monospace',
          fontSize: 13,
          color: '#1A1A1A',
          background: 'none',
          border: 'none',
          borderBottom: '1px solid #CCCCCC',
          outline: 'none',
          paddingLeft: 22,
          paddingBottom: 6,
          width: '100%',
        }}
        onFocus={(e) => { e.target.style.borderBottomColor = '#000000' }}
        onBlur={(e) => { e.target.style.borderBottomColor = '#CCCCCC' }}
      />
    </div>
  )
}
