-- Row-level security on the shared orders table of donhang_tenancy.
-- scripts/backend/row-level-security.sh runs this file before each demo; it
-- can run again and again. Đơn Hàng's own database has no policies.

-- donhang owns the tables and is a superuser (the PostgreSQL image creates
-- POSTGRES_USER that way), so no policy applies to it. The demo switches to
-- shop_app, a role that only has rights on the tables. A role belongs to
-- the whole server; NOLOGIN: only SET ROLE from donhang reaches it.
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'shop_app') THEN
        CREATE ROLE shop_app NOLOGIN;
    END IF;
END
$$;
GRANT SELECT, INSERT, UPDATE, DELETE ON orders, customers TO shop_app;

-- lesson: backend.l3.row-level-security
-- Every query shop_app sends to orders gets this USING condition added.
-- current_setting(..., true) gives null when app.shop_id was never set,
-- and '' after a SET LOCAL has ended; NULLIF turns '' into null too. Either
-- way shop_id = null is never true, so no rows: not every shop's rows.
-- With no WITH CHECK, a new or changed row must pass USING as well.
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS orders_of_current_shop ON orders;
CREATE POLICY orders_of_current_shop ON orders
    FOR ALL
    USING (shop_id = NULLIF(current_setting('app.shop_id', true), '')::integer);
