-- 1. Create Role
CREATE ROLE dbz_da WITH LOGIN PASSWORD 'debezium123!'
GRANT CONNECT ON DATABASE dsa TO dbz_da;
GRANT USAGE ON SCHEMA public TO dbz_da;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO dbz_da;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO dbz_da;

-- 2. Check Role
SELECT
  member.rolname AS member,
  role.rolname   AS granted_role
FROM pg_auth_members m
JOIN pg_roles role   ON role.oid = m.roleid
JOIN pg_roles member ON member.oid = m.member
WHERE member.rolname = 'dbz_da';