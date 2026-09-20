-- Support multiple photos per memory.
-- image_url remains the primary/cover image for backward compatibility.
alter table public.memories
  add column if not exists media_urls jsonb not null default '[]'::jsonb;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'memories_media_urls_is_array'
  ) then
    alter table public.memories
      add constraint memories_media_urls_is_array
      check (jsonb_typeof(media_urls) = 'array');
  end if;
exception when duplicate_object then
  null;
end $$;

notify pgrst, 'reload schema';
