-- ONE-TIME DEVELOPMENT CLEAN SLATE
-- Run manually in Supabase SQL Editor when you want to start the
-- current Sprout test account/project from zero.
--
-- This deletes ALL database memories and ALL circles for ALL users.
-- It is intentionally NOT a migration so it cannot run automatically
-- during deployment.
--
-- The memories/circles rows are the source of truth for what appears in
-- Home, Memories, Discover and Circles. Their dependent database rows are
-- removed by the existing foreign-key ON DELETE CASCADE relationships.
-- Storage objects are separate from the database; if you also want to
-- reclaim old photo files, empty the `memories` and `circle-covers` buckets
-- from Supabase Storage after running this script.

begin;

-- Remove memories first. This also cascades memory_circles,
-- memory_people, reactions, comments and memory-linked notifications.
delete from public.memories;

-- Remove every circle. This cascades circle_members, invites and any
-- remaining circle-linked records.
delete from public.circles;

commit;

-- Verify the database is clean:
select
  (select count(*) from public.memories) as memories_remaining,
  (select count(*) from public.circles) as circles_remaining;
