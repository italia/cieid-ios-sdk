import Foundation
import LocalAuthentication




class CryptoManager {
    static var shared = CryptoManager()
    struct KeyPair {
        static let manager: EllipticCurveKeyPair.Manager = {
            let publicAccessControl = EllipticCurveKeyPair.AccessControl(protection: kSecAttrAccessibleAlways, flags: [])
            let privateAccessControl = EllipticCurveKeyPair.AccessControl(protection: kSecAttrAccessibleAlways, flags: [])
            let config = EllipticCurveKeyPair.Config(
                publicLabel: "payment.sign.public",
                privateLabel: "payment.sign.private",
                operationPrompt: "Confirm payment",
                publicKeyAccessControl: publicAccessControl,
                privateKeyAccessControl: privateAccessControl,
                token: .keychain)
            return EllipticCurveKeyPair.Manager(config: config)
        }()
    }
    
    final func getPublicKey() -> String? {
        do {
            let pKey = try KeyPair.manager.publicKey()
            let pKeyString = try pKey.data().raw.base64EncodedString()
            return pKeyString
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    
    final func encrypt(with message: String) -> String? {
        do {
            let data = message.data(using: .utf8)
            let encrpypted = try KeyPair.manager.encrypt(data!,hash: .sha256)
            return data?.base64EncodedString()
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    final func decrtypt(with message: String, context: LAContext) -> String? {
        do {
            let data = Data(base64Encoded: message)
            let dec = try KeyPair.manager.decrypt(data!,hash: .sha256,context: context)
            guard let s =  String(data: dec, encoding: .utf8) else { return nil }
            return s
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    final func removeKeys() -> Bool{
        do {
            try KeyPair.manager.deleteKeyPair()
            return true
        }
        catch {
            print(error.localizedDescription)
            return false
        }
    }
}
