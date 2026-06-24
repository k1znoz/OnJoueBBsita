import type { User } from '@supabase/supabase-js'
import type { AppState } from './appState'
import { APP_MESSAGES } from './messages'

export function getSendMessageBlocker(state: Pick<AppState, 'sendingMessage' | 'selectedChatUserId' | 'chatInput'>): string | 'noop' | null {
  if (state.sendingMessage) return 'noop'
  if (!state.selectedChatUserId) return APP_MESSAGES.chatChooseUser
  if (!state.chatInput.trim()) return APP_MESSAGES.chatEmpty
  return null
}

export function getSignUpBlocker(state: Pick<AppState, 'authEmail' | 'authPassword' | 'authHandle'>): string | null {
  if (!state.authEmail || !state.authPassword || !state.authHandle) return APP_MESSAGES.signUpRequiredFields
  return null
}

export function getSignInBlocker(state: Pick<AppState, 'authEmail' | 'authPassword'>): string | null {
  if (!state.authEmail || !state.authPassword) return APP_MESSAGES.signInRequiredFields
  return null
}

export function getProfileSaveBlocker(params: {
  currentUser: User | null
  normalizedHandle: string
  currentHandle: string
}): string | null {
  const { currentUser, normalizedHandle, currentHandle } = params
  if (!currentUser) return null
  if (!normalizedHandle) return APP_MESSAGES.profileHandleInvalid
  if (normalizedHandle === currentHandle) return APP_MESSAGES.profileNoChange
  return null
}

export function getModeChoiceBlocker(currentUser: User | null): string | null {
  if (!currentUser) return APP_MESSAGES.modeAuthRequired
  return null
}

export function getDuelChallengeBlocker(state: Pick<AppState, 'duelLoading' | 'currentUser' | 'selectedOpponentId'>): string | 'noop' | null {
  if (state.duelLoading) return 'noop'
  if (!state.currentUser) return APP_MESSAGES.modeAuthRequired
  if (!state.selectedOpponentId) return APP_MESSAGES.duelChooseOpponent
  return null
}
