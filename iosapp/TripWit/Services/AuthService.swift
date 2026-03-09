import Foundation
import GoogleSignIn
import Supabase
import os

@Observable
@MainActor
final class AuthService {

    private(set) var isSignedIn = false
    private(set) var userEmail: String?
    private(set) var userId: String? // Supabase auth.users UUID string
    private(set) var isLoading = false

    private(set) var supabase: SupabaseClient?

    /// Whether Supabase credentials are configured (non-placeholder values).
    var isConfigured: Bool { supabase != nil }

    private let log = Logger(subsystem: "com.kevinbuckley.travelplanner", category: "Auth")

    init() {
        let url = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
        let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""

        // Only create the client if real credentials are configured
        if !key.isEmpty, key != "PLACEHOLDER", let supabaseURL = URL(string: url), !url.isEmpty {
            self.supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: key)
        } else {
            self.supabase = nil
            log.warning("Supabase not configured — sync disabled")
        }

        if supabase != nil {
            Task { await restoreSession() }
        }
    }

    // MARK: - Sign In

    func signInWithGoogle() async {
        guard let supabase else {
            log.error("Supabase not configured — cannot sign in")
            return
        }

        isLoading = true
        defer { isLoading = false }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first?.rootViewController else {
            log.error("No root view controller for Google Sign-In")
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                log.error("No ID token from Google Sign-In")
                return
            }

            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(provider: .google, idToken: idToken)
            )

            self.userId = session.user.id.uuidString
            self.userEmail = session.user.email
            self.isSignedIn = true
            log.info("Signed in as \(session.user.email ?? "unknown")")
        } catch {
            log.error("Sign-in failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        if let supabase {
            do {
                try await supabase.auth.signOut()
            } catch {
                log.error("Supabase sign-out failed: \(error.localizedDescription)")
            }
        }
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        userId = nil
        userEmail = nil
    }

    // MARK: - Delete Account

    /// Deletes all user data from Supabase, signs out from Supabase and Google.
    /// Required by App Store Guideline 5.1.1(v) — apps with account creation must offer deletion.
    func deleteAccount(dataService: SupabaseDataServiceProtocol?) async throws {
        if let dataService, let uid = userId {
            try await dataService.deleteAllTrips(userId: uid)
            log.info("Deleted all Supabase data for user \(uid)")
        }
        await signOut()
    }

    // MARK: - Session Restore

    private func restoreSession() async {
        guard let supabase else { return }
        do {
            let session = try await supabase.auth.session
            self.userId = session.user.id.uuidString
            self.userEmail = session.user.email
            self.isSignedIn = true
            log.info("Restored session for \(session.user.email ?? "unknown")")
        } catch {
            // No existing session — user is not signed in
            self.isSignedIn = false
        }
    }
}
