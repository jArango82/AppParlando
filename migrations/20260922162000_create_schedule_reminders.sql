-- schedule_reminders: preferencias de push para cupos de matrícula
-- Crear en InsForge Dashboard → Database → SQL, o como migration admin.

CREATE TABLE IF NOT EXISTS public.schedule_reminders (
  student_id text PRIMARY KEY,
  enabled boolean NOT NULL DEFAULT false,
  reminders jsonb NOT NULL DEFAULT '[]'::jsonb,
  fcm_token text,
  platform text,
  last_notified_at timestamptz,
  updated_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_schedule_reminders_enabled
  ON public.schedule_reminders (enabled)
  WHERE enabled = true;

ALTER TABLE public.schedule_reminders DISABLE ROW LEVEL SECURITY;
