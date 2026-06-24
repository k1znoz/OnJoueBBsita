import { writable } from 'svelte/store'
import type { User } from '@supabase/supabase-js'
import type {
  ActiveMatchCard,
  DailyChallengeRow,
  DuelInvitation,
  GuessHistoryEntry,
  ModeCard,
  OpponentCandidate,
  PalettePeg,
  PlayerMessage,
  DuelGuessEntry,
  UserProfile,
  View,
} from '../model/types'

export type AppState = {
  modeCards: ModeCard[]
  activeMatches: ActiveMatchCard[]
  opponentCandidates: OpponentCandidate[]
  duelInvitations: DuelInvitation[]
  selectedChatUserId: string
  chatMessages: PlayerMessage[]
  communicationLoading: boolean
  sendingMessage: boolean
  managingMatchId: string | null
  selectedOpponentId: string
  duelLoading: boolean
  currentView: View
  currentMatchId: string | null
  dailyChallenge: DailyChallengeRow | null
  currentUser: User | null
  myProfile: UserProfile | null
  isLoading: boolean
  authLoading: boolean
  signOutLoading: boolean
  profileSaving: boolean
  coins: number
  toast: string
  chatInput: string
  authEmail: string
  authPassword: string
  authHandle: string
  profileHandle: string
  asyncRow: Array<PalettePeg | null>
  asyncSlot: number
  asyncAttempt: number
  guessHistory: GuessHistoryEntry[]
  myDuelGuesses: DuelGuessEntry[]
  opponentDuelGuesses: DuelGuessEntry[]
  mySecretReady: boolean
  opponentSecretReady: boolean
  secretRow: Array<PalettePeg | null>
  secretSlot: number
  isSubmittingSecret: boolean
  isSubmittingGuess: boolean
}

export function emptyAsyncRow(): Array<PalettePeg | null> {
  return [null, null, null, null]
}

export function initialAppState(): AppState {
  return {
    modeCards: [],
    activeMatches: [],
    opponentCandidates: [],
    duelInvitations: [],
    selectedChatUserId: '',
    chatMessages: [],
    communicationLoading: false,
    sendingMessage: false,
    managingMatchId: null,
    selectedOpponentId: '',
    duelLoading: false,
    currentView: 'lobby',
    currentMatchId: null,
    dailyChallenge: null,
    currentUser: null,
    myProfile: null,
    isLoading: true,
    authLoading: false,
    signOutLoading: false,
    profileSaving: false,
    coins: 0,
    toast: '',
    chatInput: '',
    authEmail: '',
    authPassword: '',
    authHandle: '',
    profileHandle: '',
    asyncRow: emptyAsyncRow(),
    asyncSlot: 0,
    asyncAttempt: 1,
    guessHistory: [],
    myDuelGuesses: [],
    opponentDuelGuesses: [],
    mySecretReady: false,
    opponentSecretReady: false,
    secretRow: emptyAsyncRow(),
    secretSlot: 0,
    isSubmittingSecret: false,
    isSubmittingGuess: false,
  }
}

export function createAppStateStore() {
  return writable<AppState>(initialAppState())
}
