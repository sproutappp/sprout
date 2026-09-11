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

async function removeFolder(admin: SupabaseClient, bucket: string, folder: string) {
  const paths: string[] = [];
  let offset = 0;

  while (true) {
    const { data, error } = await admin.storage.from(bucket).list(folder, {
      limit: 1000,
      offset,
    });
    if (error) throw error;
    if (!data || data.length === 0) break;

    for (const item of data) {
      if (item.id) paths.push(`${folder}/${item.name}`);
    }
    if (data.length < 1000) break;
    offset += data.length;
  }

  for (let i = 0; i < paths.length; i += 100) {
    const { error } = await admin.storage.from(bucket).remove(paths.slice(i, i + 100));
    if (error) throw error;
  }
}

async function tryDeleteByColumn(
  admin: SupabaseClient,
  table: string,
  column: string,
  value: string,
) {
  const { error } = await admin.from(table).delete().eq(column, value);
  // Some older installations may not have every optional table/column.
  if (error && !['42P01', '42703'].includes(error.code ?? '')) throw error;
}

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
    if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

    const userId = ctx.userClaims?.sub;
    if (!userId) return json({ error: 'Unauthorized' }, 401);

    const admin = ctx.supabaseAdmin;

    try {
      // Collect IDs before cascading deletes remove them.
      const [{ data: memories, error: memoriesError }, { data: circles, error: circlesError }] =
        await Promise.all([
          admin.from('memories').select('id, image_url').eq('uploaded_by', userId),
          admin.from('circles').select('id').eq('created_by', userId),
        ]);
      if (memoriesError) throw memoriesError;
      if (circlesError) throw circlesError;

      const memoryIds = (memories ?? []).map((row) => row.id as string);
      const circleIds = (circles ?? []).map((row) => row.id as string);

      // Delete Storage objects through the Storage API before the auth user
      // is removed. This prevents orphaned files.
      await removeFolder(admin, 'avatars', userId);
      await removeFolder(admin, 'circle-covers', userId);

      const memoryPaths = (memories ?? [])
        .map((row) => row.image_url as string | null)
        .filter((path): path is string => !!path && !path.startsWith('http'));
      for (let i = 0; i < memoryPaths.length; i += 100) {
        const { error } = await admin.storage.from('memories').remove(memoryPaths.slice(i, i + 100));
        if (error) throw error;
      }

      // Remove rows directly tied to the account or circles it owns.
      if (memoryIds.length) {
        await admin.from('memory_circles').delete().in('memory_id', memoryIds);
        await admin.from('memory_reactions').delete().in('memory_id', memoryIds);
        await admin.from('memory_comments').delete().in('memory_id', memoryIds);
      }

      if (circleIds.length) {
        await admin.from('circle_invites').delete().in('circle_id', circleIds);
        await admin.from('memory_circles').delete().in('circle_id', circleIds);
        await admin.from('circle_members').delete().in('circle_id', circleIds);
      }

      await tryDeleteByColumn(admin, 'memory_reactions', 'user_id', userId);
      await tryDeleteByColumn(admin, 'memory_comments', 'user_id', userId);
      await tryDeleteByColumn(admin, 'notifications', 'user_id', userId);
      await tryDeleteByColumn(admin, 'notifications', 'actor_id', userId);
      await tryDeleteByColumn(admin, 'circle_members', 'user_id', userId);
      await tryDeleteByColumn(admin, 'circle_invites', 'created_by', userId);
      await tryDeleteByColumn(admin, 'private_profile_info', 'id', userId);
      await tryDeleteByColumn(admin, 'memories', 'uploaded_by', userId);

      if (circleIds.length) {
        const { error } = await admin.from('circles').delete().in('id', circleIds);
        if (error) throw error;
      }

      // profiles.id references auth.users with ON DELETE CASCADE in Sprout's
      // schema, so deleting the auth identity removes the profile as well.
      const { error: authError } = await admin.auth.admin.deleteUser(userId, false);
      if (authError) throw authError;

      return json({ success: true });
    } catch (error) {
      console.error('delete-account failed', error);
      return json({ error: 'Account deletion failed' }, 500);
    }
  }),
};
