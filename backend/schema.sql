CREATE OR REPLACE FUNCTION set_due_date_from_due_at()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    NEW.due_date := (NEW.due_at AT TIME ZONE 'UTC')::date;
  ELSE
    IF (NEW.due_at IS DISTINCT FROM OLD.due_at) THEN
      NEW.due_date := (NEW.due_at AT TIME ZONE 'UTC')::date;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2) Ensure the column exists (Postgres supports IF NOT EXISTS on ADD COLUMN)
ALTER TABLE tasks
ADD COLUMN IF NOT EXISTS due_date date;

-- 3) Backfill due_date for existing rows where it's NULL
UPDATE tasks
SET due_date = (due_at AT TIME ZONE 'UTC')::date
WHERE due_at IS NOT NULL
  AND (due_date IS NULL);

-- 4) (Re)create trigger: drop existing trigger if present, then create it
DROP TRIGGER IF EXISTS trg_tasks_set_due_date ON tasks;

CREATE TRIGGER trg_tasks_set_due_date
BEFORE INSERT OR UPDATE ON tasks
FOR EACH ROW
EXECUTE FUNCTION set_due_date_from_due_at();

-- 5) (Optional) Recreate updated_at trigger if missing (safe to run)
CREATE OR REPLACE FUNCTION set_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_tasks_set_updated_at ON tasks;

CREATE TRIGGER trg_tasks_set_updated_at
BEFORE UPDATE ON tasks
FOR EACH ROW
EXECUTE FUNCTION set_updated_at_column();

-- 6) Ensure index exists on due_date for fast queries
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks (due_date);-- 1) Create/replace trigger function to set due_date from due_at
CREATE OR REPLACE FUNCTION set_due_date_from_due_at()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    NEW.due_date := (NEW.due_at AT TIME ZONE 'UTC')::date;
  ELSE
    IF (NEW.due_at IS DISTINCT FROM OLD.due_at) THEN
      NEW.due_date := (NEW.due_at AT TIME ZONE 'UTC')::date;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2) Ensure the column exists (Postgres supports IF NOT EXISTS on ADD COLUMN)
ALTER TABLE tasks
ADD COLUMN IF NOT EXISTS due_date date;

-- 3) Backfill due_date for existing rows where it's NULL
UPDATE tasks
SET due_date = (due_at AT TIME ZONE 'UTC')::date
WHERE due_at IS NOT NULL
  AND (due_date IS NULL);

-- 4) (Re)create trigger: drop existing trigger if present, then create it
DROP TRIGGER IF EXISTS trg_tasks_set_due_date ON tasks;

CREATE TRIGGER trg_tasks_set_due_date
BEFORE INSERT OR UPDATE ON tasks
FOR EACH ROW
EXECUTE FUNCTION set_due_date_from_due_at();

-- 5) (Optional) Recreate updated_at trigger if missing (safe to run)
CREATE OR REPLACE FUNCTION set_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_tasks_set_updated_at ON tasks;

CREATE TRIGGER trg_tasks_set_updated_at
BEFORE UPDATE ON tasks
FOR EACH ROW
EXECUTE FUNCTION set_updated_at_column();

-- 6) Ensure index exists on due_date for fast queries
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks (due_date);
