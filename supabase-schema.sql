create table if not exists public.party_admins (
    user_id uuid primary key references auth.users (id) on delete cascade,
    created_at timestamptz not null default now()
);

alter table public.party_admins enable row level security;

drop policy if exists "Organizers can read their own access" on public.party_admins;
create policy "Organizers can read their own access"
    on public.party_admins for select
    to authenticated
    using (user_id = (select auth.uid()));

create table if not exists public.announcements (
    id bigint generated always as identity primary key,
    title text not null check (char_length(title) between 1 and 100),
    message text not null check (char_length(message) between 1 and 2000),
    author_id uuid not null references auth.users (id) on delete restrict,
    created_at timestamptz not null default now()
);

alter table public.announcements enable row level security;

grant select on public.announcements to anon, authenticated;
grant insert on public.announcements to authenticated;
grant usage, select on sequence public.announcements_id_seq to authenticated;
grant select on public.party_admins to authenticated;

drop policy if exists "Anyone can read announcements" on public.announcements;
create policy "Anyone can read announcements"
    on public.announcements for select
    to anon, authenticated
    using (true);

drop policy if exists "Organizers can publish announcements" on public.announcements;
create policy "Organizers can publish announcements"
    on public.announcements for insert
    to authenticated
    with check (
        author_id = (select auth.uid())
        and exists (
            select 1
            from public.party_admins
            where party_admins.user_id = (select auth.uid())
        )
    );

do $$
begin
    if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'announcements'
    ) then
        alter publication supabase_realtime add table public.announcements;
    end if;
end
$$;

-- Create an organizer in Supabase Auth, then grant organizer access using that user's UUID:
-- insert into public.party_admins (user_id) values ('YOUR-AUTH-USER-UUID');
