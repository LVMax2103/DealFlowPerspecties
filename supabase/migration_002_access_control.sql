-- ============================================================
-- DealFlow Perspectives — Demo Access System
-- Run this ENTIRE script in Supabase SQL Editor
-- ============================================================

-- 1. DEMO REQUESTS TABLE
CREATE TABLE IF NOT EXISTS demo_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  name TEXT NOT NULL,
  request_type TEXT NOT NULL DEFAULT 'individual', -- 'individual' or 'institutional'
  company TEXT,
  company_url TEXT,
  num_accounts INTEGER,
  industry TEXT,
  country TEXT,
  role_title TEXT,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, approved, rejected, expired
  approved_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(email)
);

-- 2. DEMO SURVEYS TABLE
CREATE TABLE IF NOT EXISTS demo_surveys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  email TEXT NOT NULL,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  sections_used TEXT[] DEFAULT '{}',
  desired_data TEXT,
  comments TEXT,
  privacy_accepted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. ADMIN ACCOUNTS TABLE (never-expiring accounts)
CREATE TABLE IF NOT EXISTS admin_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  codename TEXT NOT NULL, -- 'TRON', 'CLU'
  role TEXT NOT NULL DEFAULT 'developer', -- 'developer', 'admin'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert TRON (developer account)
INSERT INTO admin_accounts (email, codename, role)
VALUES ('elenesmaximiliano@gmail.com', 'TRON', 'developer')
ON CONFLICT (email) DO NOTHING;

-- 4. DISPOSABLE EMAIL DOMAINS TABLE
CREATE TABLE IF NOT EXISTS blocked_email_domains (
  id SERIAL PRIMARY KEY,
  domain TEXT NOT NULL UNIQUE
);

-- Insert common disposable email domains
INSERT INTO blocked_email_domains (domain) VALUES
  ('tempmail.com'), ('throwaway.email'), ('guerrillamail.com'), ('guerrillamail.de'),
  ('yopmail.com'), ('yopmail.fr'), ('mailinator.com'), ('mailinator.net'),
  ('10minutemail.com'), ('10minmail.com'), ('temp-mail.org'), ('temp-mail.io'),
  ('fakeinbox.com'), ('sharklasers.com'), ('guerrillamailblock.com'), ('grr.la'),
  ('dispostable.com'), ('trashmail.com'), ('trashmail.me'), ('trashmail.net'),
  ('maildrop.cc'), ('mailnesia.com'), ('tempail.com'), ('tempr.email'),
  ('discard.email'), ('discardmail.com'), ('discardmail.de'), ('dropsmail.com'),
  ('emailondeck.com'), ('33mail.com'), ('maildrop.cc'), ('getnada.com'),
  ('mohmal.com'), ('burnermail.io'), ('inboxkitten.com'), ('mailsac.com'),
  ('harakirimail.com'), ('crazymailing.com'), ('tmail.ws'), ('tempmailo.com'),
  ('emailfake.com'), ('generator.email'), ('emkei.cz'), ('receivemail.com'),
  ('tempinbox.com'), ('binkmail.com'), ('spamdecoy.net'), ('spamgourmet.com'),
  ('trashymail.com'), ('mailexpire.com'), ('jetable.org'), ('trash-mail.com'),
  ('mytemp.email'), ('tempmailaddress.com'), ('tmpmail.net'), ('tmpmail.org'),
  ('tempmails.com'), ('getairmail.com'), ('meltmail.com'), ('spamfree24.org')
ON CONFLICT (domain) DO NOTHING;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE demo_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE demo_surveys ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocked_email_domains ENABLE ROW LEVEL SECURITY;

-- Anyone can INSERT a demo request (they're submitting the form)
CREATE POLICY "Anyone can submit demo request"
  ON demo_requests FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Only the requester can read their own request (by email match)
CREATE POLICY "Users read own request"
  ON demo_requests FOR SELECT
  TO authenticated
  USING (email = (SELECT email FROM auth.users WHERE id = auth.uid()));

-- Authenticated users can insert surveys
CREATE POLICY "Authenticated users can submit survey"
  ON demo_surveys FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can read their own survey
CREATE POLICY "Users read own survey"
  ON demo_surveys FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Admin accounts readable by authenticated users (to check if they're admin)
CREATE POLICY "Authenticated users can check admin status"
  ON admin_accounts FOR SELECT
  TO authenticated
  USING (true);

-- Blocked domains readable by anyone (needed for form validation)
CREATE POLICY "Anyone can read blocked domains"
  ON blocked_email_domains FOR SELECT
  TO anon, authenticated
  USING (true);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_demo_requests_email ON demo_requests(email);
CREATE INDEX IF NOT EXISTS idx_demo_requests_status ON demo_requests(status);
CREATE INDEX IF NOT EXISTS idx_admin_accounts_email ON admin_accounts(email);
CREATE INDEX IF NOT EXISTS idx_blocked_domains ON blocked_email_domains(domain);
