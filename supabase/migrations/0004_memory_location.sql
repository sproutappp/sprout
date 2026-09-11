-- Optional human-readable location captured during memory creation.
alter table memories add column if not exists location text;
notify pgrst, 'reload schema';
