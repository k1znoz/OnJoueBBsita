-- Mastermind OS - Supabase bootstrap schema
-- Run this in Supabase SQL Editor.

create extension if not exists pgcrypto;

-- Profiles linked to auth.users
create table if not exists public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  handle text unique,
  credits integer not null default 0,
  rank_tier text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Public game modes synced from Sanity/back-office
create table if not exists public.game_modes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  title text not null,
  short_description text,
  is_enabled boolean not null default true,
  sort_order integer not null default 0,
  sanity_doc_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Daily challenge content
create table if not exists public.daily_challenges (
  id uuid primary key default gen_random_uuid(),
  challenge_date date not null unique,
  title text not null,
  description text,
  reward_credits integer not null default 0,
  difficulty text,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Match lifecycle
create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  mode_id uuid not null references public.game_modes(id),
  state text not null check (state in ('draft','waiting_opponent','active','waiting_turn','completed','canceled','expired')),
  created_by_user_id uuid not null references public.user_profiles(id),
  current_turn_user_id uuid references public.user_profiles(id),
  secret_code_hash text,
  create_request_key text,
  max_turns integer not null default 10,
  turn_number integer not null default 1,
  winner_user_id uuid references public.user_profiles(id),
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.match_players (
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  seat smallint not null,
  is_ready boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key (match_id, user_id),
  unique (match_id, seat)
);

create table if not exists public.match_turns (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  turn_index integer not null,
  actor_user_id uuid not null references public.user_profiles(id),
  status text not null default 'open' check (status in ('open','submitted','closed')),
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  unique (match_id, turn_index)
);

create table if not exists public.guesses (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  turn_id uuid not null references public.match_turns(id) on delete cascade,
  actor_user_id uuid not null references public.user_profiles(id),
  payload jsonb not null,
  exact_hits integer not null default 0,
  partial_hits integer not null default 0,
  is_win boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.matches add column if not exists secret_code_hash text;
alter table public.matches add column if not exists create_request_key text;

create table if not exists public.economy_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id),
  match_id uuid references public.matches(id) on delete set null,
  entry_type text not null check (entry_type in ('debit','credit','reward','refund')),
  amount integer not null,
  reason text,
  created_at timestamptz not null default now()
);

create index if not exists idx_matches_creator on public.matches(created_by_user_id);
create index if not exists idx_matches_state on public.matches(state);
create index if not exists idx_match_players_user on public.match_players(user_id);
create index if not exists idx_turns_match on public.match_turns(match_id);
create index if not exists idx_guesses_match on public.guesses(match_id);
create index if not exists idx_ledger_user on public.economy_ledger(user_id);
create unique index if not exists uq_matches_creator_request_key
on public.matches(created_by_user_id, create_request_key);
create unique index if not exists uq_guesses_turn_actor
on public.guesses(turn_id, actor_user_id);

-- Keep updated_at fresh
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_user_profiles_updated_at on public.user_profiles;
create trigger trg_user_profiles_updated_at before update on public.user_profiles
for each row execute function public.touch_updated_at();

drop trigger if exists trg_game_modes_updated_at on public.game_modes;
create trigger trg_game_modes_updated_at before update on public.game_modes
for each row execute function public.touch_updated_at();

drop trigger if exists trg_daily_challenges_updated_at on public.daily_challenges;
create trigger trg_daily_challenges_updated_at before update on public.daily_challenges
for each row execute function public.touch_updated_at();

drop trigger if exists trg_matches_updated_at on public.matches;
create trigger trg_matches_updated_at before update on public.matches
for each row execute function public.touch_updated_at();

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_handle_base text;
  v_candidate text;
  v_suffix integer := 0;
begin
  v_handle_base := nullif(trim(coalesce(new.raw_user_meta_data ->> 'handle', '')), '');
  if v_handle_base is null then
    v_handle_base := 'u_' || substr(replace(new.id::text, '-', ''), 1, 10);
  else
    v_handle_base := regexp_replace(lower(v_handle_base), '[^a-z0-9_]', '', 'g');
    if v_handle_base = '' then
      v_handle_base := 'u_' || substr(replace(new.id::text, '-', ''), 1, 10);
    end if;
  end if;

  loop
    v_candidate := case
      when v_suffix = 0 then v_handle_base
      else v_handle_base || '_' || v_suffix::text
    end;

    exit when not exists (
      select 1
      from public.user_profiles up
      where up.handle = v_candidate
        and up.id <> new.id
    );

    v_suffix := v_suffix + 1;
  end loop;

  insert into public.user_profiles (id, handle)
  values (new.id, v_candidate)
  on conflict (id) do update
  set handle = excluded.handle;

  return new;
end;
$$;

drop trigger if exists trg_auth_user_created on auth.users;
create trigger trg_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Atomic gameplay functions
create or replace function public.create_match(
  p_mode_id uuid,
  p_max_turns integer default 10,
  p_idempotency_key text default null
)
returns public.matches
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_match public.matches;
begin
  v_uid := auth.uid();

  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
    raise exception 'Idempotency key is required';
  end if;

  if not exists (
    select 1 from public.game_modes gm
    where gm.id = p_mode_id and gm.is_enabled = true
  ) then
    raise exception 'Mode unavailable';
  end if;

  insert into public.matches (
    mode_id,
    state,
    created_by_user_id,
    current_turn_user_id,
    secret_code_hash,
    create_request_key,
    max_turns
  )
  values (
    p_mode_id,
    'draft',
    v_uid,
    v_uid,
    encode(gen_random_bytes(16), 'hex'),
    p_idempotency_key,
    greatest(1, coalesce(p_max_turns, 10))
  )
  on conflict (created_by_user_id, create_request_key)
  do update set updated_at = now()
  returning * into v_match;

  insert into public.match_players (match_id, user_id, seat, is_ready)
  values (v_match.id, v_uid, 1, true)
  on conflict (match_id, user_id) do nothing;

  return v_match;
end;
$$;

create or replace function public.submit_guess(
  p_match_id uuid,
  p_payload jsonb
)
returns public.guesses
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_match public.matches;
  v_turn public.match_turns;
  v_guess public.guesses;
  v_next_user_id uuid;
begin
  v_uid := auth.uid();

  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.match_players mp
    where mp.match_id = p_match_id and mp.user_id = v_uid
  ) then
    raise exception 'Not participant of this match';
  end if;

  select * into v_match
  from public.matches m
  where m.id = p_match_id
  for update;

  if v_match.id is null then
    raise exception 'Match not found';
  end if;

  if v_match.state not in ('draft', 'active', 'waiting_turn') then
    raise exception 'Match not writable in current state';
  end if;

  if v_match.current_turn_user_id is distinct from v_uid then
    raise exception 'Not your turn';
  end if;

  select * into v_turn
  from public.match_turns t
  where t.match_id = p_match_id and t.turn_index = v_match.turn_number;

  if v_turn.id is null then
    insert into public.match_turns (match_id, turn_index, actor_user_id, status)
    values (p_match_id, v_match.turn_number, v_uid, 'open')
    returning * into v_turn;
  end if;

  if exists (
    select 1
    from public.guesses g
    where g.turn_id = v_turn.id and g.actor_user_id = v_uid
  ) then
    raise exception 'Guess already submitted for this turn';
  end if;

  insert into public.guesses (
    match_id,
    turn_id,
    actor_user_id,
    payload,
    exact_hits,
    partial_hits,
    is_win
  )
  values (
    p_match_id,
    v_turn.id,
    v_uid,
    coalesce(p_payload, '{}'::jsonb),
    0,
    0,
    false
  )
  returning * into v_guess;

  update public.match_turns
  set status = 'submitted', submitted_at = now()
  where id = v_turn.id;

  select mp.user_id into v_next_user_id
  from public.match_players mp
  where mp.match_id = p_match_id
    and mp.user_id <> v_uid
  order by mp.seat
  limit 1;

  if v_match.turn_number >= v_match.max_turns then
    update public.matches
    set
      state = 'completed',
      ended_at = now(),
      current_turn_user_id = null,
      updated_at = now()
    where id = p_match_id;
  else
    update public.matches
    set
      state = 'waiting_turn',
      turn_number = v_match.turn_number + 1,
      current_turn_user_id = coalesce(v_next_user_id, v_uid),
      updated_at = now()
    where id = p_match_id;
  end if;

  return v_guess;
end;
$$;

revoke execute on function public.create_match(uuid, integer, text) from public;
revoke execute on function public.submit_guess(uuid, jsonb) from public;
grant execute on function public.create_match(uuid, integer, text) to authenticated;
grant execute on function public.submit_guess(uuid, jsonb) to authenticated;

-- Explicit privileges for PostgREST roles.
grant usage on schema public to anon, authenticated;
grant select on public.game_modes to anon, authenticated;
grant select on public.daily_challenges to anon, authenticated;
grant select on public.user_profiles to authenticated;
grant select on public.matches to authenticated;
grant select on public.match_players to authenticated;
grant select on public.match_turns to authenticated;
grant select on public.guesses to authenticated;
grant select on public.economy_ledger to authenticated;
grant insert, update on public.user_profiles to authenticated;

-- RLS
alter table public.user_profiles enable row level security;
alter table public.game_modes enable row level security;
alter table public.daily_challenges enable row level security;
alter table public.matches enable row level security;
alter table public.match_players enable row level security;
alter table public.match_turns enable row level security;
alter table public.guesses enable row level security;
alter table public.economy_ledger enable row level security;

-- Public read for catalog data
drop policy if exists "public read game modes" on public.game_modes;
create policy "public read game modes"
on public.game_modes for select
using (is_enabled = true);

drop policy if exists "public read active daily challenge" on public.daily_challenges;
create policy "public read active daily challenge"
on public.daily_challenges for select
using (is_active = true);

-- Profile access
drop policy if exists "user read own profile" on public.user_profiles;
create policy "user read own profile"
on public.user_profiles for select
using (auth.uid() = id);

drop policy if exists "user insert own profile" on public.user_profiles;
create policy "user insert own profile"
on public.user_profiles for insert
with check (auth.uid() = id);

drop policy if exists "user update own profile" on public.user_profiles;
create policy "user update own profile"
on public.user_profiles for update
using (auth.uid() = id)
with check (auth.uid() = id);

-- Match access: user must be in match_players
drop policy if exists "participants read matches" on public.matches;
create policy "participants read matches"
on public.matches for select
using (
  exists (
    select 1 from public.match_players mp
    where mp.match_id = matches.id and mp.user_id = auth.uid()
  )
);

drop policy if exists "creator insert matches" on public.matches;
create policy "creator insert matches"
on public.matches for insert
with check (false);

drop policy if exists "participants read players" on public.match_players;
create policy "participants read players"
on public.match_players for select
using (
  exists (
    select 1 from public.match_players me
    where me.match_id = match_players.match_id and me.user_id = auth.uid()
  )
);

drop policy if exists "user join self" on public.match_players;
create policy "user join self"
on public.match_players for insert
with check (false);

drop policy if exists "participants read turns" on public.match_turns;
create policy "participants read turns"
on public.match_turns for select
using (
  exists (
    select 1 from public.match_players mp
    where mp.match_id = match_turns.match_id and mp.user_id = auth.uid()
  )
);

drop policy if exists "participants read guesses" on public.guesses;
create policy "participants read guesses"
on public.guesses for select
using (
  exists (
    select 1 from public.match_players mp
    where mp.match_id = guesses.match_id and mp.user_id = auth.uid()
  )
);

drop policy if exists "actor insert guess" on public.guesses;
create policy "actor insert guess"
on public.guesses for insert
with check (false);

drop policy if exists "user read own ledger" on public.economy_ledger;
create policy "user read own ledger"
on public.economy_ledger for select
using (user_id = auth.uid());

-- Bootstrap data: ensure at least one playable mode exists.
insert into public.game_modes (code, title, short_description, is_enabled, sort_order)
values (
  'classic_async',
  'Classic',
  'Mode classique asynchrone, 4 slots, palette standard.',
  true,
  10
)
on conflict (code) do update
set
  title = excluded.title,
  short_description = excluded.short_description,
  is_enabled = true,
  sort_order = excluded.sort_order,
  updated_at = now();
