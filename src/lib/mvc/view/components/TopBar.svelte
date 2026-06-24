<script lang="ts">
  import type { User } from '@supabase/supabase-js'
  import type { UserProfile, View } from '../../model/types'
  import { viewTitle } from '../../model/constants'

  export let currentView: View
  export let currentUser: User | null = null
  export let myProfile: UserProfile | null = null
  export let coins = 0
  export let signOutLoading = false
  export let onGoProfile: () => void
  export let onGoAuth: () => void
  export let onSignOut: () => void
</script>

<header class="topbar glass-panel">
  <div class="brand">
    <span class="material-symbols-outlined brand-icon">terminal</span>
    <div>
      <p class="caption">SYSTEM</p>
      <h1>{viewTitle[currentView]}</h1>
    </div>
  </div>
  <div class="wallet-panel">
    <span class="material-symbols-outlined">account_balance_wallet</span>
    <strong>{coins.toLocaleString('fr-FR')} CR</strong>
  </div>
  <div class="topbar-actions">
    {#if currentUser}
      <span class="caption">Connecte: {myProfile?.handle ?? currentUser.email}</span>
      <button type="button" class="btn btn-ghost" on:click={onGoProfile}>Mon compte</button>
      <button type="button" class="btn btn-ghost" disabled={signOutLoading} on:click={onSignOut}>
        {signOutLoading ? 'Deconnexion...' : 'Deconnexion'}
      </button>
    {:else}
      <button type="button" class="btn btn-ghost" on:click={onGoAuth}>Connexion</button>
    {/if}
  </div>
</header>
