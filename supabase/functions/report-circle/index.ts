import { withSupabase } from 'npm:@supabase/server';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

const countWords = (value: string) =>
  value.trim().length === 0 ? 0 : value.trim().split(/\s+/).length;

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

    let body: { circle_id?: string; message?: string };
    try {
      body = await req.json();
    } catch (_) {
      return json({ error: 'Invalid request body' }, 400);
    }

    const circleId = body.circle_id?.trim();
    const message = body.message?.trim();

    if (!circleId || !message) {
      return json({ error: 'Circle and report message are required' }, 400);
    }
    if (countWords(message) > 50) {
      return json({ error: 'Report message must be 50 words or fewer' }, 400);
    }

    const { data: membership, error: membershipError } =
      await ctx.supabaseAdmin
        .from('circle_members')
        .select('user_id')
        .eq('circle_id', circleId)
        .eq('user_id', userId)
        .maybeSingle();

    if (membershipError) {
      console.error('report-circle membership lookup failed', membershipError);
      return json({ error: 'Unable to verify circle membership' }, 500);
    }
    if (!membership) {
      return json({ error: 'Only circle members can report a circle' }, 403);
    }

    const [{ data: circle, error: circleError }, { data: profile, error: profileError }] =
      await Promise.all([
        ctx.supabaseAdmin
          .from('circles')
          .select('name')
          .eq('id', circleId)
          .maybeSingle(),
        ctx.supabaseAdmin
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle(),
      ]);

    if (circleError || !circle) {
      console.error('report-circle circle lookup failed', circleError);
      return json({ error: 'Circle not found' }, 404);
    }

    if (profileError) {
      console.error('report-circle profile lookup failed', profileError);
    }

    const username =
      profile?.full_name?.trim() ||
      ctx.userClaims?.email ||
      'Unknown user';

    const resendApiKey = Deno.env.get('RESEND_API_KEY');
    if (!resendApiKey) {
      console.error('report-circle: RESEND_API_KEY is not configured');
      return json({ error: 'Report email service is not configured' }, 503);
    }

    const from =
      Deno.env.get('RESEND_FROM_EMAIL') ||
      'Sprout Reports <contact@sproutapp.in>';

    const emailText =
      `${username} has reported the about the ${circle.name} ` +
      `{"${message}"}`;

    const resendResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${resendApiKey}`,
      },
      body: JSON.stringify({
        from,
        to: ['contact@sproutapp.in'],
        subject: `Circle report: ${circle.name}`,
        text: emailText,
      }),
    });

    if (!resendResponse.ok) {
      const errorBody = await resendResponse.text();
      console.error('report-circle: email delivery failed', errorBody);
      return json({ error: 'Unable to send report' }, 502);
    }

    return json({ success: true });
  }),
};
