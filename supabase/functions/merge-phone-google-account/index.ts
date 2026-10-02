import { createRemoteJWKSet, jwtVerify } from 'npm:jose@6.1.0';
import { createClient } from 'npm:@supabase/supabase-js@2';

const GOOGLE_ISSUER = 'https://accounts.google.com';
const GOOGLE_SERVER_CLIENT_ID =
  '734501171389-8199tv2f24r3tt47clc462detk6avn00.apps.googleusercontent.com';
const GOOGLE_JWKS = createRemoteJWKSet(
  new URL('https://www.googleapis.com/oauth2/v3/certs'),
);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

function normalizeEmail(value: string): string {
  return value.trim().toLowerCase();
}

async function verifyGoogleIdToken(token: string) {
  const { payload } = await jwtVerify(token, GOOGLE_JWKS, {
    issuer: GOOGLE_ISSUER,
    audience: GOOGLE_SERVER_CLIENT_ID,
  });

  if (payload.email_verified !== true) {
    throw new Error('The Google account email is not verified by Google.');
  }
  if (typeof payload.sub !== 'string' || typeof payload.email !== 'string') {
    throw new Error('Google verification did not return a usable identity.');
  }

  return { sub: payload.sub, email: normalizeEmail(payload.email) };
}

const secretKeys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}');
const secretKey = secretKeys.default ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
if (!secretKey) throw new Error('Supabase server key is not configured');

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseAdmin = createClient(
  supabaseUrl,
  secretKey,
  { auth: { autoRefreshToken: false, persistSession: false } },
);

export default {
  fetch: async (req: Request) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
    if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

    try {
      const authHeader = req.headers.get('Authorization') ?? '';
      const accessToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : '';
      if (!accessToken) return json({ error: 'A signed-in mobile account is required.' }, 401);

      const { data: currentUserData, error: currentUserError } =
        await supabaseAdmin.auth.getUser(accessToken);
      if (currentUserError || !currentUserData.user) {
        return json({ error: 'Your current Sprout session is no longer valid.' }, 401);
      }
      const sourceUser = currentUserData.user;

      const body = await req.json();
      const expectedEmail = typeof body?.expected_email === 'string'
        ? normalizeEmail(body.expected_email) : '';
      const googleIdToken = typeof body?.google_id_token === 'string'
        ? body.google_id_token : '';
      if (!expectedEmail || !googleIdToken) {
        return json({ error: 'Google verification details are missing.' }, 400);
      }

      if (!sourceUser.email?.toLowerCase().startsWith('phone+')) {
        return json({ error: 'Only a phone-primary Sprout account can start this merge.' }, 403);
      }

      const { data: phoneRow, error: phoneError } = await supabaseAdmin
        .from('private_profile_info')
        .select('mobile_number')
        .eq('id', sourceUser.id)
        .maybeSingle();
      if (phoneError) throw phoneError;
      if (!phoneRow?.mobile_number) {
        return json({ error: 'No verified mobile number is linked to this account.' }, 403);
      }

      const google = await verifyGoogleIdToken(googleIdToken);
      if (google.email !== expectedEmail) {
        return json({ error: 'The Google account you verified does not match the email entered in Sprout.' }, 409);
      }

      let targetUser = null;
      for (let page = 1; page <= 10 && !targetUser; page++) {
        const { data, error } = await supabaseAdmin.auth.admin.listUsers({ page, perPage: 1000 });
        if (error) throw error;
        targetUser = data.users.find((candidate) => {
          if (candidate.email?.toLowerCase() !== google.email) return false;
          return (candidate.identities ?? []).some((identity) =>
            identity.provider === 'google' && identity.identity_data?.sub === google.sub,
          );
        }) ?? null;
        if (data.users.length < 1000) break;
      }

      if (!targetUser) {
        return json({
          error: 'That Google account is not an existing Sprout account. You can use Google sign-in normally instead.',
        }, 404);
      }
      if (targetUser.id === sourceUser.id) {
        return json({ error: 'This Google identity is already on your current Sprout account.' }, 409);
      }

      const { data: mergeResult, error: mergeError } = await supabaseAdmin.rpc(
        'merge_sprout_accounts',
        { source_user_id: sourceUser.id, target_user_id: targetUser.id },
      );
      if (mergeError) throw mergeError;

      const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(sourceUser.id, false);
      if (deleteError) {
        console.error('Source Auth user cleanup failed after successful merge', deleteError);
        return json({
          success: true,
          cleanup_pending: true,
          target_user_id: targetUser.id,
          merge: mergeResult,
        });
      }

      return json({
        success: true,
        cleanup_pending: false,
        target_user_id: targetUser.id,
        merge: mergeResult,
      });
    } catch (error) {
      console.error('merge-phone-google-account failed', error);
      const message = error instanceof Error ? error.message : 'Could not merge the Sprout accounts';
      return json({ error: message }, 500);
    }
  },
};
