-- OAuth secrets and one-time authorization state are server-only. They are
-- deliberately separated from client-readable integration metadata.

create table public.provider_credentials (
  integration_id uuid primary key references public.integrations(id) on delete cascade,
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  provider text not null,
  access_token text not null check (length(access_token) >= 16),
  token_type text not null default 'Bearer',
  scopes text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (athlete_id, provider)
);

comment on table public.provider_credentials is
  'Server-only provider credentials. No client role has table privileges or an RLS policy.';

create table public.oauth_authorization_states (
  state_hash text primary key,
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  provider text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index oauth_authorization_states_expiry
  on public.oauth_authorization_states (expires_at);

alter table public.provider_credentials enable row level security;
alter table public.oauth_authorization_states enable row level security;

revoke all on public.provider_credentials from anon, authenticated;
revoke all on public.oauth_authorization_states from anon, authenticated;
grant all on public.provider_credentials to service_role;
grant all on public.oauth_authorization_states to service_role;

create trigger provider_credentials_set_updated_at
before update on public.provider_credentials
for each row execute function public.set_updated_at();
