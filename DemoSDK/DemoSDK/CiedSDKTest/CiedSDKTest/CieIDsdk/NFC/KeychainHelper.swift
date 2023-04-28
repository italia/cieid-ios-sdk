import Security
import LocalAuthentication

let NIS_CIE_Cognome : String = "Cognome"
let NIS_CIE_Nome : String = "Nome"
let NIS_CIE_Cert : String = "Certificate"
let NIS_CIE_HalfPIN : String = "HalfPIN"
let NIS_CIE_SecondHalfPIN : String = "SecondHalfPIN"

public class KeychainHelper {
    
    public class func saveData(nis: String?, data: Data?, forKey: String?, clazz: String?) -> Bool {
        if nis == nil || data == nil || forKey == nil || clazz == nil {
            return false
        }
        
        //print("save " + forKey!)
        
        var query = [
            kSecClass : clazz!,
            kSecAttrAccount: nis!,
            kSecAttrService : forKey!,
            kSecValueData : data!,
            ] as [String : Any]
        
        //Se sto salvando un dato biometrico aggiungo un SecAccessControl adeguato
        if (forKey == NIS_CIE_SecondHalfPIN){
            query[kSecAttrAccessControl as String] = SecAccessControlCreateWithFlags(nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil)
        }

        SecItemDelete(query as CFDictionary)

        let status: OSStatus = SecItemAdd(query as CFDictionary, nil)
        
        /*
        print("saved: ")
        print((status == noErr))
        */
        
        //Se sto salvando un dato biometrico lo salvo nell'UserDefault
        if (forKey == NIS_CIE_SecondHalfPIN){
                   self.addBiometricNis(nis: nis)
        }
        
        return status == noErr
        
    }
    
    private class func saveCertData(nis: String?, data: Data?, forKey: String?, clazz: String?) -> Bool {
        if nis == nil || data == nil || forKey == nil || clazz == nil {
            return false
        }
                
        //print("save " + forKey!)
        
        let secCert = SecCertificateCreateWithData(nil, data! as CFData)
        
        let query = [
            kSecClass : clazz!,
            kSecAttrLabel: nis!,
            kSecValueRef : secCert!
            ] as [String : Any]

        SecItemDelete(query as CFDictionary)

        let status: OSStatus = SecItemAdd(query as CFDictionary, nil)

        /*
        print("saved: ")
        print((status == noErr))
        */
        
        return status == noErr
    }
    
    public class func getRegisteredNIS() -> Array<String>?
    {
        if let nisarray = UserDefaults.standard.array(forKey: "regnis")
        {
            return nisarray as? Array<String>
        }
        else
        {
            return nil
        }
    }
    
    public class func getRegisteredProcedureIDForPUK() -> String?
    {
        if let procedureIDForPUK = UserDefaults.standard.string(forKey: "procedureID")
        {
            return procedureIDForPUK
        }
        else
        {
            return nil
        }
    }
    
    public class func load(nis: String?, key: String?, clazz: String?) -> Data? {
        
        if nis == nil || key == nil || clazz == nil {
            return nil
        }
        
        //print("load " + key!)
        
        let query: [String: Any] = [kSecClass as String: clazz!,
                                    kSecAttrAccount as String: nis!,
                                    kSecAttrService as String: key!,
                                    kSecReturnData as String: true]
                
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        
        if let retrievedData = item as? Data {
            return retrievedData
        }
        else
        {
            // NOT FOUND
            return nil;
        }

    }
    
    public class func loadBiometricData(context: LAContext?, nis: String?, key: String?, clazz: String?) -> (Data?) {
            
            if nis == nil || key == nil || clazz == nil {
                return nil
            }
                
            var query: [String: Any] = [
                kSecClass as String       : clazz!,
                kSecAttrAccount as String: nis!,
                kSecAttrService as String: key!,
                kSecReturnData as String  : kCFBooleanTrue!,
                kSecAttrAccessControl as String: SecAccessControlCreateWithFlags(nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryCurrentSet,
                nil),
                kSecMatchLimit as String  : kSecMatchLimitOne ]
            
            if let context = context {
                query[kSecUseAuthenticationContext as String] = context
                
                // Prevent system UI from automatically requesting Touc ID/Face ID authentication
                // just in case someone passes here an LAContext instance without
                // a prior evaluateAccessControl call
                query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip
            }
            
            /*
            if let prompt = prompt {
                query[kSecUseOperationPrompt as String] = prompt
            }*/

            var dataTypeRef: AnyObject? = nil
            
            let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
            
            if status == noErr {
                return (dataTypeRef! as! Data)
            } else {
                
                if (status == -25300){
                    
                    //"DATA NOT FOUND, UNA POSSIBILE CAUSA (GESTITA) E' UNA VARIAZIONE DEL KEYCHAIN COME AD ESEMPIO IL RESET DELLE CREDENZIALI BIOMETRICHE O L'AGGIUNTA DI UN NUOVO UTENTE")
                    
                    //Elimino Biometric NIS da userdefault
                    if var biometricnisarray = UserDefaults.standard.array(forKey: "regbiometricnis")
                    {
                        let array = biometricnisarray as! Array<String>
                        if let index = array.firstIndex(of: nis!)
                        {
                            biometricnisarray.remove(at: index)
                    
                            UserDefaults.standard.set(biometricnisarray, forKey: "regbiometricnis")
                            UserDefaults.standard.synchronize()
                        }
                    }
                    
                    return Data("BIOMETRIC_ERROR".utf8)
                }
                
                return nil
            }

        }
    
    public class func saveHalfPIN(nis: String?, pin: String?) -> Bool {
        
        let dataFromString: Data = pin!.data(using: String.Encoding.utf8, allowLossyConversion: false)! as Data
        return saveData(nis: nis, data: dataFromString, forKey: NIS_CIE_HalfPIN, clazz: kSecClassGenericPassword as String)
	}
    
    public class func saveSecondHalfPIN(nis: String?, pin: String?) -> Bool {
        
        let dataFromString: Data = pin!.data(using: String.Encoding.utf8, allowLossyConversion: false)! as Data
        return saveData(nis: nis, data: dataFromString, forKey: NIS_CIE_SecondHalfPIN, clazz: kSecClassGenericPassword as String)
    }
    
    public class func saveCertificate(nis: String?, nome: String?, cognome: String?, certificate: Data?) -> Bool {
        
        if nome == nil || cognome == nil || certificate == nil {
            return false
        }
        
        var ret : Bool
        
        var dataFromString: Data = nome!.data(using: String.Encoding.utf8, allowLossyConversion: false)! as Data
        ret = saveData(nis: nis, data: dataFromString, forKey: NIS_CIE_Nome, clazz: kSecClassGenericPassword as String)
        
        dataFromString = cognome!.data(using: String.Encoding.utf8, allowLossyConversion: false)! as Data
        ret = ret && saveData(nis: nis, data: dataFromString, forKey: NIS_CIE_Cognome, clazz: kSecClassGenericPassword as String)
        
        ret = ret && saveCertData(nis: nis, data: certificate, forKey: NIS_CIE_Cert, clazz: kSecClassCertificate as String)
        
        return ret;
    }
    
    public class func getHalfPIN(nis: String?) -> String?
    {
        let halfPINData = load(nis: nis, key: NIS_CIE_HalfPIN, clazz:kSecClassGenericPassword as String)
        if(halfPINData == nil)
        {
            return nil
        }
        
        let halfPINStr = String(decoding: halfPINData!, as: UTF8.self)
        
        return halfPINStr
    }
        
    public class func getSecondHalfPIN(context: LAContext, nis: String?) -> (String?)
    {
        
        let secondHalfPINData = loadBiometricData(context: context, nis: nis, key: NIS_CIE_SecondHalfPIN, clazz: kSecClassGenericPassword as String)
        //let secondHalfPINData = load(nis: nis, key: NIS_CIE_SecondHalfPIN, clazz:kSecClassGenericPassword as String)
        if(secondHalfPINData == nil)
        {
            return nil
        }
        
        let secondHalfPINStr = String(decoding: secondHalfPINData!, as: UTF8.self)
        
        return secondHalfPINStr
    }
    
    public class func isSecondHalfPINInKeychain(nis: String?) -> Bool{
        
        if (containsBiometricNis(nis: nis)){
           return true
        }

        return false
    }

    public class func isCieRegistered()->Bool{
            
        var isCieRegistered : Bool = false
        
        if let nisarray = self.getRegisteredNIS(){
            
            let registeredNIS = NSMutableArray(array: nisarray)
            
            for _ in registeredNIS {
            
                isCieRegistered = true
                
            }
            
        }else{
            
            isCieRegistered = false
            
        }
            
        return isCieRegistered
            
    }
    
    public class func getName(nis: String?) -> String?
    {
        let data = load(nis: nis, key: NIS_CIE_Nome, clazz:kSecClassGenericPassword as String)
        if(data == nil)
        {
            return nil
        }
        let str = String(decoding: data!, as: UTF8.self)
        
        return str
    }
    
    public class func getCognome(nis: String?) -> String?
    {
        let data = load(nis: nis, key: NIS_CIE_Cognome, clazz:kSecClassGenericPassword as String)
        if(data == nil)
        {
            return nil
        }
        
        let str = String(decoding: data!, as: UTF8.self)
        
        return str
    }
    
    public class func getCertificate(nis: String?) -> Data?
    {
        let query: [String: Any] = [kSecClass as String: kSecClassCertificate,
                                    kSecAttrLabel as String: nis!,
                                    kSecReturnData as String: true]
                
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        
        return item as! Data
    }

    public class func contains(nis: String?) -> Bool  {
        if let nisarray = UserDefaults.standard.array(forKey: "regnis")
        {
//            return nisarray.contains(where: { (item) -> Bool in
//                guard let n = nis else { return false }
//                return (item as? String)?.contains(n) ?? false
//            })
            return (nisarray.first { item -> Bool in
                guard let n = nis else { return false }
                return (item as? String)?.contains(n) ?? false
            } != nil)
            
        }
        else
        {
            return false
        }
    }
    
    public class func add(nis: String?)  {
        
        if var nisarray = UserDefaults.standard.array(forKey: "regnis")
        {
            nisarray.append(nis!)
            UserDefaults.standard.set(nisarray, forKey: "regnis")
        }
        else
        {
            let nisarray = NSMutableArray()
            nisarray.add(nis!)
            UserDefaults.standard.set(nisarray, forKey: "regnis")
        }
                        
        UserDefaults.standard.synchronize()
    }
    
    //Metodo che verifica i NIS registrati con biometria
    public class func containsBiometricNis(nis: String?) -> Bool  {
        if let biometricnisarray = UserDefaults.standard.array(forKey: "regbiometricnis")
        {
            return biometricnisarray.contains(where: { (item) -> Bool in
                return item as! String == nis
            })
            
        }
        else
        {
            return false
        }
    }
    
    //Metodo che conserva i NIS registrati con biometria
    public class func addBiometricNis(nis: String?)  {
        
        if var biometricnisarray = UserDefaults.standard.array(forKey: "regbiometricnis")
        {
            biometricnisarray.append(nis!)
            UserDefaults.standard.set(biometricnisarray, forKey: "regbiometricnis")
        }
        else
        {
            let biometricnisarray = NSMutableArray()
            biometricnisarray.add(nis!)
            UserDefaults.standard.set(biometricnisarray, forKey: "regbiometricnis")
        }
                        
        UserDefaults.standard.synchronize()
    }
    
    public class func delete(nis: String?) -> Bool {
        
        //Elimino NIS da userdefault
        if var nisarray = UserDefaults.standard.array(forKey: "regnis")
        {
            let array = nisarray as! Array<String>
            if let index = array.firstIndex(of: nis!)
            {
                nisarray.remove(at: index)
        
                UserDefaults.standard.set(nisarray, forKey: "regnis")
                UserDefaults.standard.synchronize()
            }
        }
        
        //Elimino Biometric NIS da userdefault
        if var biometricnisarray = UserDefaults.standard.array(forKey: "regbiometricnis")
        {
            let array = biometricnisarray as! Array<String>
            if let index = array.firstIndex(of: nis!)
            {
                biometricnisarray.remove(at: index)
        
                UserDefaults.standard.set(biometricnisarray, forKey: "regbiometricnis")
                UserDefaults.standard.synchronize()
            }
        }
        
        self.delete(nis: nis, key: NIS_CIE_Cert, clazz: kSecClassCertificate as String)
        self.delete(nis: nis, key: NIS_CIE_Cognome, clazz: kSecClassGenericPassword as String)
        self.delete(nis: nis, key: NIS_CIE_Nome, clazz: kSecClassGenericPassword as String)
        self.delete(nis: nis, key: NIS_CIE_SecondHalfPIN, clazz: kSecClassGenericPassword as String)
        return self.delete(nis: nis, key: NIS_CIE_HalfPIN, clazz: kSecClassGenericPassword as String)
        
    }
        
    private class func delete(nis: String?, key: String, clazz: String) -> Bool {
		
        var query: [String: Any] = [
            kSecClass as String: clazz,
            kSecAttrAccount as String: nis!,
            kSecAttrService as String: key]
        
        //Se sto eliminando un dato biometrico aggiungo un SecAccessControl adeguato
        if (key == NIS_CIE_SecondHalfPIN){
            query[kSecAttrAccessControl as String] = SecAccessControlCreateWithFlags(nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil)
        }

        let status: OSStatus = SecItemDelete(query as CFDictionary)
        
        //MARK: CHECK STATUS
        //print("STATUS: \(status)")
		return status == noErr
        
	}
}
