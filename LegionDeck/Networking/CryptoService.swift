import Foundation
import CryptoKit

/// End-to-End Encryption utility for LegionDeck WebSocket payloads.
/// Relies on a pre-shared 32-byte key entered by the user in Settings.
class CryptoService {
    static let shared = CryptoService()
    
    private init() {}
    
    /// Retrieves the 32-byte secret key from UserDefaults.
    /// Falls back to the default key if not set.
    private var secretKey: SymmetricKey {
        let keyString = UserDefaults.standard.string(forKey: "encryption_key") ?? "LegionDeck_SecretKey_32_Bytes!!!"
        // Ensure it's exactly 32 bytes (pad or truncate if necessary)
        var keyData = keyString.data(using: .utf8) ?? Data()
        if keyData.count > 32 {
            keyData = keyData.prefix(32)
        } else if keyData.count < 32 {
            keyData.append(Data(repeating: 0, count: 32 - keyData.count))
        }
        return SymmetricKey(data: keyData)
    }
    
    /// Encrypts a string payload into a Base64 string.
    func encrypt(_ text: String) -> String? {
        guard let data = text.data(using: .utf8) else { return nil }
        do {
            let sealedBox = try AES.GCM.seal(data, using: secretKey)
            // combined = nonce (12) + ciphertext + tag (16)
            guard let combined = sealedBox.combined else { return nil }
            return combined.base64EncodedString()
        } catch {
            DebugLogger.shared.log("🔒 Encryption error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Decrypts a Base64 string payload back into a string.
    func decrypt(_ b64Text: String) -> String? {
        guard let combinedData = Data(base64Encoded: b64Text) else { return nil }
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: secretKey)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
