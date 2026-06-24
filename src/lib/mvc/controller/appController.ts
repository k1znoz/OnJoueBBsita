import type { User } from '@supabase/supabase-js'
import {
  fetchActiveGameModes,
  fetchCurrentUser,
  fetchDailyChallenge,
  fetchDuelBoard,
  fetchDuelInvitations,
  fetchMatchGuesses,
  fetchMessagesWithUser,
  fetchMyMatches,
  fetchMyProfile,
  fetchOpponentCandidates,
} from '../../supabase/services'
import { buildActiveMatches, buildGuessHistory, buildModeCards, withTimeout } from '../model/mappers'
import type {
  ActiveMatchCard,
  DailyChallengeRow,
  DuelGuessEntry,
  DuelInvitation,
  GameModeRow,
  GuessHistoryEntry,
  MatchRow,
  ModeCard,
  OpponentCandidate,
  PlayerMessage,
  UserProfile,
} from '../model/types'

export type HydrationData = {
  currentUser: User | null
  profile: UserProfile | null
  coins: number
  dailyChallenge: DailyChallengeRow | null
  profileHandle: string
  opponentCandidates: OpponentCandidate[]
  selectedOpponentId: string
  selectedChatUserId: string
  modeCards: ModeCard[]
  activeMatches: ActiveMatchCard[]
  currentMatchId: string | null
  loadErrors: string[]
}

export type GuessHistoryData = {
  guessHistory: GuessHistoryEntry[]
  asyncAttempt: number
}

export type CommunicationData = {
  duelInvitations: DuelInvitation[]
  chatMessages: PlayerMessage[]
}

export type MatchTimelineData = {
  guessHistory: GuessHistoryEntry[]
  asyncAttempt: number
  myDuelGuesses: DuelGuessEntry[]
  opponentDuelGuesses: DuelGuessEntry[]
  mySecretReady: boolean
  opponentSecretReady: boolean
}

function emptyTimelineData(): MatchTimelineData {
  return {
    guessHistory: [],
    asyncAttempt: 1,
    myDuelGuesses: [],
    opponentDuelGuesses: [],
    mySecretReady: false,
    opponentSecretReady: false,
  }
}

export async function fetchHydrationData(params: {
  preferredMatchId?: string | null
  selectedOpponentId?: string
  selectedChatUserId?: string
}): Promise<HydrationData> {
  const { preferredMatchId = null, selectedOpponentId = '', selectedChatUserId = '' } = params

  const currentUser = await withTimeout(fetchCurrentUser(), 7000, null)

  const [profileRes, modesRes, matchesRes, challengeRes] = await Promise.allSettled([
    withTimeout(fetchMyProfile(), 7000, null),
    withTimeout(fetchActiveGameModes(), 7000, [] as GameModeRow[]),
    withTimeout(fetchMyMatches(), 7000, [] as Array<MatchRow | MatchRow[]>),
    withTimeout(fetchDailyChallenge(), 7000, null),
  ])

  const opponentRes = currentUser
    ? await Promise.allSettled([withTimeout(fetchOpponentCandidates(), 7000, [] as OpponentCandidate[])])
    : [{ status: 'fulfilled', value: [] }] as const

  const profile = (profileRes.status === 'fulfilled' ? profileRes.value : null) as UserProfile | null
  const modes = (modesRes.status === 'fulfilled' ? modesRes.value : []) as GameModeRow[]
  const matches = (matchesRes.status === 'fulfilled' ? matchesRes.value : []) as Array<MatchRow | MatchRow[]>
  const challenge = (challengeRes.status === 'fulfilled' ? challengeRes.value : null) as DailyChallengeRow | null
  const opponents = (opponentRes[0].status === 'fulfilled' ? opponentRes[0].value : []) as OpponentCandidate[]

  const modeCards = buildModeCards(modes)
  const activeMatches = buildActiveMatches(matches, modes)

  const hasPreferredMatch = preferredMatchId ? activeMatches.some((match) => match.id === preferredMatchId) : false
  const currentMatchId = hasPreferredMatch ? preferredMatchId : (activeMatches[0]?.id ?? preferredMatchId ?? null)

  const nextSelectedOpponentId =
    selectedOpponentId && opponents.some((opponent) => opponent.id === selectedOpponentId)
      ? selectedOpponentId
      : (opponents[0]?.id ?? '')

  const nextSelectedChatUserId =
    selectedChatUserId && opponents.some((opponent) => opponent.id === selectedChatUserId)
      ? selectedChatUserId
      : (opponents[0]?.id ?? '')

  const loadErrors: string[] = []
  if (profileRes.status === 'rejected') loadErrors.push('profil')
  if (modesRes.status === 'rejected') loadErrors.push('modes')
  if (matchesRes.status === 'rejected') loadErrors.push('parties')
  if (challengeRes.status === 'rejected') loadErrors.push('defi')

  return {
    currentUser,
    profile,
    coins: profile?.credits ?? 0,
    dailyChallenge: challenge,
    profileHandle: profile?.handle ?? '',
    opponentCandidates: opponents,
    selectedOpponentId: nextSelectedOpponentId,
    selectedChatUserId: nextSelectedChatUserId,
    modeCards,
    activeMatches,
    currentMatchId,
    loadErrors,
  }
}

export async function fetchGuessHistoryData(matchId: string | null, currentUser: User | null): Promise<GuessHistoryData> {
  if (!matchId || !currentUser) {
    return {
      guessHistory: [],
      asyncAttempt: 1,
    }
  }

  const guesses = await withTimeout(fetchMatchGuesses(matchId), 7000, [])
  const guessHistory = buildGuessHistory(guesses)

  return {
    guessHistory,
    asyncAttempt: guessHistory.length + 1,
  }
}

export async function fetchMatchTimelineData(params: {
  matchId: string | null
  currentUser: User | null
  isDuelMatch: boolean
}): Promise<MatchTimelineData> {
  const { matchId, currentUser, isDuelMatch } = params
  if (!matchId || !currentUser) return emptyTimelineData()

  const historyData = await fetchGuessHistoryData(matchId, currentUser)
  if (!isDuelMatch) {
    return {
      ...emptyTimelineData(),
      guessHistory: historyData.guessHistory,
      asyncAttempt: historyData.asyncAttempt,
    }
  }

  const board = await withTimeout(
    fetchDuelBoard(matchId),
    7000,
    {
      mySecretReady: false,
      opponentSecretReady: false,
      myGuesses: [],
      opponentGuesses: [],
    }
  )

  return {
    guessHistory: historyData.guessHistory,
    asyncAttempt: (board.myGuesses?.length ?? 0) + 1,
    myDuelGuesses: board.myGuesses ?? [],
    opponentDuelGuesses: board.opponentGuesses ?? [],
    mySecretReady: board.mySecretReady,
    opponentSecretReady: board.opponentSecretReady,
  }
}

export async function fetchCommunicationData(
  selectedChatUserId: string,
  currentUser: User | null
): Promise<CommunicationData> {
  if (!currentUser) {
    return {
      duelInvitations: [],
      chatMessages: [],
    }
  }

  const duelInvitations = await withTimeout(fetchDuelInvitations(), 7000, [])

  if (!selectedChatUserId) {
    return {
      duelInvitations,
      chatMessages: [],
    }
  }

  const chatMessages = await withTimeout(fetchMessagesWithUser(selectedChatUserId), 7000, [])

  return {
    duelInvitations,
    chatMessages,
  }
}

export function normalizeHandleInput(rawHandle: string): string {
  return (rawHandle ?? '').trim().toLowerCase().replace(/[^a-z0-9_]/g, '')
}
