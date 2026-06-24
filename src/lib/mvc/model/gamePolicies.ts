import type { User } from '@supabase/supabase-js'
import type { ActiveMatchCard, PalettePeg, View } from './types'

export function canCancelMatch(match: ActiveMatchCard, currentUser: User | null): boolean {
  if (!currentUser) return false
  if (match.createdByUserId !== currentUser.id) return false
  return ['draft', 'active', 'waiting_turn', 'waiting_opponent'].includes(match.state)
}

export function canDeleteMatch(match: ActiveMatchCard, currentUser: User | null): boolean {
  if (!currentUser) return false
  if (match.createdByUserId !== currentUser.id) return false
  return ['completed', 'canceled', 'expired'].includes(match.state)
}

export function placePegInRow(
  row: Array<PalettePeg | null>,
  slot: number,
  peg: PalettePeg
): { row: Array<PalettePeg | null>; nextSlot: number } {
  const nextRow = [...row]
  nextRow[slot] = peg

  return {
    row: nextRow,
    nextSlot: Math.min(slot + 1, row.length - 1),
  }
}

export function getNavigationBlocker(view: View, currentUser: User | null, currentMatchId: string | null): string | null {
  if ((view === 'async' || view === 'profile' || view === 'communication') && !currentUser) {
    return 'auth_required'
  }

  if (view === 'async' && !currentMatchId) {
    return 'match_required'
  }

  return null
}

export function getSubmitGuessBlocker(params: {
  currentUser: User | null
  currentMatchId: string | null
  asyncRow: Array<PalettePeg | null>
  currentMatch: ActiveMatchCard | undefined
  guessCount: number
}): string | null {
  const { currentUser, currentMatchId, asyncRow, currentMatch, guessCount } = params

  if (!currentUser) return 'Connecte-toi pour jouer.'
  if (!currentMatchId) return 'Aucune session active.'
  if (asyncRow.some((peg) => !peg)) return 'Complete les 4 slots avant de soumettre.'
  if (currentMatch && currentMatch.state === 'waiting_opponent') {
    return 'En attente d\'un adversaire pour commencer le duel.'
  }
  if (currentMatch && currentMatch.state === 'completed') return 'Cette partie est terminee.'
  if (currentMatch && guessCount >= currentMatch.maxTurns) return 'Nombre maximum de tours atteint.'

  return null
}
