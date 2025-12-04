-- RLS policies for leads

-- Enable row level security
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;

-- SELECT policy:
-- - Admins (role = 'admin') can see all leads for their tenant
-- - Counselors can see leads they own OR leads assigned to any team they belong to
CREATE POLICY select_leads_by_role_owner_team ON leads
FOR SELECT
USING (
  -- admin check (role claim)
  (auth.jwt() ->> 'role') = 'admin'
  OR
  -- owner
  owner_id = auth.uid()
  OR
  -- team membership: assumes table user_teams(user_id, team_id) exists
  EXISTS (
    SELECT 1
    FROM user_teams ut
    WHERE ut.user_id = auth.uid()
      AND ut.team_id = leads.team_id
  )
);

-- INSERT policy:
-- Admins or counselors can insert leads inside their tenant.
-- For counselors: either owner_id must be auth.uid() or team_id must be a team they belong to.
CREATE POLICY insert_leads_for_admin_or_team ON leads
FOR INSERT
WITH CHECK (
  (auth.jwt() ->> 'role') = 'admin'
  OR
  owner_id = auth.uid()
  OR
  EXISTS (
    SELECT 1
    FROM user_teams ut
    WHERE ut.user_id = auth.uid()
      AND ut.team_id = NEW.team_id
  )
);

-- Optional: restrict UPDATE/DELETE to admins only (safer default)
CREATE POLICY update_leads_admin_only ON leads
FOR UPDATE
USING ((auth.jwt() ->> 'role') = 'admin')
WITH CHECK ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY delete_leads_admin_only ON leads
FOR DELETE
USING ((auth.jwt() ->> 'role') = 'admin');
