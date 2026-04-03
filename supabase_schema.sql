-- Enable uuid-ossp extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Define Roles
CREATE TYPE user_role AS ENUM ('customer', 'admin', 'super_admin');
CREATE TYPE meal_type AS ENUM ('breakfast', 'lunch', 'dinner');
CREATE TYPE subscription_plan AS ENUM ('monthly', 'yearly');
CREATE TYPE delivery_status AS ENUM ('pending', 'dispatched', 'delivered', 'unable_to_deliver');
CREATE TYPE subscription_status AS ENUM ('pending_approval', 'payment_pending', 'active', 'paused', 'expired', 'rejected');

-- Profiles Table
CREATE TABLE profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  full_name TEXT,
  phone TEXT,
  address TEXT,
  landmark TEXT,
  pincode TEXT,
  area TEXT,
  role user_role DEFAULT 'customer',
  status TEXT DEFAULT 'pending', -- pending, active, suspended
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Function and Trigger to handle new users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, phone, address, landmark, pincode, area, role, status)
  VALUES (
    new.id, 
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'phone',
    new.raw_user_meta_data->>'address',
    new.raw_user_meta_data->>'landmark',
    new.raw_user_meta_data->>'pincode',
    new.raw_user_meta_data->>'area',
    -- Make the very first user an admin, others customer
    CASE WHEN (SELECT count(*) FROM public.profiles) = 0 THEN 'super_admin'::public.user_role ELSE 'customer'::public.user_role END,
    'pending'
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Subscriptions Table
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  plan_type subscription_plan,
  has_breakfast BOOLEAN DEFAULT FALSE,
  has_lunch BOOLEAN DEFAULT FALSE,
  has_dinner BOOLEAN DEFAULT FALSE,
  start_date DATE,
  breakfast_expiry DATE,
  lunch_expiry DATE,
  dinner_expiry DATE,
  status subscription_status DEFAULT 'pending_approval',
  parent_subscription_id UUID REFERENCES subscriptions(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Pause Logs Table
CREATE TABLE pause_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE CASCADE,
  meal_type meal_type,
  pause_start_date DATE,
  pause_end_date DATE,
  days_paused INT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Transactions Table
CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  amount DECIMAL(10, 2),
  type TEXT, -- new_subscription, renewal, refund, adjustment
  razorpay_payment_id TEXT,
  razorpay_order_id TEXT,
  status TEXT, -- success, failed, pending
  transaction_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Daily Deliveries Table
CREATE TABLE daily_deliveries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  delivery_date DATE,
  meal_type meal_type,
  status delivery_status DEFAULT 'pending',
  delivery_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  UNIQUE(customer_id, delivery_date, meal_type)
);

-- Application Settings
CREATE TABLE app_settings (
  id INT PRIMARY KEY DEFAULT 1,
  brand_name TEXT DEFAULT 'Saapadu Box',
  tag_line TEXT DEFAULT 'Taste of Home. In Every Bite.',
  logo_url TEXT,
  breakfast_price_monthly DECIMAL(10, 2) DEFAULT 1500.00,
  lunch_price_monthly DECIMAL(10, 2) DEFAULT 2000.00,
  dinner_price_monthly DECIMAL(10, 2) DEFAULT 2000.00,
  breakfast_price_yearly DECIMAL(10, 2) DEFAULT 15000.00,
  lunch_price_yearly DECIMAL(10, 2) DEFAULT 20000.00,
  dinner_price_yearly DECIMAL(10, 2) DEFAULT 20000.00,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Initialize default app settings
INSERT INTO app_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- Daily Expiration Job and Function
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

-- To enable the cron, you must have pg_cron enabled in your Supabase project settings.
-- Then run this separately:
-- SELECT cron.schedule('expire_daily_subscriptions_job', '0 0 * * *', $$ SELECT update_expired_subscriptions(); $$);

-- ============================================================================
-- PRODUCTION SECURITY: ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE pause_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- Helper function to check if user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- Profiles Policies
CREATE POLICY "Users can view their own profile or admins can view all" ON profiles
  FOR SELECT USING (auth.uid() = id OR public.is_admin());

CREATE POLICY "Users can update their own profile or admins can update all" ON profiles
  FOR UPDATE USING (auth.uid() = id OR public.is_admin());

-- Subscriptions Policies
CREATE POLICY "Users can view their own subs or admins view all" ON subscriptions
  FOR SELECT USING (auth.uid() = customer_id OR public.is_admin());

CREATE POLICY "Users can insert their own subs or admins insert all" ON subscriptions
  FOR INSERT WITH CHECK (auth.uid() = customer_id OR public.is_admin());

CREATE POLICY "Admins can update all subs" ON subscriptions
  FOR UPDATE USING (public.is_admin());

CREATE POLICY "Users can update their own subs" ON subscriptions
  FOR UPDATE USING (auth.uid() = customer_id);

-- Pause Logs Policies
CREATE POLICY "Users can view their own pause logs or admins view all" ON pause_logs
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM subscriptions s WHERE s.id = pause_logs.subscription_id AND s.customer_id = auth.uid()) 
    OR public.is_admin()
  );

CREATE POLICY "Users can insert their own pause logs" ON pause_logs
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM subscriptions s WHERE s.id = subscription_id AND s.customer_id = auth.uid()) 
    OR public.is_admin()
  );

-- Transactions Policies
CREATE POLICY "Users can view their own transactions or admins view all" ON transactions
  FOR SELECT USING (auth.uid() = customer_id OR public.is_admin());

CREATE POLICY "Users can insert their own transactions" ON transactions
  FOR INSERT WITH CHECK (auth.uid() = customer_id OR public.is_admin());

-- Daily Deliveries Policies
CREATE POLICY "Users can view their own deliveries or admins view all" ON daily_deliveries
  FOR SELECT USING (auth.uid() = customer_id OR public.is_admin());

CREATE POLICY "Admins can manage deliveries" ON daily_deliveries
  FOR ALL USING (public.is_admin());

-- App Settings Policies
CREATE POLICY "Anyone can view app settings" ON app_settings
  FOR SELECT USING (true);

CREATE POLICY "Only admins can update app settings" ON app_settings
  FOR UPDATE USING (public.is_admin());
