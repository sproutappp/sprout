import { createRemoteJWKSet, jwtVerify } from 'npm:jose@6.1.0';
import { createClient } from 'npm:@supabase/supabase-js@2';

const FIREBASE_PROJECT_ID = 'sprout-ed7ce';
const FIREBASE_ISSUER = `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`;
const FIREBASE_JWKS = createRemoteJWKSet(
  new URL('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'),
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

function normalizePhone(value: string): string {
  const digits = value.replace(/\D/g, '');
  return `+${digits}`;
}

function syntheticEmail(phone: string): string {
  return `phone+${phone.replace(/\D/g, '')}@sproutapp.in`;
}

function generatePassword(): string {
  const bytes = new Uint8Array(48);
  crypto.getRandomValues(bytes);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

async function verifyFirebaseToken(token: string) {
  const { payload } = await jwtVerify(token, FIREBASE_JWKS, {
    issuer: FIREBASE_ISSUER,
    audience: FIREBASE_PROJECT_ID,
  });
  return payload;
}

const secretKeys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}');
const secretKey = secretKeys.default ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
if (!secretKey) throw new Error('Supabase server key is not configured');

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const publicKey = Deno.env.get('SUPABASE_ANON_KEY') ?? secretKey;

const supabaseAdmin = createClient(
  supabaseUrl,
  secretKey,
  { auth: { autoRefreshToken: false, persistSession: false } },
);

async function issueSupabaseSession(email: string, password: string) {
  const response = await fetch(
    `${supabaseUrl}/auth/v1/token?grant_type=password`,
    {
      method: 'POST',
      headers: {
        apikey: publicKey,
        Authorization: `Bearer ${publicKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email, password }),
    },
  );

  const data = await response.json();
  if (!response.ok) {
    const detail =
      typeof data?.msg === 'string'
        ? data.msg
        : typeof data?.message === 'string'
            ? data.message
            : 'Supabase could not create a session';
    throw new Error(detail);
  }

  return data;
}

export default {
  fetch: async (req: Request) => {
    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders });
    }
    if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

    try {
      const authHeader = req.headers.get('Authorization') ?? '';
      const firebaseToken = authHeader.startsWith('Bearer ')
        ? authHeader.slice(7).trim()
        : '';
      if (!firebaseToken) return json({ error: 'Missing Firebase authentication' }, 401);

      const claims = await verifyFirebaseToken(firebaseToken);
      const tokenPhone = typeof claims.phone_number === 'string'
        ? normalizePhone(claims.phone_number)
        : '';
      if (!tokenPhone) return json({ error: 'Firebase token has no verified phone number' }, 403);

      const body = await req.json();
      const requestedPhone =
        typeof body?.phone === 'string' ? normalizePhone(body.phone) : '';
      if (!requestedPhone || requestedPhone !== tokenPhone) {
        return json({ error: 'Verified phone number does not match the requested account' }, 403);
      }

      const synthetic = syntheticEmail(requestedPhone);

      // First resolve the verified phone against the app's own account
      // mapping. This is what keeps a Google-primary account and a
      // phone-primary account as ONE Supabase user.
      let matchedUserId: string | null = null;
      let accountEmail = synthetic;

      const { data: linkedRow, error: linkedError } = await supabaseAdmin
        .from('private_profile_info')
        .select('id')
        .eq('mobile_number', requestedPhone)
        .maybeSingle();

      if (linkedError) throw linkedError;

      if (linkedRow?.id) {
        const { data: linkedUser, error: linkedUserError } =
          await supabaseAdmin.auth.admin.getUserById(linkedRow.id);
        if (linkedUserError) throw linkedUserError;
        if (linkedUser.user) {
          matchedUserId = linkedUser.user.id;
          accountEmail = linkedUser.user.email ?? synthetic;
        }
      }

      // Backward compatibility for phone accounts created before the
      // private_profile_info phone mapping was introduced.
      if (!matchedUserId) {
        for (let page = 1; page <= 10 && !matchedUserId; page++) {
          const { data, error } = await supabaseAdmin.auth.admin.listUsers({
            page,
            perPage: 1000,
          });
          if (error) throw error;

          const match = data.users.find(
            (user) => user.email?.toLowerCase() === synthetic.toLowerCase(),
          );
          if (match) {
            matchedUserId = match.id;
            accountEmail = match.email ?? synthetic;
            break;
          }
          if (data.users.length < 1000) break;
        }
      }

      const password = generatePassword();
      let userId = matchedUserId;

      if (userId) {
        const { data: existingUser, error: existingUserError } =
          await supabaseAdmin.auth.admin.getUserById(userId);
        if (existingUserError) throw existingUserError;
        if (!existingUser.user) throw new Error('Linked account no longer exists');

        accountEmail = existingUser.user.email ?? synthetic;

        const { error } = await supabaseAdmin.auth.admin.updateUserById(userId, {
          password,
          email_confirm: true,
        });
        if (error) throw error;
      } else {
        const { data: taken, error: takenError } = await supabaseAdmin.rpc(
          'is_mobile_number_taken',
          { phone: requestedPhone },
        );
        if (takenError) throw takenError;

        if (taken === true) {
          return json({
            error:
              'This mobile number is linked to another existing account. Sign in with that account first.',
          }, 409);
        }

        const { data, error } = await supabaseAdmin.auth.admin.createUser({
          email: synthetic,
          password,
          email_confirm: true,
        });
        if (error) throw error;
        userId = data.user?.id ?? null;
        if (!userId) throw new Error('Supabase account creation returned no user');
        accountEmail = synthetic;
      }

      // Persist the verified phone against this SAME Supabase user so
      // future phone OTP logins can resolve the account even if its email
      // has since been changed to the user's real Gmail address.
      const { error: mobileMapError } = await supabaseAdmin
        .from('private_profile_info')
        .upsert({
          id: userId,
          mobile_number: requestedPhone,
        });
      if (mobileMapError) throw mobileMapError;

      const session = await issueSupabaseSession(email, password);

      return json({
        success: true,
        email,
        userId,
        access_token: session.access_token,
        refresh_token: session.refresh_token,
        expires_in: session.expires_in,
        token_type: session.token_type,
      });
    } catch (error) {
      console.error('recover-phone-account failed', error);
      const message = error instanceof Error ? error.message : 'Could not recover the phone account';
      return json({ error: message }, 500);
    }
  },
};
