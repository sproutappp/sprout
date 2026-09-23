-- Reliable in-app circle invitations.
-- This migration is intentionally self-contained so an existing/live database
-- does not depend on earlier invite migrations having been applied in order.

ALTER TABLE public.circle_invites
  ADD COLUMN IF NOT EXISTS invited_user_id uuid
    REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS invite_token uuid
    REFERENCES public.circle_invites(token) ON DELETE CASCADE;

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (type IN ('circle_memory', 'circle_join', 'memory_comment', 'circle_invite'));

-- Create one notification + one targeted invite for every selected recipient.
-- The function is SECURITY DEFINER so the client never needs direct INSERT
-- permission on circle_invites or notifications.
CREATE OR REPLACE FUNCTION public.send_circle_invites(
  p_circle_id uuid,
  p_user_ids uuid[]
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;
  v_token uuid;
  v_count integer := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'You must be signed in to send invitations.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.circle_members cm
    WHERE cm.circle_id = p_circle_id
      AND cm.user_id = (SELECT auth.uid())
      AND cm.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only circle admins can send invitations.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.circles c WHERE c.id = p_circle_id
  ) THEN
    RAISE EXCEPTION 'Circle not found.';
  END IF;

  FOREACH v_user_id IN ARRAY COALESCE(p_user_ids, ARRAY[]::uuid[]) LOOP
    IF v_user_id IS NULL OR v_user_id = (SELECT auth.uid()) THEN
      CONTINUE;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = v_user_id
    ) THEN
      CONTINUE;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM public.circle_members cm
      WHERE cm.circle_id = p_circle_id
        AND cm.user_id = v_user_id
    ) THEN
      CONTINUE;
    END IF;

    -- Avoid piling up duplicate active invites for the same user/circle.
    DELETE FROM public.circle_invites ci
    WHERE ci.circle_id = p_circle_id
      AND ci.invited_user_id = v_user_id
      AND ci.revoked = false
      AND (ci.expires_at IS NULL OR ci.expires_at >= now());

    v_token := gen_random_uuid();

    INSERT INTO public.circle_invites
      (token, circle_id, created_by, invited_user_id)
    VALUES
      (v_token, p_circle_id, (SELECT auth.uid()), v_user_id);

    INSERT INTO public.notifications
      (user_id, actor_id, type, circle_id, invite_token, is_read)
    VALUES
      (v_user_id, (SELECT auth.uid()), 'circle_invite', p_circle_id, v_token, false);

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.send_circle_invites(uuid, uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.send_circle_invites(uuid, uuid[]) TO authenticated;

-- Return active invitations addressed to the current user. The client does
-- not need SELECT access to circle_invites itself, so invitation recipients
-- cannot enumerate other users' invitations.
CREATE OR REPLACE FUNCTION public.fetch_pending_circle_invites()
RETURNS TABLE (
  circle_id uuid,
  circle_name text,
  invite_token uuid,
  created_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
  SELECT
    ci.circle_id,
    c.name,
    ci.token,
    ci.created_at
  FROM public.circle_invites ci
  JOIN public.circles c ON c.id = ci.circle_id
  WHERE ci.invited_user_id = (SELECT auth.uid())
    AND ci.revoked = false
    AND (ci.expires_at IS NULL OR ci.expires_at >= now())
    AND NOT EXISTS (
      SELECT 1
      FROM public.circle_members cm
      WHERE cm.circle_id = ci.circle_id
        AND cm.user_id = (SELECT auth.uid())
    )
  ORDER BY ci.created_at DESC;
$$;

REVOKE ALL ON FUNCTION public.fetch_pending_circle_invites() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fetch_pending_circle_invites() TO authenticated;

-- Accept a targeted invitation and remove its pending state atomically.
CREATE OR REPLACE FUNCTION public.redeem_pending_circle_invite(p_circle_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_token uuid;
BEGIN
  IF (SELECT auth.uid()) IS NULL THEN
    RAISE EXCEPTION 'You must be signed in.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.circle_members cm
    WHERE cm.circle_id = p_circle_id
      AND cm.user_id = (SELECT auth.uid())
  ) THEN
    RETURN false;
  END IF;

  SELECT ci.token
    INTO v_token
  FROM public.circle_invites ci
  WHERE ci.circle_id = p_circle_id
    AND ci.invited_user_id = (SELECT auth.uid())
    AND ci.revoked = false
    AND (ci.expires_at IS NULL OR ci.expires_at >= now())
  ORDER BY ci.created_at DESC
  LIMIT 1;

  IF v_token IS NULL THEN
    RETURN false;
  END IF;

  INSERT INTO public.circle_members (circle_id, user_id, role)
  VALUES (p_circle_id, (SELECT auth.uid()), 'member')
  ON CONFLICT (circle_id, user_id) DO NOTHING;

  UPDATE public.circle_invites
  SET revoked = true
  WHERE token = v_token;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.redeem_pending_circle_invite(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.redeem_pending_circle_invite(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
