alter table public.integrations
  add column authorization_method text not null default 'api_key'
  check (authorization_method in ('api_key', 'oauth'));

comment on column public.integrations.authorization_method is
  'Non-secret connection mechanism. OAuth bearer tokens remain server-only.';
