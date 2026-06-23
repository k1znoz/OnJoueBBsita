# Supabase integration

## 1) Project setup

1. Create a Supabase project.
2. Copy `.env.example` to `.env`.
3. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`.
4. Run SQL from `supabase/001_init.sql` in Supabase SQL editor.

## 2) Auth requirement

Most runtime tables are protected by RLS and require authentication.
Catalog tables (`game_modes`, `daily_challenges`) are readable publicly when active/enabled.

## 3) Front usage

Use helpers from `src/lib/supabase/services.ts`.

Example:

```ts
import { fetchActiveGameModes, fetchDailyChallenge } from '$lib/supabase/services'

const modes = await fetchActiveGameModes()
const challenge = await fetchDailyChallenge()
```

## 4) Next steps

1. Add auth flow (email magic link or OAuth).
2. Use RPC functions `create_match` and `submit_guess` from the client services.
3. Add backend webhook to sync Sanity content into `game_modes` and `daily_challenges`.
