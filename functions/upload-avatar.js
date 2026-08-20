import { createClient } from 'npm:@insforge/sdk';

/**
 * Edge Function: upload-avatar
 *
 * Proxy para subir avatares al bucket de storage con permisos elevados.
 * La app Flutter envía JSON:
 *   { username, fileBase64, contentType? }
 *
 * Endpoint: POST /functions/upload-avatar
 */
export default async function (req) {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const body = await req.json();
    const username = body?.username;
    const fileBase64 = body?.fileBase64;
    const contentType = body?.contentType || 'image/jpeg';

    if (!username || !fileBase64) {
      return new Response(
        JSON.stringify({ error: 'Missing username or fileBase64' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    const fileName = `${String(username).toLowerCase()}_avatar.jpg`;
    const binary = Uint8Array.from(atob(fileBase64), (c) => c.charCodeAt(0));
    const file = new File([binary], fileName, { type: contentType });

    const client = createClient({
      baseUrl: Deno.env.get('INSFORGE_BASE_URL'),
      anonKey: Deno.env.get('API_KEY'),
    });

    const { data, error } = await client.storage
      .from('avatars')
      .upload(fileName, file);

    if (error) {
      console.error('Storage upload error:', error);
      return new Response(
        JSON.stringify({ error: 'Upload failed', detail: error.message }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        key: data.key,
        url: data.url,
        bucket: data.bucket,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  } catch (err) {
    console.error('Unexpected error:', err);
    return new Response(
      JSON.stringify({ error: 'Internal server error', detail: err.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }
}
