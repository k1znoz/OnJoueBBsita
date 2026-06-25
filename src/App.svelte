<script lang="ts">
  import { onMount } from 'svelte'
  import { get } from 'svelte/store'
  import { hasSupabaseConfig, supabase } from './lib/supabase/client'
  import TopBar from './lib/mvc/view/components/TopBar.svelte'
  import LobbyPanel from './lib/mvc/view/components/LobbyPanel.svelte'
  import ModesPanel from './lib/mvc/view/components/ModesPanel.svelte'
  import AsyncPanel from './lib/mvc/view/components/AsyncPanel.svelte'
  import CommunicationPanel from './lib/mvc/view/components/CommunicationPanel.svelte'
  import AuthPanel from './lib/mvc/view/components/AuthPanel.svelte'
  import ProfilePanel from './lib/mvc/view/components/ProfilePanel.svelte'
  import BottomNav from './lib/mvc/view/components/BottomNav.svelte'
  import type {
    ActiveMatchCard,
    DuelInvitation,
    ModeCard,
    PalettePeg,
    View,
  } from './lib/mvc/model/types'
  import { getErrorMessage } from './lib/mvc/model/mappers'
  import { asyncPalette } from './lib/mvc/model/constants'
  import {
    canCancelMatch as policyCanCancelMatch,
    canDeleteMatch as policyCanDeleteMatch,
    getNavigationBlocker,
    placePegInRow,
  } from './lib/mvc/model/gamePolicies'
  import {
    fetchCommunicationData,
    fetchHydrationData,
    fetchMatchTimelineData,
    normalizeHandleInput,
  } from './lib/mvc/controller/appController'
  import { APP_MESSAGES, buildPartialLoadMessage } from './lib/mvc/controller/messages'
  import {
    getDuelChallengeBlocker,
    getModeChoiceBlocker,
    getProfileSaveBlocker,
    getSendMessageBlocker,
    getSignInBlocker,
    getSignUpBlocker,
  } from './lib/mvc/controller/interactionPolicies'
  import {
    getCurrentMatch,
    getGuessSubmissionBlocker,
    getSecretSubmissionBlocker,
  } from './lib/mvc/controller/gameController'
  import {
    buildCommunicationPatch,
    buildHydrationPatch,
    buildSessionEndedPatch,
    buildSignedOutPatch,
    buildThreadMessagesPatch,
    buildTimelineErrorPatch,
    buildTimelinePatch,
  } from './lib/mvc/controller/statePatches'
  import {
    acceptInvitationMatch,
    createDuelInvitation,
    manageMatchLifecycle,
    openMatchWithAutoAccept,
    saveUserProfileHandle,
    sendChatMessage,
    signInUser,
    signOutUser,
    signUpUser,
    startModeMatch,
    setMatchSecretCode,
    submitDuelGuessRow,
    submitMatchGuessRow,
  } from './lib/mvc/controller/useCases'
  import { createAppStateStore, emptyAsyncRow } from './lib/mvc/controller/appState'
  import type { AppState } from './lib/mvc/controller/appState'

  const appState = createAppStateStore()

  function patchState(payload: Partial<AppState>) {
    appState.update((state) => ({ ...state, ...payload }))
  }

  function setToast(message: string) {
    patchState({ toast: message })
  }

  function resolveAsyncOutcome(state: AppState, currentMatch: ActiveMatchCard | undefined): 'win' | 'loss' | 'draw' | null {
    if (!currentMatch || currentMatch.state !== 'completed') return null

    const myWin =
      currentMatch.queueType === 'duel'
        ? state.myDuelGuesses.some((guess) => guess.isWin)
        : state.guessHistory.some((guess) => guess.isWin)

    if (myWin) return 'win'

    if (currentMatch.queueType === 'duel' && state.opponentDuelGuesses.some((guess) => guess.isWin)) {
      return 'loss'
    }

    return 'draw'
  }

  async function replayCurrentMode() {
    const state = get(appState)
    const currentMatch = getCurrentMatch(state)
    if (!currentMatch) {
      setToast(APP_MESSAGES.matchRequired)
      goTo('modes')
      return
    }

    const mode = state.modeCards.find((card) => card.modeId === currentMatch.modeId)
    if (!mode) {
      setToast('Mode introuvable. Retour aux modes.')
      goTo('modes', { preserveToast: true })
      return
    }

    await chooseMode(mode)
  }

  onMount(() => {
    hydrateApp()

    if (!supabase) return

    const refreshTimer = setInterval(() => {
      const state = get(appState)
      if (state.currentUser) {
        hydrateApp(state.currentMatchId)

        if (state.currentView === 'communication') {
          void loadCommunication()
        }
      }
    }, 12000)

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (_event, session) => {
      patchState({ currentUser: session?.user ?? null })

      if (!session?.user) {
        patchState(buildSessionEndedPatch(get(appState).currentView))

        return
      }

      await hydrateApp()
    })

    return () => {
      clearInterval(refreshTimer)
      subscription.unsubscribe()
    }
  })

  async function loadMatchHistory(matchId: string | null) {
    try {
      const state = get(appState)
      const currentMatch = state.activeMatches.find((match) => match.id === matchId)
      const isDuelMatch = currentMatch?.queueType === 'duel'
      const timeline = await fetchMatchTimelineData({
        matchId,
        currentUser: state.currentUser,
        isDuelMatch,
      })
      patchState(buildTimelinePatch(timeline))
    } catch (error) {
      patchState(buildTimelineErrorPatch(getErrorMessage(error, APP_MESSAGES.timelineLoadError)))
    }
  }

  async function hydrateApp(preferredMatchId: string | null = null) {
    if (!hasSupabaseConfig) {
      patchState({
        isLoading: false,
        toast: APP_MESSAGES.missingConfig,
      })
      return
    }

    try {
      patchState({ isLoading: true })

      const state = get(appState)

      const hydration = await fetchHydrationData({
        preferredMatchId,
        selectedOpponentId: state.selectedOpponentId,
        selectedChatUserId: state.selectedChatUserId,
      })

      patchState(buildHydrationPatch(hydration))

      await loadMatchHistory(hydration.currentMatchId)

      const nextState = get(appState)
      if (nextState.currentUser && nextState.currentView === 'communication') {
        await loadCommunication()
      }

      if (hydration.loadErrors.length > 0) {
        patchState({
          toast: buildPartialLoadMessage(hydration.loadErrors),
        })
      } else if (nextState.toast.startsWith('Chargement partiel')) {
        patchState({ toast: '' })
      }
    } catch (error) {
      patchState({ toast: getErrorMessage(error, APP_MESSAGES.hydrateLoadError) })
    } finally {
      patchState({ isLoading: false })
    }
  }

  function goTo(view: View, options?: { preserveToast?: boolean }) {
    const state = get(appState)
    const blocker = getNavigationBlocker(view, state.currentUser, state.currentMatchId)

    if (blocker === 'auth_required') {
      patchState({
        toast: APP_MESSAGES.authRequiredForArea,
        currentView: 'auth',
      })
      return
    }

    if (blocker === 'match_required') {
      patchState({
        toast: APP_MESSAGES.matchRequired,
        currentView: 'modes',
      })
      return
    }

    patchState({ currentView: view, toast: options?.preserveToast ? state.toast : '' })

    if (view === 'communication') {
      void loadCommunication()
    }
  }

  async function loadCommunication(threadOnly = false) {
    try {
      patchState({ communicationLoading: true })
      const state = get(appState)
      const communication = await fetchCommunicationData(state.selectedChatUserId, state.currentUser)
      if (threadOnly) {
        patchState(buildThreadMessagesPatch(communication))
      } else {
        patchState(buildCommunicationPatch(communication))
      }
    } catch (error) {
      patchState({
        toast: getErrorMessage(error, threadOnly ? APP_MESSAGES.chatLoadError : APP_MESSAGES.communicationLoadError),
      })
    } finally {
      patchState({ communicationLoading: false })
    }
  }

  async function acceptInvitation(invite: DuelInvitation) {
    try {
      await acceptInvitationMatch(invite.match_id)
      patchState({ currentMatchId: invite.match_id })
      await hydrateApp(invite.match_id)
      await loadCommunication()
      setToast(APP_MESSAGES.inviteAccepted)
      goTo('async', { preserveToast: true })
    } catch (error) {
      patchState({ toast: getErrorMessage(error, APP_MESSAGES.inviteAcceptError) })
    }
  }

  async function refreshChatThread() {
    await loadCommunication(true)
  }

  async function sendMessageToPlayer() {
    const state = get(appState)
    const blocker = getSendMessageBlocker(state)
    if (blocker === 'noop') return
    if (blocker) {
      setToast(blocker)
      return
    }

    try {
      patchState({ sendingMessage: true })
      await sendChatMessage({ recipientUserId: state.selectedChatUserId, body: state.chatInput })
      patchState({ chatInput: '' })
      await refreshChatThread()
    } catch (error) {
      patchState({ toast: getErrorMessage(error, APP_MESSAGES.chatSendError) })
    } finally {
      patchState({ sendingMessage: false })
    }
  }

  async function handleSignUp() {
    const state = get(appState)
    const blocker = getSignUpBlocker(state)
    if (blocker) {
      setToast(blocker)
      return
    }

    try {
      patchState({ authLoading: true })
      await signUpUser({
        email: state.authEmail.trim(),
        password: state.authPassword,
        handle: state.authHandle,
      })
      setToast(APP_MESSAGES.signUpSuccess)
      await hydrateApp()
      if (get(appState).currentUser) goTo('lobby')
    } catch (error) {
      patchState({ toast: getErrorMessage(error, APP_MESSAGES.signUpError) })
    } finally {
      patchState({ authLoading: false })
    }
  }

  async function handleSignIn() {
    const state = get(appState)
    const blocker = getSignInBlocker(state)
    if (blocker) {
      setToast(blocker)
      return
    }

    try {
      patchState({ authLoading: true })
      await signInUser({
        email: state.authEmail.trim(),
        password: state.authPassword,
      })
      await hydrateApp()
      goTo('lobby')
    } catch (error) {
      patchState({ toast: getErrorMessage(error, APP_MESSAGES.signInError) })
    } finally {
      patchState({ authLoading: false })
    }
  }

  async function handleSignOut() {
    if (get(appState).signOutLoading) return

    try {
      patchState({
        signOutLoading: true,
        toast: APP_MESSAGES.signOutInProgress,
      })
      await signOutUser()
      setToast(APP_MESSAGES.signOutSuccess)
    } catch (error) {
      patchState({ toast: getErrorMessage(error, APP_MESSAGES.signOutError) })
    } finally {
      patchState(buildSignedOutPatch())
      goTo('auth', { preserveToast: true })
      patchState({ signOutLoading: false })
    }
  }

  async function saveProfile() {
    const state = get(appState)
    if (!state.currentUser) {
      goTo('auth')
      return
    }

    const nextHandle = normalizeHandleInput(state.profileHandle)
    const blocker = getProfileSaveBlocker({
      currentUser: state.currentUser,
      normalizedHandle: nextHandle,
      currentHandle: state.myProfile?.handle ?? '',
    })
    if (blocker) {
      setToast(blocker)
      return
    }

    try {
      patchState({
        profileSaving: true,
        toast: APP_MESSAGES.profileSaving,
      })
      const updated = await saveUserProfileHandle(nextHandle)
      patchState({
        myProfile: updated,
        profileHandle: updated?.handle ?? nextHandle,
      })
      setToast(APP_MESSAGES.profileSaved)
      await hydrateApp()
    } catch (error) {
      patchState({ toast: getErrorMessage(error, APP_MESSAGES.profileSaveError) })
    } finally {
      patchState({ profileSaving: false })
    }
  }

  async function chooseMode(card: ModeCard) {
    const blocker = getModeChoiceBlocker(get(appState).currentUser)
    if (blocker) {
      setToast(blocker)
      goTo('auth')
      return
    }

    if (!card?.modeId) return

    try {
      const match = await startModeMatch(card)

      patchState({ currentMatchId: match.id })
      await hydrateApp(match.id)

      if (match.isDuel && match.state === 'waiting_opponent') {
        setToast(APP_MESSAGES.duelCreatedWaiting)
        goTo(card.route ?? 'async', { preserveToast: true })
        return
      }

      goTo(card.route ?? 'async')
    } catch (error) {
      patchState({ toast: getErrorMessage(error, APP_MESSAGES.modeCreateError) })
    }
  }

  async function createDuelChallenge(card: ModeCard) {
    const state = get(appState)
    const blocker = getDuelChallengeBlocker(state)
    if (blocker === 'noop') return
    if (blocker) {
      setToast(blocker)
      if (blocker === APP_MESSAGES.modeAuthRequired) goTo('auth')
      return
    }

    try {
      patchState({ duelLoading: true })
      const match = await createDuelInvitation({
        modeId: card.modeId,
        opponentId: state.selectedOpponentId,
      })

      patchState({ currentMatchId: match.id })
      await hydrateApp(match.id)
      setToast(APP_MESSAGES.duelInviteSent)
      goTo('async')
    } catch (error) {
      patchState({ toast: getErrorMessage(error, APP_MESSAGES.duelInviteError) })
    } finally {
      patchState({ duelLoading: false })
    }
  }

  async function openOrAcceptMatch(match: ActiveMatchCard) {
    try {
      const result = await openMatchWithAutoAccept({
        match,
        currentUserId: get(appState).currentUser?.id,
      })
      patchState({ currentMatchId: result.id })
      await hydrateApp(result.id)
      goTo('async')
    } catch (error) {
      patchState({ toast: getErrorMessage(error, APP_MESSAGES.matchOpenError) })
    }
  }

  function canCancelMatch(match: ActiveMatchCard): boolean {
    return policyCanCancelMatch(match, get(appState).currentUser)
  }

  function canDeleteMatch(match: ActiveMatchCard): boolean {
    return policyCanDeleteMatch(match, get(appState).currentUser)
  }

  async function manageMatch(match: ActiveMatchCard, action: 'cancel' | 'delete') {
    if (get(appState).managingMatchId) return

    try {
      patchState({ managingMatchId: match.id })

      const result = await manageMatchLifecycle({ matchId: match.id, action })
      const state = get(appState)
      if (action === 'delete' && state.currentMatchId === match.id) {
        patchState({
          currentMatchId: null,
          guessHistory: [],
        })
      }
      patchState({ toast: result.message })

      await hydrateApp(get(appState).currentMatchId)
    } catch (error) {
      patchState({ toast: getErrorMessage(error, APP_MESSAGES.matchManageError) })
    } finally {
      patchState({ managingMatchId: null })
    }
  }

  function placeAsyncPeg(peg: PalettePeg) {
    const state = get(appState)
    const next = placePegInRow(state.asyncRow, state.asyncSlot, peg)
    patchState({
      asyncRow: next.row,
      asyncSlot: next.nextSlot,
    })
  }

  function setAsyncSlot(index: number) {
    patchState({ asyncSlot: index })
  }

  function placeSecretPeg(peg: PalettePeg) {
    const state = get(appState)
    if (state.mySecretReady) return

    const next = placePegInRow(state.secretRow, state.secretSlot, peg)
    patchState({
      secretRow: next.row,
      secretSlot: next.nextSlot,
    })
  }

  function setSecretSlot(index: number) {
    patchState({ secretSlot: index })
  }

  async function submitSecretRow() {
    const state = get(appState)
    const currentMatch = getCurrentMatch(state)
    const blocker = getSecretSubmissionBlocker(state, currentMatch)
    if (blocker === 'noop') return
    if (blocker) {
      patchState({ toast: blocker })
      return
    }

    const matchId = state.currentMatchId
    if (!matchId) return

    try {
      patchState({ isSubmittingSecret: true })
      await setMatchSecretCode({ matchId, row: state.secretRow })
      patchState({
        mySecretReady: true,
        toast: APP_MESSAGES.secretLocked,
      })
      await loadMatchHistory(matchId)
    } catch (error) {
      patchState({ toast: getErrorMessage(error, APP_MESSAGES.secretLockError) })
    } finally {
      patchState({ isSubmittingSecret: false })
    }
  }

  async function submitAsyncRow() {
    const state = get(appState)
    if (state.isSubmittingGuess) return

    const currentMatch = getCurrentMatch(state)
    const blocker = getGuessSubmissionBlocker(state, currentMatch)
    if (blocker) {
      patchState({ toast: blocker })
      if (blocker === APP_MESSAGES.modeAuthRequired || blocker === 'Connecte-toi pour jouer.') goTo('auth')
      return
    }

    try {
      patchState({ isSubmittingGuess: true })
      if (currentMatch?.queueType === 'duel') {
        await submitDuelGuessRow({ matchId: state.currentMatchId as string, row: state.asyncRow })
      } else {
        await submitMatchGuessRow({ matchId: state.currentMatchId as string, row: state.asyncRow })
      }

      patchState({
        asyncRow: emptyAsyncRow(),
        asyncSlot: 0,
        toast: '',
      })
      await hydrateApp(get(appState).currentMatchId)
    } catch (error) {
      patchState({ toast: getErrorMessage(error, APP_MESSAGES.submitError) })
    } finally {
      patchState({ isSubmittingGuess: false })
    }
  }

  function setSelectedOpponentId(opponentId: string) {
    patchState({ selectedOpponentId: opponentId })
  }

  function setSelectedChatUserId(userId: string) {
    patchState({ selectedChatUserId: userId })
  }

  function setChatInput(value: string) {
    patchState({ chatInput: value })
  }

  function setAuthEmail(value: string) {
    patchState({ authEmail: value })
  }

  function setAuthPassword(value: string) {
    patchState({ authPassword: value })
  }

  function setAuthHandle(value: string) {
    patchState({ authHandle: value })
  }

  function setProfileHandle(value: string) {
    patchState({ profileHandle: value })
  }

</script>

<svelte:head>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
  <link
    href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;700;800&family=JetBrains+Mono:wght@400;500&family=Material+Symbols+Outlined:wght,FILL@200..700,0..1&display=swap"
    rel="stylesheet"
  />
</svelte:head>

<div class="hud-app">
  <div class="scanner-line"></div>
  <TopBar
    currentView={$appState.currentView}
    currentUser={$appState.currentUser}
    myProfile={$appState.myProfile}
    coins={$appState.coins}
    signOutLoading={$appState.signOutLoading}
    onGoProfile={() => goTo('profile')}
    onGoAuth={() => goTo('auth')}
    onSignOut={handleSignOut}
  />

  <main class="screen grid-layer">
    {#if $appState.currentView === 'lobby'}
      <LobbyPanel
        isLoading={$appState.isLoading}
        activeMatches={$appState.activeMatches}
        dailyChallenge={$appState.dailyChallenge}
        currentUser={$appState.currentUser}
        managingMatchId={$appState.managingMatchId}
        {canCancelMatch}
        {canDeleteMatch}
        onOpenMatch={openOrAcceptMatch}
        onManageMatch={manageMatch}
        onGoToModes={() => goTo('modes')}
      />
    {/if}

    {#if $appState.currentView === 'modes'}
      <ModesPanel
        isLoading={$appState.isLoading}
        modeCards={$appState.modeCards}
        opponentCandidates={$appState.opponentCandidates}
        selectedOpponentId={$appState.selectedOpponentId}
        duelLoading={$appState.duelLoading}
        onSelectOpponent={setSelectedOpponentId}
        onCreateDuelChallenge={createDuelChallenge}
        onChooseMode={chooseMode}
      />
    {/if}

    {#if $appState.currentView === 'async'}
      {@const currentAsyncMatch = $appState.activeMatches.find((match) => match.id === $appState.currentMatchId)}
      <AsyncPanel
        isDuelMatch={currentAsyncMatch?.queueType === 'duel'}
        matchState={currentAsyncMatch?.state ?? null}
        matchOutcome={resolveAsyncOutcome($appState, currentAsyncMatch)}
        asyncAttempt={$appState.asyncAttempt}
        guessHistory={$appState.guessHistory}
        asyncRow={$appState.asyncRow}
        asyncSlot={$appState.asyncSlot}
        {asyncPalette}
        mySecretReady={$appState.mySecretReady}
        opponentSecretReady={$appState.opponentSecretReady}
        secretRow={$appState.secretRow}
        secretSlot={$appState.secretSlot}
        isSubmittingSecret={$appState.isSubmittingSecret}
        myDuelGuesses={$appState.myDuelGuesses}
        opponentDuelGuesses={$appState.opponentDuelGuesses}
        isSubmittingGuess={$appState.isSubmittingGuess}
        onSetSlot={setAsyncSlot}
        onPlacePeg={placeAsyncPeg}
        onSetSecretSlot={setSecretSlot}
        onPlaceSecretPeg={placeSecretPeg}
        onSubmitSecret={submitSecretRow}
        onSubmitRow={submitAsyncRow}
        onReplay={replayCurrentMode}
      />
    {/if}

    {#if $appState.currentView === 'communication'}
      <CommunicationPanel
        communicationLoading={$appState.communicationLoading}
        duelInvitations={$appState.duelInvitations}
        opponentCandidates={$appState.opponentCandidates}
        selectedChatUserId={$appState.selectedChatUserId}
        chatMessages={$appState.chatMessages}
        chatInput={$appState.chatInput}
        onChatInputChange={setChatInput}
        sendingMessage={$appState.sendingMessage}
        currentUser={$appState.currentUser}
        onAcceptInvitation={acceptInvitation}
        onRefreshChatThread={refreshChatThread}
        onSendMessage={sendMessageToPlayer}
        onSelectChatUser={setSelectedChatUserId}
      />
    {/if}

    {#if $appState.currentView === 'auth'}
      <AuthPanel
        authEmail={$appState.authEmail}
        authPassword={$appState.authPassword}
        authHandle={$appState.authHandle}
        authLoading={$appState.authLoading}
        onAuthEmailChange={setAuthEmail}
        onAuthPasswordChange={setAuthPassword}
        onAuthHandleChange={setAuthHandle}
        onSignIn={handleSignIn}
        onSignUp={handleSignUp}
      />
    {/if}

    {#if $appState.currentView === 'profile'}
      <ProfilePanel
        currentUser={$appState.currentUser}
        profileHandle={$appState.profileHandle}
        profileSaving={$appState.profileSaving}
        onProfileHandleChange={setProfileHandle}
        onSaveProfile={saveProfile}
        onGoAuth={() => goTo('auth')}
        onGoLobby={() => goTo('lobby')}
      />
    {/if}

    {#if $appState.toast}
      <p class="toast">{$appState.toast}</p>
    {/if}
  </main>

  <BottomNav currentView={$appState.currentView} currentUser={$appState.currentUser} onGoTo={goTo} />
</div>
