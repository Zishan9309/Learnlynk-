-- LearnLynk test schema (ready to run in Supabase)
-- Creates leads, applications, tasks. Uses tasks.application_id per README.

-- Extensions (Supabase usually provides pgcrypto/gen_random_uuid)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Helper trigger to set updated_at
CREATE OR REPLACE FUNCTION set_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- leads table
CREATE TABLE IF NOT EXISTS leads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  owner_id uuid,
  team_id uuid,
  name text NOT NULL,
  email text,
  phone text,
  stage text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_leads_set_updated_at
BEFORE UPDATE ON leads
FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

CREATE INDEX IF NOT EXISTS idx_leads_tenant_owner_stage
  ON leads (tenant_id, owner_id, stage);


-- applications table
CREATE TABLE IF NOT EXISTS applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  lead_id uuid NOT NULL,
  application_data jsonb,
  status text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_applications_lead FOREIGN KEY (lead_id) REFERENCES leads(id) ON DELETE CASCADE
);

CREATE TRIGGER trg_applications_set_updated_at
BEFORE UPDATE ON applications
FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

CREATE INDEX IF NOT EXISTS idx_applications_tenant_lead
  ON applications (tenant_id, lead_id);


-- tasks table (uses application_id per README)
CREATE TABLE IF NOT EXISTS tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  application_id uuid NOT NULL,
  title text NOT NULL,
  description text,
  type text NOT NULL,            -- call | email | review
  status text NOT NULL DEFAULT 'pending', -- pending | completed | canceled
  due_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT fk_tasks_application FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE CASCADE,
  CONSTRAINT chk_task_type CHECK (type IN ('call','email','review')),
  CONSTRAINT chk_due_at_future CHECK (due_at >= created_at)
);

CREATE TRIGGER trg_tasks_set_updated_at
BEFORE UPDATE ON tasks
FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

-- generated date column for safe indexing by day
ALTER TABLE tasks
ADD COLUMN IF NOT EXISTS due_date date GENERATED ALWAYS AS (due_at::date) STORED;

-- indexes
CREATE INDEX IF NOT EXISTS idx_tasks_tenant_status ON tasks (tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks (due_date);


-- broadcast_notification RPC for pg_notify
CREATE OR REPLACE FUNCTION broadcast_notification(channel text, payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER AS $$
BEGIN
  PERFORM pg_notify(channel, payload::text);
END;
$$;

-- grant execute to authenticated role (adjust if you use a different role)
GRANT EXECUTE ON FUNCTION broadcast_notification(text, jsonb) TO authenticated;
