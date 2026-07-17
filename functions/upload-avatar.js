import { createClient } from 'npm:@insforge/sdk';

/**
 * Edge Function: upload-avatar
 * 
 * Proxy para subir avatares al bucket de storage con permisos elevados.
 * La app Flutter envía el archivo como multipart/form-data con un campo 'file'
 * y un campo 'username' para nombrar el archivo.
 * 
 * Endpoint: POST /api/functions/upload-avatar
 */
export default async function(req) {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  // Handle CORS preflight
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
    const formData = await req.formData();
    const file = formData.get('file');
    const username = formData.get('username');

    if (!file || !username) {
      return new Response(
        JSON.stringify({ error: 'Missing file or username' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const fileName = `${username.toLowerCase()}_avatar.jpg`;

    // Crear cliente con el SDK de InsForge usando el API_KEY (admin/service)
    const client = createClient({
      baseUrl: Deno.env.get('INSFORGE_BASE_URL'),
      anonKey: Deno.env.get('API_KEY'),
    });

    // Subir archivo al bucket 'avatars' usando el SDK
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
        }
      );
    }

    // Retornar la URL del archivo subido
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
      }
    );
  } catch (err) {
    console.error('Unexpected error:', err);
    return new Response(
      JSON.stringify({ error: 'Internal server error', detail: err.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
}
