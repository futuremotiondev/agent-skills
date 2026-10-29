-- Returns users.
CREATE OR REPLACE FUNCTION get_users(p_limit int) RETURNS SETOF users AS $$
  SELECT * FROM users LIMIT p_limit;
$$ LANGUAGE sql;

CREATE PROCEDURE dbo.Archive @days INT AS BEGIN DELETE FROM logs; END;
CREATE TRIGGER trg_audit AFTER INSERT ON users FOR EACH ROW EXECUTE FUNCTION audit();
CREATE VIEW active_users AS SELECT * FROM users;
