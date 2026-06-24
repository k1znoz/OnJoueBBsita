<script lang="ts">
  import type { User } from '@supabase/supabase-js'

  export let currentUser: User | null = null
  export let profileHandle = ''
  export let profileSaving = false
  export let onProfileHandleChange: (value: string) => void
  export let onSaveProfile: () => void
  export let onGoAuth: () => void
  export let onGoLobby: () => void
</script>

<section class="account-panel glass-panel">
  <h3>Mon profil</h3>
  <p class="account-subtitle">Consulter et modifier les informations de compte.</p>

  {#if !currentUser}
    <article class="empty-state">Aucune session utilisateur.</article>
    <div class="account-actions">
      <button type="button" class="btn btn-primary" on:click={onGoAuth}>Se connecter</button>
    </div>
  {:else}
    <div class="profile-grid">
      <div>
        <div class="field-label">User ID</div>
        <div class="readonly-value">{currentUser.id}</div>
      </div>
      <div>
        <div class="field-label">Email</div>
        <div class="readonly-value">{currentUser.email ?? 'N/A'}</div>
      </div>
    </div>

    <div class="form-grid">
      <label class="field-label" for="profile-handle">Pseudo</label>
      <input
        id="profile-handle"
        class="input-field"
        type="text"
        value={profileHandle}
        on:input={(event) => onProfileHandleChange((event.currentTarget as HTMLInputElement).value)}
        placeholder="Pseudo joueur"
      />
    </div>

    <div class="account-actions">
      <button type="button" class="btn btn-primary" disabled={profileSaving} on:click={onSaveProfile}>
        {profileSaving ? 'Enregistrement...' : 'Enregistrer'}
      </button>
      <button type="button" class="btn btn-ghost" on:click={onGoLobby}>Retour lobby</button>
    </div>
  {/if}
</section>
