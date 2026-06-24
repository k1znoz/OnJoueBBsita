import type { PalettePeg, View } from './types'

export const asyncPalette: PalettePeg[] = [
  { symbol: 'circle', tone: 'primary' },
  { symbol: 'pentagon', tone: 'secondary' },
  { symbol: 'square', tone: 'tertiary' },
  { symbol: 'change_history', tone: 'error' },
  { symbol: 'star', tone: 'neutral' },
  { symbol: 'diamond', tone: 'neutral' },
]

export const viewTitle: Record<View, string> = {
  lobby: 'Lobby',
  modes: 'Modes',
  async: 'Session',
  communication: 'Communication',
  auth: 'Compte',
  profile: 'Profil',
}
