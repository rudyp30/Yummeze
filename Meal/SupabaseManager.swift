import Foundation
import OSLog
import Supabase

private let log = Logger(subsystem: "rudy.Meal", category: "Supabase")

/// The app's single Supabase client (supabase-swift 2.53.0). Stage A is
/// foundation only — configured + reachable. No auth, reads, or writes are
/// wired yet; those come in Stage B onward. All config lives in `SupabaseConfig`.
enum SupabaseManager {
    /// One shared, configured client for the whole app.
    static let shared = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey
    )

    /// Lightweight, unauthenticated connectivity probe. Any response from the
    /// server — including a 404/RLS/permission error — proves the client reached
    /// Supabase and security is working; only a transport error is a real
    /// failure. Logs the outcome; no UI is built around it.
    static func logConnectivityCheck() async {
        do {
            _ = try await shared
                .from("__connectivity_check")
                .select()
                .limit(1)
                .execute()
            log.notice("Reachable — probe query returned without error.")
        } catch let urlError as URLError {
            log.error("NOT reachable — transport error: \(urlError.code.rawValue, privacy: .public) \(urlError.localizedDescription, privacy: .public)")
        } catch {
            log.notice("Reachable — server responded (expected error for the probe, which proves connectivity): \(String(describing: error), privacy: .public)")
        }
    }
}
