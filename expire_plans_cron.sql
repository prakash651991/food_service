-- Daily Expiration Job and Function

-- 1. Create the function that sweeps for expired plans
CREATE OR REPLACE FUNCTION update_expired_subscriptions()
RETURNS void AS $$
BEGIN
  UPDATE subscriptions
  SET status = 'expired'
  WHERE status IN ('active', 'paused')
  AND (
      GREATEST(
          COALESCE(breakfast_expiry, '2000-01-01'::date),
          COALESCE(lunch_expiry, '2000-01-01'::date),
          COALESCE(dinner_expiry, '2000-01-01'::date)
      ) < CURRENT_DATE
  );
END;
$$ LANGUAGE plpgsql;

-- 2. (Optional but Recommended) Enable the pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 3. Schedule the function to run automatically every night at 12:00 AM (Midnight)
SELECT cron.schedule(
  'expire_daily_subscriptions_job',
  '0 0 * * *', -- Everyday at midnight
  $$ SELECT update_expired_subscriptions(); $$
);
