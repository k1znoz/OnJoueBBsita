<script lang="ts">
  import type { User } from '@supabase/supabase-js'
  import type { DuelInvitation, OpponentCandidate, PlayerMessage } from '../../model/types'

  export let communicationLoading = false
  export let duelInvitations: DuelInvitation[] = []
  export let opponentCandidates: OpponentCandidate[] = []
  export let selectedChatUserId = ''
  export let chatMessages: PlayerMessage[] = []
  export let chatInput = ''
  export let onChatInputChange: (value: string) => void
  export let sendingMessage = false
  export let currentUser: User | null = null
  export let onAcceptInvitation: (invite: DuelInvitation) => void
  export let onRefreshChatThread: () => void
  export let onSendMessage: () => void
  export let onSelectChatUser: (userId: string) => void
</script>

<section class="section-head intro">
  <h3>Communication</h3>
  <p>Invitations duel et messages entre joueurs.</p>
</section>

<section class="account-panel glass-panel">
  <h4>Invitations recues</h4>
  {#if communicationLoading}
    <article class="empty-state">Chargement...</article>
  {:else if duelInvitations.length === 0}
    <article class="empty-state">Aucune invitation en attente.</article>
  {:else}
    <div class="stack">
      {#each duelInvitations as invite}
        <article class="match-card glass-panel">
          <div class="match-head">
            <div>
              <h4>{invite.mode_title}</h4>
              <p>Invite par {invite.inviter_handle}</p>
            </div>
            <span class="status-chip status-wait">Invitation</span>
          </div>
          <button type="button" class="btn btn-primary" on:click={() => onAcceptInvitation(invite)}>
            Accepter
          </button>
        </article>
      {/each}
    </div>
  {/if}
</section>

<section class="account-panel glass-panel">
  <h4>Messages prives</h4>
  <div class="duel-controls">
    <label class="field-label" for="chat-user">Joueur</label>
    <select
      id="chat-user"
      class="input-field"
      value={selectedChatUserId}
      on:change={(event) => {
        onSelectChatUser((event.currentTarget as HTMLSelectElement).value)
        onRefreshChatThread()
      }}
    >
      {#if opponentCandidates.length === 0}
        <option value="">Aucun joueur disponible</option>
      {:else}
        {#each opponentCandidates as opponent}
          <option value={opponent.id}>{opponent.handle}</option>
        {/each}
      {/if}
    </select>
  </div>

  <div class="chat-thread glass-panel">
    {#if chatMessages.length === 0}
      <article class="empty-state">Aucun message.</article>
    {:else}
      {#each chatMessages as message}
        <article class={`chat-message ${currentUser && message.sender_user_id === currentUser.id ? 'chat-own' : 'chat-peer'}`}>
          <p>{message.body}</p>
          <small>{new Date(message.created_at).toLocaleString('fr-FR')}</small>
        </article>
      {/each}
    {/if}
  </div>

  <div class="duel-controls">
    <label class="field-label" for="chat-input">Message</label>
    <textarea
      id="chat-input"
      class="input-field chat-input"
      rows="3"
      value={chatInput}
      on:input={(event) => onChatInputChange((event.currentTarget as HTMLTextAreaElement).value)}
      placeholder="Ecris ton message..."
    ></textarea>
    <button type="button" class="btn btn-primary" disabled={sendingMessage} on:click={onSendMessage}>
      {sendingMessage ? 'Envoi...' : 'Envoyer'}
    </button>
  </div>
</section>
