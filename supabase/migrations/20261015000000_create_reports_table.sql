-- Store app issue and circle reports so the Sprout CMS can review them.
-- Apply only after review/approval; do not run against production automatically.

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  report_type text not null check (report_type in ('issue', 'circle')),
  reporter_id uuid references public.profiles(id) on delete set null,
  subject text not null,
  message text not null,
  circle_id uuid references public.circles(id) on delete set null,
  circle_name text,
  status text not null default 'new'
    check (status in ('new', 'in_review', 'resolved', 'dismissed')),
  email_notification_status text not null default 'pending'
    check (email_notification_status in ('pending', 'sent', 'failed', 'not_configured')),
  email_sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reports_circle_fields_check check (
    (report_type = 'circle' and circle_id is not null)
    or (report_type = 'issue' and circle_id is null)
  )
);

create index if not exists reports_created_at_idx
  on public.reports (created_at desc);
create index if not exists reports_status_created_at_idx
  on public.reports (status, created_at desc);
create index if not exists reports_reporter_id_idx
  on public.reports (reporter_id);
create index if not exists reports_circle_id_idx
  on public.reports (circle_id);

alter table public.reports enable row level security;

-- Reports are accessed only by authenticated Edge Functions using the service role
-- and by the server-authorized Sprout CMS. Do not expose report content to app users.
revoke all on table public.reports from anon, authenticated;
grant all on table public.reports to service_role;
