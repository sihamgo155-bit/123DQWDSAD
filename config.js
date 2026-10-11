/* Public client configuration only. Never place service_role keys or passwords here. */
window.CCP_CONFIG = {
  mode: "demo", // "demo" or "supabase"
  supabaseUrl: "", // e.g. https://YOUR_PROJECT.supabase.co
  supabaseAnonKey: "", // public anon/publishable key; protect data with RLS
  minExamScore: 70,
  allowRetake: true,
  allowReapply: true,
  applicationsOpen: true,
  showPublicStats: true
};
