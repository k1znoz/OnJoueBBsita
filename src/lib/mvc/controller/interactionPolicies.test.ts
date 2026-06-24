import { describe, expect, it } from 'vitest'
import { APP_MESSAGES } from './messages'
import {
  getDuelChallengeBlocker,
  getModeChoiceBlocker,
  getProfileSaveBlocker,
  getSendMessageBlocker,
  getSignInBlocker,
  getSignUpBlocker,
} from './interactionPolicies'

describe('interactionPolicies', () => {
  it('blocks empty message and missing target chat user', () => {
    expect(
      getSendMessageBlocker({
        sendingMessage: false,
        selectedChatUserId: '',
        chatInput: 'hello',
      })
    ).toBe(APP_MESSAGES.chatChooseUser)

    expect(
      getSendMessageBlocker({
        sendingMessage: false,
        selectedChatUserId: 'u1',
        chatInput: '   ',
      })
    ).toBe(APP_MESSAGES.chatEmpty)
  })

  it('returns noop while message is already being sent', () => {
    expect(
      getSendMessageBlocker({
        sendingMessage: true,
        selectedChatUserId: 'u1',
        chatInput: 'hello',
      })
    ).toBe('noop')
  })

  it('validates sign-up required fields', () => {
    expect(getSignUpBlocker({ authEmail: '', authPassword: 'pw', authHandle: 'h' })).toBe(APP_MESSAGES.signUpRequiredFields)
    expect(getSignUpBlocker({ authEmail: 'a@a.com', authPassword: 'pw', authHandle: 'h' })).toBeNull()
  })

  it('validates sign-in required fields', () => {
    expect(getSignInBlocker({ authEmail: '', authPassword: 'pw' })).toBe(APP_MESSAGES.signInRequiredFields)
    expect(getSignInBlocker({ authEmail: 'a@a.com', authPassword: 'pw' })).toBeNull()
  })

  it('validates profile save blockers', () => {
    expect(
      getProfileSaveBlocker({
        currentUser: {} as never,
        normalizedHandle: '',
        currentHandle: 'alice',
      })
    ).toBe(APP_MESSAGES.profileHandleInvalid)

    expect(
      getProfileSaveBlocker({
        currentUser: {} as never,
        normalizedHandle: 'alice',
        currentHandle: 'alice',
      })
    ).toBe(APP_MESSAGES.profileNoChange)

    expect(
      getProfileSaveBlocker({
        currentUser: null,
        normalizedHandle: '',
        currentHandle: 'alice',
      })
    ).toBeNull()
  })

  it('requires auth for mode choice', () => {
    expect(getModeChoiceBlocker(null)).toBe(APP_MESSAGES.modeAuthRequired)
    expect(getModeChoiceBlocker({} as never)).toBeNull()
  })

  it('validates duel challenge blockers in order', () => {
    expect(
      getDuelChallengeBlocker({
        duelLoading: true,
        currentUser: {} as never,
        selectedOpponentId: 'u1',
      })
    ).toBe('noop')

    expect(
      getDuelChallengeBlocker({
        duelLoading: false,
        currentUser: null,
        selectedOpponentId: 'u1',
      })
    ).toBe(APP_MESSAGES.modeAuthRequired)

    expect(
      getDuelChallengeBlocker({
        duelLoading: false,
        currentUser: {} as never,
        selectedOpponentId: '',
      })
    ).toBe(APP_MESSAGES.duelChooseOpponent)

    expect(
      getDuelChallengeBlocker({
        duelLoading: false,
        currentUser: {} as never,
        selectedOpponentId: 'u1',
      })
    ).toBeNull()
  })
})
