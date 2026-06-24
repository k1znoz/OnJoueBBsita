import { signInWithEmail, signOutCurrentUser, signUpWithEmail, updateMyProfile, createMatch, joinOrCreateDuel, createDuelInvite, acceptDuelInvite, cancelMatch, deleteMatch, submitGuess, sendPlayerMessage } from '../../supabase/services'
import type { ActiveMatchCard, ModeCard, PalettePeg } from '../model/types'
import { withTimeout } from '../model/mappers'

export async function signUpUser(params: { email: string; password: string; handle: string }) {
  return signUpWithEmail(params)
}

export async function signInUser(params: { email: string; password: string }) {
  return signInWithEmail(params)
}

export async function signOutUser() {
  return withTimeout(signOutCurrentUser(), 5000, undefined)
}

export async function saveUserProfileHandle(handle: string) {
  return updateMyProfile({ handle })
}

export async function startModeMatch(card: ModeCard): Promise<{ id: string; state?: string; isDuel: boolean }> {
  const isDuel = card.code?.includes('duel')
  const match = isDuel ? await joinOrCreateDuel({ modeId: card.modeId }) : await createMatch({ modeId: card.modeId })

  return {
    id: match.id as string,
    state: match.state as string | undefined,
    isDuel,
  }
}

export async function createDuelInvitation(params: { modeId: string; opponentId: string }) {
  return createDuelInvite({
    modeId: params.modeId,
    opponentId: params.opponentId,
  })
}

export async function acceptInvitationMatch(matchId: string) {
  return acceptDuelInvite(matchId)
}

export async function openMatchWithAutoAccept(params: {
  match: ActiveMatchCard
  currentUserId?: string
}): Promise<{ id: string }> {
  const { match, currentUserId } = params

  if (match.state === 'waiting_opponent' && currentUserId && currentUserId !== match.createdByUserId) {
    await acceptDuelInvite(match.id)
  }

  return { id: match.id }
}

export async function manageMatchLifecycle(params: { matchId: string; action: 'cancel' | 'delete' }) {
  if (params.action === 'cancel') {
    await cancelMatch(params.matchId)
    return { message: 'Partie annulee.' }
  }

  await deleteMatch(params.matchId)
  return { message: 'Partie supprimee.' }
}

export async function submitMatchGuessRow(params: { matchId: string; row: Array<PalettePeg | null> }) {
  return submitGuess({
    matchId: params.matchId,
    payload: { row: params.row.map((peg) => peg?.symbol ?? null) },
  })
}

export async function sendChatMessage(params: { recipientUserId: string; body: string }) {
  const cleanBody = params.body.trim()
  return sendPlayerMessage(params.recipientUserId, cleanBody)
}
