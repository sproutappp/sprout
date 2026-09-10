-- Fix: memory_reactions / memory_comments RLS still used the pre-multi-circle
-- is_circle_member(m.circle_id) check, so:
--   * public memories (circle_id is null) could never be reacted to / commented on
--   * memories shared to multiple circles only worked for the original circle_id,
--     not any of the other circles it was also shared to via memory_circles
--
-- This makes both tables use can_view_memory(memory_id) instead, the same
-- visibility function already used by the memories table and storage policies.
-- Safe to run directly against the live database in the Supabase SQL Editor.
-- Idempotent (drop-if-exists + create), can be re-run safely.

drop policy if exists "circle members can view reactions" on memory_reactions;
create policy "anyone who can view the memory can view reactions"
  on memory_reactions for select
  to authenticated
  using (can_view_memory(memory_id));

drop policy if exists "circle members can react" on memory_reactions;
create policy "anyone who can view the memory can react"
  on memory_reactions for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and can_view_memory(memory_id)
  );

drop policy if exists "circle members can view comments" on memory_comments;
create policy "anyone who can view the memory can view comments"
  on memory_comments for select
  to authenticated
  using (can_view_memory(memory_id));

drop policy if exists "circle members can comment" on memory_comments;
create policy "anyone who can view the memory can comment"
  on memory_comments for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and can_view_memory(memory_id)
  );
