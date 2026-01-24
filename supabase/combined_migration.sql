/*
  Combined Migration Script
  Generated from:
  1. 20260123160045_create_pick_sessions.sql
  2. 20260124000000_secure_picking.sql
*/

-- ==========================================
-- Part 1: Initial Schema Setup
-- ==========================================

CREATE TABLE IF NOT EXISTS pick_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shuffled_order jsonb NOT NULL,
  picked_index integer,
  picked_name text,
  created_at timestamptz DEFAULT now(),
  picked_at timestamptz
);

ALTER TABLE pick_sessions ENABLE ROW LEVEL SECURITY;

-- Note: The following policies are from the original schema but will be superseded
-- by the revocation in Part 2. We keep them here for historical completeness if
-- this script is meant to represent the full history, but effectively they are disabled
-- for 'anon' by the REVOKE command later.

DROP POLICY IF EXISTS "Anyone can create sessions" ON pick_sessions;
CREATE POLICY "Anyone can create sessions"
  ON pick_sessions
  FOR INSERT
  TO anon
  WITH CHECK (true);

DROP POLICY IF EXISTS "Anyone can read sessions by ID" ON pick_sessions;
CREATE POLICY "Anyone can read sessions by ID"
  ON pick_sessions
  FOR SELECT
  TO anon
  USING (true);

DROP POLICY IF EXISTS "Anyone can update sessions" ON pick_sessions;
CREATE POLICY "Anyone can update sessions"
  ON pick_sessions
  FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_pick_sessions_created_at ON pick_sessions(created_at);

-- ==========================================
-- Part 2: Secure Picking Implementation
-- ==========================================

-- Create names table to store the pool of names
CREATE TABLE IF NOT EXISTS names (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Ensure unique constraint on name to prevent duplicates
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'names_name_key'
  ) THEN
    ALTER TABLE names ADD CONSTRAINT names_name_key UNIQUE (name);
  END IF;
END
$$;

-- Seed initial names
INSERT INTO names (name)
VALUES
  ('Alex Morgan'), ('Jordan Chen'), ('Taylor Swift'), ('Casey Johnson'),
  ('Riley Parker'), ('Morgan Davis'), ('Jamie Wilson'), ('Avery Brown'),
  ('Quinn Martinez'), ('Drew Anderson'), ('Sage Thompson'), ('River Garcia')
ON CONFLICT (name) DO NOTHING;

-- Secure the pick_sessions table
-- We revoke direct access to anon to prevent peeking at shuffled_order
REVOKE ALL ON pick_sessions FROM anon;
REVOKE ALL ON names FROM anon;

-- Function to create a new session with server-side shuffle
DROP FUNCTION IF EXISTS create_pick_session();
CREATE OR REPLACE FUNCTION create_pick_session()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_session_id uuid;
  name_list text[];
BEGIN
  -- Get names shuffled randomly
  SELECT array_agg(name ORDER BY random())
  INTO name_list
  FROM names;

  IF name_list IS NULL THEN
    RAISE EXCEPTION 'No names found in database. Please seed the names table.';
  END IF;

  -- Create session
  INSERT INTO pick_sessions (shuffled_order)
  VALUES (to_jsonb(name_list))
  RETURNING id INTO new_session_id;

  RETURN new_session_id;
END;
$$;

-- Grant execute to anon
GRANT EXECUTE ON FUNCTION create_pick_session TO anon;

DROP FUNCTION IF EXISTS get_pick_session_info(uuid);
-- Function to get session info without revealing the full order
CREATE OR REPLACE FUNCTION get_pick_session_info(session_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  session_record pick_sessions%ROWTYPE;
BEGIN
  SELECT * INTO session_record
  FROM pick_sessions
  WHERE id = session_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  RETURN json_build_object(
    'id', session_record.id,
    'picked_index', session_record.picked_index,
    'picked_name', session_record.picked_name,
    'total_boxes', jsonb_array_length(session_record.shuffled_order)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_pick_session_info TO anon;

-- Function to make a pick
DROP FUNCTION IF EXISTS make_pick(uuid, integer);
CREATE OR REPLACE FUNCTION make_pick(session_id uuid, pick_idx integer)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  session_record pick_sessions%ROWTYPE;
  picked_val text;
  total_len int;
BEGIN
  -- Lock the row to prevent race conditions
  SELECT * INTO session_record
  FROM pick_sessions
  WHERE id = session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Session not found';
  END IF;

  -- Check if already picked
  IF session_record.picked_index IS NOT NULL THEN
    RAISE EXCEPTION 'Already picked';
  END IF;

  total_len := jsonb_array_length(session_record.shuffled_order);
  
  -- Validate index
  IF pick_idx < 0 OR pick_idx >= total_len THEN
     RAISE EXCEPTION 'Invalid index';
  END IF;

  -- Get the name at the index
  picked_val := session_record.shuffled_order->>pick_idx;

  -- Update the session
  UPDATE pick_sessions
  SET picked_index = pick_idx,
      picked_name = picked_val,
      picked_at = now()
  WHERE id = session_id;

  -- Return the result
  RETURN json_build_object(
    'id', session_id,
    'picked_index', pick_idx,
    'picked_name', picked_val,
    'total_boxes', total_len
  );
END;
$$;

GRANT EXECUTE ON FUNCTION make_pick TO anon;
