import type { View } from '../model/types'
import type { CommunicationData, HydrationData, MatchTimelineData } from './appController'
import type { AppState } from './appState'

export function buildHydrationPatch(hydration: HydrationData): Partial<AppState> {
  return {
    currentUser: hydration.currentUser,
    myProfile: hydration.profile,
    coins: hydration.coins,
    dailyChallenge: hydration.dailyChallenge,
    profileHandle: hydration.profileHandle,
    opponentCandidates: hydration.opponentCandidates,
    selectedOpponentId: hydration.selectedOpponentId,
    selectedChatUserId: hydration.selectedChatUserId,
    modeCards: hydration.modeCards,
    activeMatches: hydration.activeMatches,
    currentMatchId: hydration.currentMatchId,
  }
}

export function buildTimelinePatch(timeline: MatchTimelineData): Partial<AppState> {
  return {
    guessHistory: timeline.guessHistory,
    asyncAttempt: timeline.asyncAttempt,
    myDuelGuesses: timeline.myDuelGuesses,
    opponentDuelGuesses: timeline.opponentDuelGuesses,
    mySecretReady: timeline.mySecretReady,
    opponentSecretReady: timeline.opponentSecretReady,
  }
}

export function buildTimelineErrorPatch(toast: string): Partial<AppState> {
  return {
    guessHistory: [],
    asyncAttempt: 1,
    myDuelGuesses: [],
    opponentDuelGuesses: [],
    mySecretReady: false,
    opponentSecretReady: false,
    toast,
  }
}

export function buildCommunicationPatch(data: CommunicationData): Partial<AppState> {
  return {
    duelInvitations: data.duelInvitations,
    chatMessages: data.chatMessages,
  }
}

export function buildThreadMessagesPatch(data: CommunicationData): Partial<AppState> {
  return {
    chatMessages: data.chatMessages,
  }
}

export function buildSignedOutPatch(): Partial<AppState> {
  return {
    currentUser: null,
    myProfile: null,
    coins: 0,
    activeMatches: [],
  }
}

export function buildSessionEndedPatch(currentView: View): Partial<AppState> {
  return {
    myProfile: null,
    coins: 0,
    activeMatches: [],
    profileHandle: '',
    currentView: ['profile', 'async', 'communication'].includes(currentView) ? 'auth' : currentView,
  }
}