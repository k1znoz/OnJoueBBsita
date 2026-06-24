import type { PalettePeg, View } from './types'

export const asyncPalette: PalettePeg[] = [
  { symbol: 'circle', tone: 'primary' },
  { symbol: 'pentagon', tone: 'secondary' },
  { symbol: 'square', tone: 'tertiary' },
  { symbol: 'change_history', tone: 'error' },
  { symbol: 'star', tone: 'violet' },
  { symbol: 'diamond', tone: 'mint' },
  { symbol: 'hexagon', tone: 'slate' },
  { symbol: 'bolt', tone: 'neutral' },
]

export const viewTitle: Record<View, string> = {
  lobby: 'Lobby',
  modes: 'Modes',
  async: 'Session',
  communication: 'Communication',
  auth: 'Compte',
  profile: 'Profil',
}
