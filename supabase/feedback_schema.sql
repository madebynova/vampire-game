-- ============================================================================================
-- Vampire Game - player feedback database (Supabase / Postgres)
--
-- HOW TO USE: Supabase dashboard -> SQL Editor -> New query -> paste this whole file -> Run.
-- It is safe to run again later (it only creates what is missing / refreshes policies).
-- Full walkthrough: docs/FEEDBACK_BACKEND.md
--
-- SECURITY MODEL (read this once):
--   * The website only ever uses the project's PUBLIC "anon" key. That key is visible to anyone who
--     views the page source, so everything below assumes the whole internet holds it.
--   * Row Level Security (RLS) is ON. The public may:   INSERT a new report   and   SELECT visible reports.
--   * The public may NOT: update, delete, set a status, un-hide a hidden report, or read admin-only columns
--     (admin_notes, attachment_path). That is enforced by RLS policies AND by column-level privileges.
--   * You manage everything from the Supabase dashboard (Table Editor), which uses admin rights and
--     is not subject to these limits. NEVER put the service_role / secret key in this repository or website.
-- ============================================================================================

create table if not exists public.feedback (
  id                 uuid        primary key default gen_random_uuid(),
  type               text        not null check (type in ('bug', 'idea')),
  title              text        not null check (char_length(btrim(title)) between 3 and 120),
  description        text        not null check (char_length(btrim(description)) between 10 and 4000),
  -- bug reports
  context            text        check (context is null or char_length(context) <= 2000),            -- what were you doing?
  reproduction_steps text        check (reproduction_steps is null or char_length(reproduction_steps) <= 3000),
  expected_behavior  text        check (expected_behavior is null or char_length(expected_behavior) <= 2000),
  -- ideas
  idea_benefit       text        check (idea_benefit is null or char_length(idea_benefit) <= 2000),   -- why would this improve the game?
  -- who (nobody has to give a real name)
  submitter_name     text        check (submitter_name is null or char_length(btrim(submitter_name)) between 1 and 40),
  anonymous          boolean     not null default true,
  -- optional screenshot/video, stored in the private 'feedback-attachments' bucket (admin-only)
  attachment_path    text        check (attachment_path is null or attachment_path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]{1,100}$'),
  -- managed by YOU in the dashboard
  status             text        not null default 'new'
                                 check (status in ('new', 'investigating', 'planned', 'in_progress', 'fixed', 'closed')),
  visible            boolean     not null default true,   -- untick to hide a report from the public list.
                                                         -- Want to approve reports BEFORE they appear? change this default to false.
  admin_notes        text,                                 -- private; never exposed to the public API
  created_at         timestamptz not null default now(),
  -- an anonymous report must not carry a name; a named report must say so
  constraint feedback_anonymous_has_no_name check (not (anonymous and submitter_name is not null))
);

create index if not exists feedback_public_list_idx on public.feedback (type, created_at desc) where visible;

alter table public.feedback enable row level security;

-- Start from nothing, then grant back only what the public site needs (column by column).
revoke all on public.feedback from anon, authenticated;

-- Public may read these columns only (never admin_notes / attachment_path):
grant select (id, type, title, description, context, reproduction_steps, expected_behavior, idea_benefit,
              submitter_name, anonymous, status, visible, created_at)
  on public.feedback to anon, authenticated;

-- Public may write these columns only. status / visible / admin_notes cannot be set by the public:
-- they always take the defaults above.
grant insert (type, title, description, context, reproduction_steps, expected_behavior, idea_benefit,
              submitter_name, anonymous, attachment_path)
  on public.feedback to anon, authenticated;

-- (No UPDATE or DELETE privilege and no UPDATE/DELETE policy exist for the public, so both are impossible.)

drop policy if exists "public can read visible feedback" on public.feedback;
create policy "public can read visible feedback"
  on public.feedback for select to anon, authenticated
  using (visible);

drop policy if exists "public can submit feedback" on public.feedback;
create policy "public can submit feedback"
  on public.feedback for insert to anon, authenticated
  with check (status = 'new');

-- ----------------------------------------------------------------------------------------------
-- Optional screenshot/video uploads: a PRIVATE bucket the public can write to but not read or list.
-- You view uploads in the dashboard (Storage -> feedback-attachments); attachment_path says which file.
-- ----------------------------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('feedback-attachments', 'feedback-attachments', false, 10485760,
        array['image/png', 'image/jpeg', 'image/gif', 'image/webp', 'video/mp4', 'video/webm'])
on conflict (id) do update
  set public = false, file_size_limit = 10485760,
      allowed_mime_types = array['image/png', 'image/jpeg', 'image/gif', 'image/webp', 'video/mp4', 'video/webm'];

drop policy if exists "public can upload feedback attachments" on storage.objects;
create policy "public can upload feedback attachments"
  on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'feedback-attachments'
              and (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$');
-- No select / update / delete policy on storage.objects for the public: uploads are write-only.
