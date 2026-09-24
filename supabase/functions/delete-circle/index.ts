import { withSupabase } from 'npm:@supabase/server';
import type { SupabaseClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

async function removeStoragePaths(
  admin: SupabaseClient,
  bucket: string,
  paths: string[],
) {
  const unique = [...new Set(paths.filter((path) => path && !path.startsWith('http')))];
  for (let i = 0; i < unique.length; i += 100) {
    const batch = unique.slice(i, i + 100);
    const { error } = await admin.storage.from(bucket).remove(batch);
    if (error) throw error;
  }
}

function coverPathFromUrl(url: string | null) {
  if (!url) return null;
  const marker = '/storage/v1/object/public/circle-covers/';
  const index = url.indexOf(marker);
  if (index < 0) return null;
  const path = url.slice(index + marker.length);
  return path || null;
}

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders });
    }
    if (req.method !== 'POST') {
      return json({ error: 'Method not allowed' }, 405);
    }

    const userId = ctx.userClaims?.sub;
    if (!userId) return json({ error: 'Unauthorized' }, 401);

    const admin = ctx.supabaseAdmin;

    try {
      const body = await req.json();
      const circleId = typeof body?.circleId === 'string' ? body.circleId : null;
      if (!circleId) return json({ error: 'circleId is required' }, 400);

      const { data: circle, error: circleError } = await admin
        .from('circles')
        .select('id, name, created_by, cover_image_url')
        .eq('id', circleId)
        .maybeSingle();

      if (circleError) throw circleError;
      if (!circle) return json({ error: 'Circle not found' }, 404);
      if (circle.created_by !== userId) {
        return json({ error: 'Only the circle creator can delete this circle' }, 403);
      }

      const { data: adminMembership, error: adminMembershipError } = await admin
        .from('circle_members')
        .select('user_id')
        .eq('circle_id', circleId)
        .eq('user_id', userId)
        .eq('role', 'admin')
        .maybeSingle();

      if (adminMembershipError) throw adminMembershipError;
      if (!adminMembership) {
        return json({ error: 'Only the circle admin can delete this circle' }, 403);
      }

      // Collect all memories attached to this circle, including memories
      // shared through memory_circles rather than only memories.circle_id.
      const [{ data: directMemories, error: directError }, { data: shares, error: sharesError }] =
        await Promise.all([
          admin.from('memories').select('id').eq('circle_id', circleId),
          admin.from('memory_circles').select('memory_id').eq('circle_id', circleId),
        ]);

      if (directError) throw directError;
      if (sharesError) throw sharesError;

      const memoryIds = [
        ...new Set([
          ...(directMemories ?? []).map((row) => row.id as string),
          ...(shares ?? []).map((row) => row.memory_id as string),
        ]),
      ];

      const memoryPaths: string[] = [];
      if (memoryIds.length) {
        const { data: memories, error: memoriesError } = await admin
          .from('memories')
          .select('image_url, media_urls')
          .in('id', memoryIds);

        if (memoriesError) throw memoriesError;

        for (const memory of memories ?? []) {
          if (typeof memory.image_url === 'string') memoryPaths.push(memory.image_url);
          if (Array.isArray(memory.media_urls)) {
            for (const path of memory.media_urls) {
              if (typeof path === 'string') memoryPaths.push(path);
            }
          }
        }
      }

      const coverPath = coverPathFromUrl(circle.cover_image_url);

      // Delete physical files through the Storage API before cascading the
      // database rows. This also removes files uploaded by other circle
      // members because this function uses the server-side service client.
      await removeStoragePaths(admin, 'memories', memoryPaths);
      if (coverPath) {
        await removeStoragePaths(admin, 'circle-covers', [coverPath]);
      }

      // Persist deletion notifications before deleting the circle. The
      // notification deliberately has no circle_id so ON DELETE CASCADE
      // cannot remove it with the circle.
      const { data: members, error: membersError } = await admin
        .from('circle_members')
        .select('user_id')
        .eq('circle_id', circleId)
        .neq('user_id', userId);

      if (membersError) throw membersError;

      const actorName = await admin
        .from('profiles')
        .select('full_name')
        .eq('id', userId)
        .maybeSingle();

      if (actorName.error) throw actorName.error;

      const displayName =
        typeof actorName.data?.full_name === 'string' &&
        actorName.data.full_name.trim().isNotEmpty
          ? actorName.data.full_name.trim()
          : 'Someone';
      const message = displayName + ' has deleted the ' + circle.name;

      if ((members ?? []).length) {
        const notifications = (members ?? []).map((member) => ({
          user_id: member.user_id,
          actor_id: userId,
          type: 'circle_deleted',
          circle_id: null,
          memory_id: null,
          message,
          is_read: false,
        }));

        const { error: notificationError } = await admin
          .from('notifications')
          .insert(notifications);

        if (notificationError) throw notificationError;
      }

      const { error: deleteError } = await admin
        .from('circles')
        .delete()
        .eq('id', circleId)
        .eq('created_by', userId);

      if (deleteError) throw deleteError;

      return json({
        success: true,
        circleId,
        circleName: circle.name,
      });
    } catch (error) {
      console.error('delete-circle failed', error);
      return json({ error: 'Circle deletion failed' }, 500);
    }
  }),
};
