-- ============================================================================
-- 1. CREATE MISSING TYPES AND TABLES (Safe for existing databases)
-- ============================================================================

DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('customer', 'admin', 'super_admin');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE meal_type AS ENUM ('breakfast', 'lunch', 'dinner');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE subscription_plan AS ENUM ('monthly', 'yearly');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE delivery_status AS ENUM ('pending', 'dispatched', 'delivered', 'unable_to_deliver');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE subscription_status AS ENUM ('pending_approval', 'payment_pending', 'active', 'paused', 'expired', 'rejected');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;CREATE TABLE IF NOT EXISTS pause_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE CASCADE,
  meal_type meal_type,
  pause_start_date DATE,
  pause_end_date DATE,
  days_paused INT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS daily_deliveries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  delivery_date DATE,
  meal_type meal_type,
  status delivery_status DEFAULT 'pending',
  delivery_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  UNIQUE(customer_id, delivery_date, meal_type)
);

CREATE TABLE IF NOT EXISTS app_settings (
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

INSERT INTO app_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 2. PRODUCTION SECURITY: ROW LEVEL SECURITY (RLS) POLICIES
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
