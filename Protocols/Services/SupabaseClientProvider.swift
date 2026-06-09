import Foundation
import Supabase

enum SupabaseClientProvider {
    static let redirectURL = URL(string: "protocols://auth-callback")!

    static func makeClient() throws -> SupabaseClient {
        let configuration = try SupabaseRuntimeConfiguration.load()

        return SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.anonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: KeychainLocalStorage(service: "com.kevinshah.Protocols.supabase"),
                    redirectToURL: redirectURL,
                    autoRefreshToken: true,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}

struct SupabaseRuntimeConfiguration {
    let url: URL
    let anonKey: String

    static func load(bundle: Bundle = .main) throws -> SupabaseRuntimeConfiguration {
        guard let rawURL = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              !rawURL.contains("YOUR-PROJECT-REF"),
              let url = URL(string: rawURL),
              url.host != nil else {
            throw SupabaseConfigurationError.missingURL
        }

        guard let anonKey = bundle.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
              !anonKey.contains("YOUR-SUPABASE-ANON-KEY"),
              anonKey.count > 20 else {
            throw SupabaseConfigurationError.missingAnonKey
        }

        return SupabaseRuntimeConfiguration(url: url, anonKey: anonKey)
    }
}

enum SupabaseConfigurationError: LocalizedError {
    case missingURL
    case missingAnonKey

    var errorDescription: String? {
        switch self {
        case .missingURL:
            "Add your Supabase project URL to Protocols/Config/Supabase.xcconfig using the escaped form https:/$()/YOUR-PROJECT-REF.supabase.co."
        case .missingAnonKey:
            "Add your Supabase anon key to Protocols/Config/Supabase.xcconfig."
        }
    }
}
