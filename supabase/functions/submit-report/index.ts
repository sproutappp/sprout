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

    let body: { subject?: string; message?: string };
    try {
      body = await req.json();
    } catch (_) {
      return json({ error: 'Invalid request body' }, 400);
    }

    const subject = body.subject?.trim();
    const message = body.message?.trim();

    if (!subject || !message) {
      return json({ error: 'Subject and report message are required' }, 400);
    }
    if (subject.length > 200) {
      return json({ error: 'Subject is too long' }, 400);
    }
    if (message.length > 5000) {
      return json({ error: 'Report message is too long' }, 400);
    }

    const { data: profile, error: profileError } = await ctx.supabaseAdmin
      .from('profiles')
      .select('full_name')
      .eq('id', userId)
      .maybeSingle();

    if (profileError) {
      console.error('submit-report profile lookup failed', profileError);
      return json({ error: 'Unable to prepare report' }, 500);
    }

    const username =
      profile?.full_name?.trim() ||
      ctx.userClaims?.email ||
      'Unknown user';

    const resendApiKey = Deno.env.get('RESEND_API_KEY');
    if (!resendApiKey) {
      console.error('submit-report: RESEND_API_KEY is not configured');
      return json({ error: 'Report email service is not configured' }, 503);
    }

    const from =
      Deno.env.get('RESEND_FROM_EMAIL') ||
      'Sprout Reports <contact@sproutapp.in>';

    const emailText =
      username + ' has raised an issue.\n\n' +
      'Subject: ' + subject + '\n\n' +
      'Report an Issue:\n' + message;

    const resendResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer ' + resendApiKey,
      },
      body: JSON.stringify({
        from,
        to: ['contact@sproutapp.in'],
        subject: 'Sprout issue: ' + subject,
        text: emailText,
      }),
    });

    if (!resendResponse.ok) {
      const errorBody = await resendResponse.text();
      console.error('submit-report: email delivery failed', errorBody);
      return json({ error: 'Unable to send report' }, 502);
    }

    return json({ success: true });
  }),
};
