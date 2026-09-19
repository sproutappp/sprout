-- Allow the creator of a circle to delete it.
-- The existing foreign keys use ON DELETE CASCADE, so deleting the circle
-- also removes its members, memories, reactions, comments, tags and
-- notifications from the database.

create policy "circle creators can delete their circle"
on public.circles
for delete
to authenticated
using (created_by = auth.uid());

notify pgrst, 'reload schema';
