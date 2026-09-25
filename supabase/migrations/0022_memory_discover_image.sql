-- Sprout: separate user-selected 16:9 image for Home -> Discover.
-- The original image_url remains the main memory image used by the
-- full Discover experience and memory detail screens.

ALTER TABLE public.memories
  ADD COLUMN IF NOT EXISTS discover_image_url text;

NOTIFY pgrst, 'reload schema';
