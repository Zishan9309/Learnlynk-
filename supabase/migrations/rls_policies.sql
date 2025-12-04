
-- RLS POLICIES FOR LEADS TABLE

-- Enable Row Level Security on leads table
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;

-- SELECT POLICY
-- Allow:
--   1) Admin users to read all leads
--   2) A counselor to read:
--        - leads assigned to them (owner_id = auth.uid())
--        - leads assigned to their team (team_id in user_teams)

CREATE POLICY "allow_select_for_admin_owner_team"
ON leads
FOR SELECT
USING (
  -- If user role in JWT is admin → allow all
  (auth.jwt() ->> 'role') = 'admin'
  
  OR

  -- user is the assigned owner
  owner_id = auth.uid()

  OR

  -- user belongs to same team as the lead
  EXISTS (
    SELECT 1
    FROM user_teams ut
    WHERE ut.user_id = auth.uid()
      AND ut.team_id = leads.team_id
  )
);


-- INSERT POLICY
-- Allow:
--   1) Admin create leads
--   2) Counselor may create leads assigned to:
--        - themselves
--        - their team

CREATE POLICY "allow_insert_for_admin_owner_team"
ON leads
FOR INSERT
WITH CHECK (
  -- Admins can insert anything
  (auth.jwt() ->> 'role') = 'admin'

  OR

  -- If assigning lead to themselves
  owner_id = auth.uid()

  OR

  -- If assigning to a team they belong to
  EXISTS (
    SELECT 1
    FROM user_teams ut
    WHERE ut.user_id = auth.uid()
      AND ut.team_id = NEW.team_id
  )
);


-- Allow only admins to update leads
CREATE POLICY "allow_update_admin_only"
ON leads
FOR UPDATE
USING (
  (auth.jwt() ->> 'role') = 'admin'
)
WITH CHECK (
  (auth.jwt() ->> 'role') = 'admin'
);

-- Allow only admins to delete leads
CREATE POLICY "allow_delete_admin_only"
ON leads
FOR DELETE
USING (
  (auth.jwt() ->> 'role') = 'admin'
);
