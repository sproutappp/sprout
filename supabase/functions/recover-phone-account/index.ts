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

const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  secretKey,
  { auth: { autoRefreshToken: false, persistSession: false } },
);

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

      const email = syntheticEmail(requestedPhone);

      let userId: string | null = null;
      for (let page = 1; page <= 10 && !userId; page++) {
        const { data, error } = await supabaseAdmin.auth.admin.listUsers({
          page,
          perPage: 1000,
        });
        if (error) throw error;

        const match = data.users.find(
          (user) => user.email?.toLowerCase() === email.toLowerCase(),
        );
        if (match) {
          userId = match.id;
          break;
        }
        if (data.users.length < 1000) break;
      }

      const password = generatePassword();

      if (userId) {
        const { error } = await supabaseAdmin.auth.admin.updateUserById(userId, {
          password,
          email_confirm: true,
        });
        if (error) throw error;
      } else {
        const { data: taken, error: takenError } = await supabaseAdmin.rpc(
          'is_mobile_number_taken',
          { p_phone: requestedPhone },
        );
        if (takenError) throw takenError;

        if (taken === true) {
          return json({
            error: 'This mobile number is linked to another existing account. Sign in with that account first.',
          }, 409);
        }

        const { data, error } = await supabaseAdmin.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
        });
        if (error) throw error;
        userId = data.user?.id ?? null;
        if (!userId) throw new Error('Supabase account creation returned no user');
      }

      return json({
        success: true,
        email,
        password,
        userId,
      });
    } catch (error) {
      console.error('recover-phone-account failed', error);
      return json({ error: 'Could not recover the phone account' }, 500);
    }
  },
};
