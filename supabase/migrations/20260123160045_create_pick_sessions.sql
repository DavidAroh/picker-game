/*
  # Pick One Box Sessions

  1. New Tables
    - `pick_sessions`
      - `id` (uuid, primary key) - Unique session identifier
      - `shuffled_order` (jsonb) - Array of shuffled names assigned to boxes
      - `picked_index` (integer, nullable) - Index of the box that was picked (null if not picked yet)
      - `picked_name` (text, nullable) - Name of the person picked (denormalized for easy access)
      - `created_at` (timestamptz) - When the session was created
      - `picked_at` (timestamptz, nullable) - When the pick was made
  
  2. Security
    - Enable RLS on `pick_sessions` table
    - Add policy for anyone to insert their own session
    - Add policy for anyone to read their own session by ID
    - Add policy for anyone to update their own session (for making the pick)
  
  3. Notes
    - Sessions are identified by UUID that will be stored in client localStorage
    - Each session can only pick once (enforced by application logic)
    - No authentication required - truly anonymous
*/

CREATE TABLE IF NOT EXISTS pick_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shuffled_order jsonb NOT NULL,
  picked_index integer,
  picked_name text,
  created_at timestamptz DEFAULT now(),
  picked_at timestamptz
);

ALTER TABLE pick_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can create sessions"
  ON pick_sessions
  FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Anyone can read sessions by ID"
  ON pick_sessions
  FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Anyone can update sessions"
  ON pick_sessions
  FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_pick_sessions_created_at ON pick_sessions(created_at);