-- Enable RLS
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;

-- SELECT: admin OR owner
CREATE POLICY select_leads_admin_owner ON leads
FOR SELECT
USING (
  (auth.jwt() ->> 'role') = 'admin'
  OR owner_id = auth.uid()
);

-- INSERT: admin OR assigning to self
CREATE POLICY insert_leads_admin_owner ON leads
FOR INSERT
WITH CHECK (
  (auth.jwt() ->> 'role') = 'admin'
  OR owner_id = auth.uid()
);

-- UPDATE: admin only
CREATE POLICY update_leads_admin_only ON leads
FOR UPDATE
USING ((auth.jwt() ->> 'role') = 'admin')
WITH CHECK ((auth.jwt() ->> 'role') = 'admin');

-- DELETE: admin only
CREATE POLICY delete_leads_admin_only ON leads
FOR DELETE
USING ((auth.jwt() ->> 'role') = 'admin');
