-- schema.sql
-- Supabase-ready schema for Leads / Applications / Tasks
-- Includes required fields, FK constraints, indexes, check constraints,
-- and a helper function to broadcast notifications (pg_notify wrapper).
-- Run in Supabase SQL editor.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- leads table
CREATE TABLE IF NOT EXISTS leads (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id uuid NOT NULL,
  owner_id uuid,            -- counselor user id
  team_id uuid,             -- team the lead is assigned to
  name text NOT NULL,
  email text,
  phone text,
  stage text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION set_updated_at_column()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language plpgsql;

CREATE TRIGGER trg_leads_set_updated_at
BEFORE UPDATE ON leads
FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

CREATE INDEX IF NOT EXISTS idx_leads_owner_stage_created_at
  ON leads (owner_id, stage, created_at DESC);

-- applications table
CREATE TABLE IF NOT EXISTS applications (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id uuid NOT NULL,
  lead_id uuid NOT NULL,
  application_data jsonb,
  status text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_applications_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE CASCADE
);

CREATE TRIGGER trg_applications_set_updated_at
BEFORE UPDATE ON applications
FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

-- Index for fetching applications by lead
CREATE INDEX IF NOT EXISTS idx_applications_by_lead ON applications (lead_id);

-- tasks table
CREATE TABLE IF NOT EXISTS tasks (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id uuid NOT NULL,
  related_id uuid NOT NULL, -- references applications.id
  related_table text NOT NULL DEFAULT 'applications', 
  title text NOT NULL,
  description text,
  type text NOT NULL, -- 'call' | 'email' | 'review'
  status text NOT NULL DEFAULT 'pending', -- pending | completed | canceled
  due_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_tasks_application FOREIGN KEY (related_id) REFERENCES applications (id) ON DELETE CASCADE,
  CONSTRAINT chk_task_type CHECK (type IN ('call','email','review')),
  CONSTRAINT chk_due_after_created CHECK (due_at >= created_at)
);

CREATE TRIGGER trg_tasks_set_updated_at
BEFORE UPDATE ON tasks
FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

-- Index to support queries for "tasks due today"
-- We index the expression (date_trunc('day', due_at)) so queries by date are fast.
CREATE INDEX IF NOT EXISTS idx_tasks_due_date_trunc ON tasks ((date_trunc('day', due_at)));

-- Also index by tenant + status for common operations
CREATE INDEX IF NOT EXISTS idx_tasks_tenant_status ON tasks (tenant_id, status);


-- This function allows Edge Functions to call an RPC to emit pg_notify messages.
CREATE OR REPLACE FUNCTION broadcast_notification(channel text, payload jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM pg_notify(channel, payload::text);
END;
$$;

-- Grant execute on the RPC to authenticated role (adjust role name if necessary)
GRANT EXECUTE ON FUNCTION broadcast_notification(text, jsonb) TO authenticated;
