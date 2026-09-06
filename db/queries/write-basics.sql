-- Change data on purpose. Everything here runs inside a transaction that is
-- rolled back at the end, so the lab data is the same after you run it.
SET TIME ZONE 'Asia/Ho_Chi_Minh';
BEGIN;

-- Look before you change: run the SELECT with the WHERE you are about to use.
SELECT id, name, price_vnd FROM products WHERE price_vnd < 500000;

-- lesson: foundation.l1.sql-write
INSERT INTO products (name, price_vnd)
VALUES ('Túi đựng laptop', 390000)
RETURNING id, name, price_vnd;

UPDATE products
SET price_vnd = 300000
WHERE name = 'Giá đỡ laptop';

DELETE FROM products
WHERE name = 'Túi đựng laptop';

ROLLBACK;

-- A foreign key refuses to leave orders pointing at a customer who is gone.
-- The block below catches the refusal and prints it instead of stopping.
DO $$
BEGIN
    DELETE FROM customers WHERE id = 1;
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'the database refused: %', SQLERRM;
END;
$$;

SELECT count(*) AS products_after_rollback FROM products;

-- The rollback undid the rows, but a sequence never goes backwards. Put it
-- back, so that running this file again prints exactly the same thing.
SELECT setval(pg_get_serial_sequence('products', 'id'), 8);
