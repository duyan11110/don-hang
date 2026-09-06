-- "Orders per day" is not one question. It is one question per time zone.

-- lesson: foundation.l1.time-and-timezones
SELECT date(placed_at AT TIME ZONE 'UTC')              AS day_utc,
       date(placed_at AT TIME ZONE 'Asia/Ho_Chi_Minh') AS day_vietnam,
       count(*) AS orders
FROM orders
GROUP BY day_utc, day_vietnam
ORDER BY day_utc;

-- The two orders that fall on different days are the ones placed in the early
-- morning Vietnam time, which is still the previous day in UTC.
SELECT id,
       placed_at AT TIME ZONE 'UTC'              AS at_utc,
       placed_at AT TIME ZONE 'Asia/Ho_Chi_Minh' AS at_vietnam
FROM orders
WHERE date(placed_at AT TIME ZONE 'UTC')
   <> date(placed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')
ORDER BY id;
