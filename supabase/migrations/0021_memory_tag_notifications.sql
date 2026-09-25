-- Memory tagging notifications and self-tag protection.
-- The creator is never offered as a tag and cannot be tagged through the API.
-- Every selected tagged member receives an in-app notification.

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (
    type IN (
      'circle_memory',
      'circle_join',
      'memory_comment',
      'circle_invite',
      'circle_deleted',
      'memory_tagged'
    )
  );

CREATE OR REPLACE FUNCTION public.memory_person_is_member_of_shared_circle(
  p_memory_id uuid,
  p_person_id uuid
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.memory_circles mc
    JOIN public.circle_members cm
      ON cm.circle_id = mc.circle_id
    WHERE mc.memory_id = p_memory_id
      AND cm.user_id = p_person_id
  );
$$;

REVOKE ALL ON FUNCTION public.memory_person_is_member_of_shared_circle(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.memory_person_is_member_of_shared_circle(uuid, uuid) TO authenticated;

DROP POLICY IF EXISTS "memory owner can add people tags" ON public.memory_people;

CREATE POLICY "memory owner can add people tags"
  ON public.memory_people
  FOR INSERT
  TO authenticated
  WITH CHECK (
    person_id <> (SELECT auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.memories m
      WHERE m.id = memory_id
        AND m.uploaded_by = (SELECT auth.uid())
    )
    AND public.memory_person_is_member_of_shared_circle(memory_id, person_id)
  );

CREATE OR REPLACE FUNCTION public.notify_on_memory_person_tagged()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor_id uuid;
  v_actor_name text;
  v_circle_id uuid;
BEGIN
  SELECT
    m.uploaded_by,
    m.circle_id,
    COALESCE(NULLIF(BTRIM(p.full_name), ''), 'Someone')
  INTO v_actor_id, v_circle_id, v_actor_name
  FROM public.memories m
  LEFT JOIN public.profiles p ON p.id = m.uploaded_by
  WHERE m.id = NEW.memory_id;

  IF v_actor_id IS NULL OR NEW.person_id = v_actor_id THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.notifications
    (user_id, actor_id, type, circle_id, memory_id, is_read, message)
  VALUES
    (
      NEW.person_id,
      v_actor_id,
      'memory_tagged',
      v_circle_id,
      NEW.memory_id,
      false,
      v_actor_name || ' has tagged you in new memory'
    );

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_on_memory_person_tagged() FROM PUBLIC;

DROP TRIGGER IF EXISTS on_memory_person_tagged ON public.memory_people;

CREATE TRIGGER on_memory_person_tagged
  AFTER INSERT ON public.memory_people
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_memory_person_tagged();

NOTIFY pgrst, 'reload schema';
