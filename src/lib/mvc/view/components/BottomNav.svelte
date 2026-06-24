<script lang="ts">
  import type { User } from '@supabase/supabase-js'
  import type { View } from '../../model/types'

  export let currentView: View
  export let currentUser: User | null = null
  export let onGoTo: (view: View) => void
</script>

<nav class="bottom-nav">
  <button type="button" class={currentView === 'lobby' ? 'active' : ''} on:click={() => onGoTo('lobby')}>
    <span class="material-symbols-outlined">videogame_asset</span>
    <span>Lobby</span>
  </button>
  <button type="button" class={currentView === 'modes' ? 'active' : ''} on:click={() => onGoTo('modes')}>
    <span class="material-symbols-outlined">extension</span>
    <span>Modes</span>
  </button>
  <button type="button" class={currentView === 'async' ? 'active' : ''} on:click={() => onGoTo('async')}>
    <span class="material-symbols-outlined">history</span>
    <span>Logs</span>
  </button>
  <button type="button" class={currentView === 'communication' ? 'active' : ''} on:click={() => onGoTo('communication')}>
    <span class="material-symbols-outlined">forum</span>
    <span>Comms</span>
  </button>
  <button
    type="button"
    class={currentView === 'profile' || currentView === 'auth' ? 'active' : ''}
    on:click={() => onGoTo(currentUser ? 'profile' : 'auth')}
  >
    <span class="material-symbols-outlined">person</span>
    <span>Compte</span>
  </button>
</nav>
