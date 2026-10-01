/* Public website settings. Everything in this file is visible to every visitor, so it must only ever
 * hold PUBLIC values.
 *
 *   supabaseUrl      your project URL, e.g. "https://abcdxyz.supabase.co"
 *   supabaseAnonKey  the project's PUBLIC key: the "anon" key (a long eyJ... string) or the newer
 *                    "publishable" key (sb_publishable_...). It is designed to be public; what it may do is
 *                    limited by the Row Level Security rules in supabase/feedback_schema.sql.
 *
 * NEVER paste the "service_role" key or a "secret" key (sb_secret_...) here or anywhere in this repository:
 * it bypasses every protection. Leave both values empty to switch feedback off: the site then shows
 * "feedback is temporarily unavailable" and works normally. Setup steps: docs/FEEDBACK_BACKEND.md
 */
window.VG_CONFIG = {
  supabaseUrl: "",
  supabaseAnonKey: "",
  attachmentsBucket: "feedback-attachments"
};
