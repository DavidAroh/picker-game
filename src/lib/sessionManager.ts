import { supabase, PickSession } from './supabase';

const SESSION_KEY = 'pick_one_box_session_id';

export async function getOrCreateSession(): Promise<PickSession> {
  const existingSessionId = localStorage.getItem(SESSION_KEY);

  if (existingSessionId) {
    const { data, error } = await supabase
      .rpc('get_pick_session_info', { session_id: existingSessionId });

    if (!error && data) {
      return data as PickSession;
    }
    // If error (e.g. session not found), remove invalid ID and create new one
    console.warn('Invalid session found, creating new one', error);
    localStorage.removeItem(SESSION_KEY);
  }

  // Create new session
  const { data: newSessionId, error: createError } = await supabase
    .rpc('create_pick_session');

  if (createError || !newSessionId) {
    console.error('Create session error:', createError);
    throw new Error(`Failed to create session: ${createError?.message || 'Unknown error'}`);
  }

  localStorage.setItem(SESSION_KEY, newSessionId as string);

  // Get session info
  const { data, error: fetchError } = await supabase
    .rpc('get_pick_session_info', { session_id: newSessionId });

  if (fetchError || !data) {
    console.error('Fetch session error:', fetchError);
    throw new Error('Failed to load new session');
  }

  return data as PickSession;
}

export async function makePick(pickIndex: number, session: PickSession): Promise<PickSession> {
  const { data, error } = await supabase
    .rpc('make_pick', { 
      session_id: session.id, 
      pick_idx: pickIndex 
    });

  if (error) {
    console.error('Make pick error:', error);
    throw new Error('Failed to save pick');
  }

  return data as PickSession;
}
