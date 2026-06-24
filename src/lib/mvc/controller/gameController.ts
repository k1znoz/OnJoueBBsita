import { getSubmitGuessBlocker } from '../model/gamePolicies'
import type { ActiveMatchCard, PalettePeg } from '../model/types'
import type { AppState } from './appState'

type GameplaySlice = Pick<
  AppState,
  'activeMatches' | 'currentMatchId' | 'mySecretReady' | 'opponentSecretReady' | 'currentUser' | 'asyncRow' | 'myDuelGuesses' | 'guessHistory'
>

export function getCurrentMatch(state: Pick<AppState, 'activeMatches' | 'currentMatchId'>): ActiveMatchCard | undefined {
  return state.activeMatches.find((match) => match.id === state.currentMatchId)
}

export function getSecretSubmissionBlocker(
  state: Pick<AppState, 'isSubmittingSecret' | 'mySecretReady' | 'currentMatchId' | 'secretRow'>,
  currentMatch: ActiveMatchCard | undefined
): string | null {
  if (state.isSubmittingSecret || state.mySecretReady) return 'noop'
  if (currentMatch?.queueType !== 'duel') return 'Le codeur manuel est reserve au mode duel.'
  if (!state.currentMatchId) return 'Aucune session active.'
  if (state.secretRow.some((peg) => !peg)) return 'Complete les 4 slots avant de verrouiller ton code.'
  return null
}

export function getDuelReadinessBlocker(state: Pick<AppState, 'mySecretReady' | 'opponentSecretReady'>): string | null {
  if (!state.mySecretReady) return 'Verrouille ton code secret avant de lancer un essai.'
  if (!state.opponentSecretReady) return 'En attente du code secret adverse avant de commencer.'
  return null
}

function guessCountForValidation(state: GameplaySlice, currentMatch: ActiveMatchCard | undefined): number {
  return currentMatch?.queueType === 'duel' ? state.myDuelGuesses.length : state.guessHistory.length
}

export function getGuessSubmissionBlocker(state: GameplaySlice, currentMatch: ActiveMatchCard | undefined): string | null {
  if (currentMatch?.queueType === 'duel') {
    const duelBlocker = getDuelReadinessBlocker(state)
    if (duelBlocker) return duelBlocker
  }

  return getSubmitGuessBlocker({
    currentUser: state.currentUser,
    currentMatchId: state.currentMatchId,
    asyncRow: state.asyncRow as Array<PalettePeg | null>,
    currentMatch,
    guessCount: guessCountForValidation(state, currentMatch),
  })
}
