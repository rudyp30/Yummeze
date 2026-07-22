import Foundation

/// Single source of truth for the Supabase backend connection.
///
/// The anon/public key is safe to ship in the client — it's public by design and
/// Row Level Security is what actually protects the data. NEVER put the
/// `service_role` key in the app.
enum SupabaseConfig {
    static let url = URL(string: "https://vfpkghixjtbkvndujamv.supabase.co")!

    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmcGtnaGl4anRia3ZuZHVqYW12Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ2NTI5MjgsImV4cCI6MjEwMDIyODkyOH0.3x0pHE7UytI9fhNxD01caFofOtin6GZ-yDhIyJgs-fU"
}
