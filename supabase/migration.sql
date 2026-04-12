-- ============================================================
-- DealFlow Perspectives — Supabase Schema Migration
-- Run this ENTIRE script in Supabase SQL Editor (https://supabase.com/dashboard → SQL Editor)
-- ============================================================

-- 1. DEALS TABLE
CREATE TABLE IF NOT EXISTS deals (
  id SERIAL PRIMARY KEY,
  deal_name TEXT NOT NULL,
  category TEXT,
  investor_buyer TEXT,
  target_company TEXT,
  country TEXT,
  sector TEXT,
  deal_value_usd_m NUMERIC,
  local_currency TEXT,
  notes TEXT,
  period TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. PLAYERS TABLE
CREATE TABLE IF NOT EXISTS players (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  aum_display TEXT,
  aum_numeric NUMERIC,
  active_funds INTEGER,
  total_funds INTEGER,
  active_holdings INTEGER,
  total_holdings INTEGER,
  addresses INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. PE FUNDS TABLE
CREATE TABLE IF NOT EXISTS pe_funds (
  id SERIAL PRIMARY KEY,
  fund TEXT NOT NULL,
  gp TEXT,
  vintage INTEGER,
  size TEXT,
  status TEXT,
  irr NUMERIC,
  quartile TEXT,
  countries TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. USER PREFERENCES TABLE (dashboard layout, market favorites)
CREATE TABLE IF NOT EXISTS user_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  panel_layout JSONB DEFAULT '{}',
  market_favorites TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- ============================================================
-- ROW LEVEL SECURITY — Only authenticated users can read data
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE deals ENABLE ROW LEVEL SECURITY;
ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE pe_funds ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

-- Deals: authenticated users can SELECT
CREATE POLICY "Authenticated users can read deals"
  ON deals FOR SELECT
  TO authenticated
  USING (true);

-- Players: authenticated users can SELECT
CREATE POLICY "Authenticated users can read players"
  ON players FOR SELECT
  TO authenticated
  USING (true);

-- PE Funds: authenticated users can SELECT
CREATE POLICY "Authenticated users can read pe_funds"
  ON pe_funds FOR SELECT
  TO authenticated
  USING (true);

-- User Preferences: users can only access their own row
CREATE POLICY "Users can read own preferences"
  ON user_preferences FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own preferences"
  ON user_preferences FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own preferences"
  ON user_preferences FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- INDEXES for performance
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_deals_category ON deals(category);
CREATE INDEX IF NOT EXISTS idx_deals_country ON deals(country);
CREATE INDEX IF NOT EXISTS idx_deals_value ON deals(deal_value_usd_m DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_players_name ON players(name);
CREATE INDEX IF NOT EXISTS idx_players_aum ON players(aum_numeric DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_pe_funds_irr ON pe_funds(irr DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_pe_funds_gp ON pe_funds(gp);
CREATE INDEX IF NOT EXISTS idx_user_prefs_user ON user_preferences(user_id);
