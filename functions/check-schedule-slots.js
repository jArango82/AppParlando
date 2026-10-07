/**
 * Edge Function: check-schedule-slots
 *
 * Usa Firebase Admin SDK (moderno) — NO la API legacy / server key.
 *
 * Secrets en InsForge (encrypted):
 *   FIREBASE_SERVICE_ACCOUNT_JSON  → contenido completo del JSON
 *                                    "Generate new private key" de Firebase
 *   CRON_SECRET                    → el schedule lo envía en el header
 *                                    x-cron-secret; sin él responde 401
 *
 * Env opcional:
 *   SCHEDULE_API_BASE
 *   INSFORGE_URL / INSFORGE_ANON_KEY (si el runtime no los inyecta)
 *
 * Cron sugerido: cada 15 min (expresion cron cada cuarto de hora).
 */

import { initializeApp, cert, getApps } from 'npm:firebase-admin/app';
import { getMessaging } from 'npm:firebase-admin/messaging';

const SCHEDULE_API =
  Deno.env.get('SCHEDULE_API_BASE') ??
  'https://parlandolingue.com/assets/php/student_schedule_booking.php';

const COOLDOWN_MS = 3 * 60 * 60 * 1000; // 3 h entre avisos por estudiante

const DAY_LABELS = {
  lunes: 'Lunes',
  martes: 'Martes',
  miercoles: 'Miércoles',
  jueves: 'Jueves',
  viernes: 'Viernes',
  sabado: 'Sábado',
};

function insforgeBaseUrl() {
  return (
    Deno.env.get('INSFORGE_BASE_URL') ??
    Deno.env.get('INSFORGE_URL') ??
    ''
  );
}

function insforgeApiKey() {
  return (
    Deno.env.get('API_KEY') ??
    Deno.env.get('INSFORGE_SERVICE_KEY') ??
    Deno.env.get('INSFORGE_ANON_KEY') ??
    ''
  );
}

function dbHeaders() {
  return {
    Authorization: `Bearer ${insforgeApiKey()}`,
    'Content-Type': 'application/json',
    Prefer: 'return=representation',
  };
}

async function listEnabledReminders() {
  const url = new URL(
    `${insforgeBaseUrl()}/api/database/records/schedule_reminders`,
  );
  url.searchParams.set('enabled', 'eq.true');
  url.searchParams.set('select', '*');

  const res = await fetch(url, { headers: dbHeaders() });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`DB list failed HTTP ${res.status}: ${text}`);
  }
  return JSON.parse(text);
}

async function markNotified(studentId) {
  const url = new URL(
    `${insforgeBaseUrl()}/api/database/records/schedule_reminders`,
  );
  url.searchParams.set('student_id', `eq.${studentId}`);

  const res = await fetch(url, {
    method: 'PATCH',
    headers: dbHeaders(),
    body: JSON.stringify({
      last_notified_at: new Date().toISOString(),
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    console.error(`markNotified failed for ${studentId}: ${text}`);
  }
}

function getServiceAccount() {
  const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (!raw) {
    throw new Error(
      'Falta el secret FIREBASE_SERVICE_ACCOUNT_JSON en InsForge. ' +
        'Pega el JSON completo del Service Account de Firebase.',
    );
  }
  return JSON.parse(raw);
}

/**
 * Equivalente al snippet de Firebase Console:
 *
 *   admin.initializeApp({
 *     credential: admin.credential.cert(serviceAccount)
 *   });
 *
 * Adaptado a ESM + Deno (npm:firebase-admin) sin require() de archivo.
 */
function initFirebaseAdmin() {
  if (getApps().length > 0) return getApps()[0];

  const serviceAccount = getServiceAccount();
  return initializeApp({
    credential: cert(serviceAccount),
    projectId: serviceAccount.project_id,
  });
}

function isoWeekKey(date = new Date(), weeksOffset = 1) {
  const d = new Date(date);
  d.setDate(d.getDate() + weeksOffset * 7);
  const day = d.getDay();
  const distanceToMonday = day === 0 ? -6 : 1 - day;
  const monday = new Date(d);
  monday.setDate(d.getDate() + distanceToMonday);
  const thursday = new Date(monday);
  thursday.setDate(monday.getDate() + 3);
  const firstJan = new Date(thursday.getFullYear(), 0, 1);
  const firstJanDay = firstJan.getDay();
  const weekNum = Math.ceil(
    ((thursday - firstJan) / 86400000 + firstJanDay + 1) / 7,
  );
  return `${thursday.getFullYear()}-W${String(weekNum).padStart(2, '0')}`;
}

async function fetchStudentSchedule(studentId, weekKey) {
  const url =
    `${SCHEDULE_API}?week_key=${encodeURIComponent(weekKey)}` +
    `&student_id=${encodeURIComponent(studentId)}`;
  const res = await fetch(url);
  if (!res.ok) return null;
  const json = await res.json();
  if (!json.success || !json.student) return null;
  return json.student;
}

function findBookableMatches(studentView, reminders) {
  const matches = [];
  const days = studentView.days ?? {};
  for (const rem of reminders ?? []) {
    const dayKey = rem.day;
    const wanted = new Set(rem.slots ?? []);
    const day = days[dayKey];
    if (!day) continue;
    for (const slotObj of day.slots ?? []) {
      if (!wanted.has(slotObj.slot)) continue;
      for (const room of slotObj.rooms ?? []) {
        if (room.can_book === true) {
          matches.push({
            dayKey,
            slot: slotObj.slot,
            roomName: room.name,
            roomId: room.id,
          });
        }
      }
    }
  }
  return matches;
}

async function sendPushAdmin(messaging, { token, title, body, data }) {
  const messageId = await messaging.send({
    token,
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data ?? {}).map(([k, v]) => [k, String(v)]),
    ),
    android: {
      priority: 'high',
      notification: {
        channelId: 'parlando_push',
        sound: 'default',
      },
    },
    apns: {
      headers: {
        'apns-priority': '10',
        'apns-push-type': 'alert',
      },
      payload: {
        aps: {
          alert: { title, body },
          sound: 'default',
          badge: 1,
          'content-available': 1,
        },
      },
    },
  });
  return messageId;
}

export default async function (req) {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  // Solo el cron de InsForge puede ejecutarla: la respuesta incluye student_id
  // y cada ejecución consulta cupos y puede enviar pushes.
  const cronSecret = Deno.env.get('CRON_SECRET') ?? '';
  if (!cronSecret || req.headers.get('x-cron-secret') !== cronSecret) {
    return new Response(
      JSON.stringify({ success: false, message: 'Unauthorized' }),
      {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }

  try {
    if (!insforgeBaseUrl() || !insforgeApiKey()) {
      return new Response(
        JSON.stringify({
          success: false,
          message: 'Missing INSFORGE_BASE_URL or API_KEY in function runtime',
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    initFirebaseAdmin();
    const messaging = getMessaging();

    const rows = await listEnabledReminders();
    // Revisar semana actual y próxima (la app suele mostrar próxima)
    const weekKeys = [
      isoWeekKey(new Date(), 0),
      isoWeekKey(new Date(), 1),
    ];
    let notified = 0;
    const details = [];

    for (const row of rows ?? []) {
      if (!row.fcm_token) {
        details.push({ student_id: row.student_id, ok: false, error: 'no_fcm_token' });
        continue;
      }

      if (row.last_notified_at) {
        const last = new Date(row.last_notified_at).getTime();
        if (Date.now() - last < COOLDOWN_MS) {
          details.push({
            student_id: row.student_id,
            ok: false,
            error: 'cooldown',
            last_notified_at: row.last_notified_at,
          });
          continue;
        }
      }

      let first = null;
      let matchedWeek = null;
      for (const weekKey of weekKeys) {
        const view = await fetchStudentSchedule(row.student_id, weekKey);
        if (!view) continue;
        const matches = findBookableMatches(view, row.reminders);
        if (matches.length > 0) {
          first = matches[0];
          matchedWeek = weekKey;
          break;
        }
      }

      if (!first || !matchedWeek) {
        details.push({
          student_id: row.student_id,
          ok: false,
          error: 'no_bookable_match',
          week_keys: weekKeys,
          reminders: row.reminders,
        });
        continue;
      }

      const dayLabel = DAY_LABELS[first.dayKey] ?? first.dayKey;
      const title = '¡Se liberó un cupo!';
      const body =
        `${dayLabel}, ${first.slot} en el salón ${first.roomName}. ` +
        'Entra a Parlando para agendarte antes de que se ocupe.';

      try {
        const messageId = await sendPushAdmin(messaging, {
          token: row.fcm_token,
          title,
          body,
          data: {
            type: 'schedule_cupo',
            week_key: matchedWeek,
            day_key: first.dayKey,
            slot: first.slot,
            room_id: first.roomId,
          },
        });

        notified++;
        details.push({
          student_id: row.student_id,
          ok: true,
          messageId,
          week_key: matchedWeek,
          match: first,
        });

        await markNotified(row.student_id);
      } catch (sendErr) {
        details.push({
          student_id: row.student_id,
          ok: false,
          error: String(sendErr),
          week_key: matchedWeek,
          match: first,
        });
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        week_keys: weekKeys,
        checked: (rows ?? []).length,
        notified,
        details,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ success: false, message: String(e) }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }
}
