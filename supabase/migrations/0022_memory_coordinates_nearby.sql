-- Store coordinates separately from the human-readable location label so
-- Nearby can sort public memories by actual distance.
alter table public.memories
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

create index if not exists memories_public_coordinates_idx
  on public.memories (is_public, latitude, longitude);

-- Public memories are intentionally discoverable by every signed-in user.
drop policy if exists "authenticated users can view public memories" on public.memories;
create policy "authenticated users can view public memories"
  on public.memories
  for select
  to authenticated
  using (is_public = true);

-- Return only public memories and order them from nearest to farthest.
-- The distance is calculated with the haversine formula, so no PostGIS
-- extension is required.
create or replace function public.fetch_nearby_public_memories(
  p_latitude double precision,
  p_longitude double precision
)
returns table (
  id uuid,
  circle_id uuid,
  uploaded_by uuid,
  image_url text,
  media_urls jsonb,
  title text,
  caption text,
  location text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz,
  is_public boolean
)
language sql
security definer
set search_path = public
stable
as $$
  select
    m.id,
    m.circle_id,
    m.uploaded_by,
    m.image_url,
    m.media_urls,
    m.title,
    m.caption,
    m.location,
    m.latitude,
    m.longitude,
    m.created_at,
    m.is_public
  from public.memories m
  where m.is_public = true
    and m.latitude is not null
    and m.longitude is not null
  order by
    6371.0 * acos(
      least(
        1.0,
        greatest(
          -1.0,
          cos(radians(p_latitude))
          * cos(radians(m.latitude))
          * cos(radians(m.longitude) - radians(p_longitude))
          + sin(radians(p_latitude))
          * sin(radians(m.latitude))
        )
      )
    ) asc,
    m.created_at desc;
$$;

revoke all on function public.fetch_nearby_public_memories(double precision, double precision) from public;
grant execute on function public.fetch_nearby_public_memories(double precision, double precision) to authenticated;

notify pgrst, 'reload schema';
