// Supabase project the till talks to (Supabase dashboard -> Project Settings -> API).
// The publishable/anon key is meant to be public: the database rules in supabase/schema.sql
// decide what each signed-in account can do. Never put the secret/service_role key here.
window.BAR_CONFIG = {
  supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
  supabaseKey: 'YOUR_PUBLISHABLE_KEY'
};
