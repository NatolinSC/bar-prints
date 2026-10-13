-- Bar Prints: database schema for Supabase.
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.

-- Who may use the till. Only emails listed here can read or change anything,
-- even if someone manages to create an account.
create table public.staff (
  email text primary key,
  role  text not null check (role in ('bar', 'admin'))
);

create table public.members (
  id     text primary key default gen_random_uuid()::text,
  name   text not null check (char_length(name) between 1 and 60),
  nat    text check (nat is null or char_length(nat) <= 40),
  active boolean not null default true,
  ex     boolean not null default false,
  ts     bigint not null default (extract(epoch from now()) * 1000)::bigint
);

-- Every operation is kept: mistakes are fixed with a 'void' row, never by editing.
create table public.ops (
  id text primary key default gen_random_uuid()::text,
  m  text not null references public.members (id) on delete cascade,
  k  text not null check (k in ('topup', 'drink', 'adjust', 'void')),
  p  numeric(10, 2) not null,
  q  integer,
  it jsonb,
  e  numeric(10, 2),
  n  text check (n is null or char_length(n) <= 80),
  v  text,
  ts bigint not null default (extract(epoch from now()) * 1000)::bigint,
  created_by uuid default auth.uid()
);
create index ops_m_idx on public.ops (m);

create table public.config (
  id   text primary key check (id = 'main'),
  data jsonb not null
);

-- Role of the signed-in user, or null when their email is not on the staff list.
create function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.staff where lower(email) = lower(auth.jwt() ->> 'email')
$$;
revoke execute on function public.my_role() from public, anon;
grant execute on function public.my_role() to authenticated;

alter table public.staff   enable row level security;
alter table public.members enable row level security;
alter table public.ops     enable row level security;
alter table public.config  enable row level security;

-- staff: no policies, so the page can only reach it through my_role().

create policy members_read   on public.members for select to authenticated using (public.my_role() is not null);
create policy members_add    on public.members for insert to authenticated with check (public.my_role() is not null);
create policy members_edit   on public.members for update to authenticated using (public.my_role() is not null) with check (public.my_role() is not null);
create policy members_delete on public.members for delete to authenticated using (public.my_role() = 'admin');

-- The bar account may only change a student's nationality; renaming and (de)activating are admin-only.
create function public.members_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(public.my_role(), '') <> 'admin'
     and (new.name is distinct from old.name or new.active is distinct from old.active or new.ex is distinct from old.ex) then
    raise exception 'Only the admin account can rename or deactivate a student' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger members_guard before update on public.members for each row execute function public.members_guard();

create policy ops_read   on public.ops for select to authenticated using (public.my_role() is not null);
-- The bar account may only record drinks (always a debit) and void a drink it can see;
-- top-ups, corrections and other voids are admin-only.
create policy ops_add on public.ops for insert to authenticated with check (
  public.my_role() = 'admin'
  or (public.my_role() = 'bar' and (
       (k = 'drink' and p < 0)
    or (k = 'void' and exists (select 1 from public.ops o where o.id = ops.v and o.k = 'drink' and o.m = ops.m and o.p = -ops.p))
  ))
);
create policy ops_delete on public.ops for delete to authenticated using (public.my_role() = 'admin');

create policy config_read  on public.config for select to authenticated using (public.my_role() is not null);
create policy config_add   on public.config for insert to authenticated with check (public.my_role() = 'admin');
create policy config_edit  on public.config for update to authenticated using (public.my_role() = 'admin') with check (public.my_role() = 'admin');

-- Live updates between the phones behind the bar.
alter publication supabase_realtime add table public.members, public.ops, public.config;
