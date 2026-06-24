<script lang="ts">
  export let authEmail = ''
  export let authPassword = ''
  export let authHandle = ''
  export let authLoading = false
  export let onAuthEmailChange: (value: string) => void
  export let onAuthPasswordChange: (value: string) => void
  export let onAuthHandleChange: (value: string) => void
  export let onSignIn: () => void
  export let onSignUp: () => void
</script>

<section class="account-panel glass-panel">
  <h3>Acces utilisateur</h3>
  <p class="account-subtitle">Creer un compte ou se connecter pour acceder aux parties.</p>

  <div class="form-grid">
    <label class="field-label" for="auth-email">Email</label>
    <input
      id="auth-email"
      class="input-field"
      type="email"
      value={authEmail}
      on:input={(event) => onAuthEmailChange((event.currentTarget as HTMLInputElement).value)}
      placeholder="email@domaine.com"
    />

    <label class="field-label" for="auth-password">Mot de passe</label>
    <input
      id="auth-password"
      class="input-field"
      type="password"
      value={authPassword}
      on:input={(event) => onAuthPasswordChange((event.currentTarget as HTMLInputElement).value)}
      placeholder="Minimum 6 caracteres"
    />

    <label class="field-label" for="auth-handle">Pseudo</label>
    <input
      id="auth-handle"
      class="input-field"
      type="text"
      value={authHandle}
      on:input={(event) => onAuthHandleChange((event.currentTarget as HTMLInputElement).value)}
      placeholder="Pseudo joueur"
    />
  </div>

  <div class="account-actions">
    <button type="button" class="btn btn-primary" disabled={authLoading} on:click={onSignIn}>Connexion</button>
    <button type="button" class="btn btn-ghost" disabled={authLoading} on:click={onSignUp}>Creer un compte</button>
  </div>
</section>
