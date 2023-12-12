import Flutter
import UIKit
import Security

public class FlutterKeychainPlugin: NSObject, FlutterPlugin {
    private let KEYCHAIN_SERVICE = "flutter_keychain"
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "plugin.appmire.be/flutter_keychain", binaryMessenger: registrar.messenger())
        let instance = FlutterKeychainPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "clear":
            clearKeychain(call: call, result: result)
        case "get":
            getValue(call: call, result: result)
        case "put":
            putValue(call: call, result: result)
        case "remove":
            removeValue(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func clearKeychain(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [:]
        
        let keyChainService = call.getKeychainName() ?? KEYCHAIN_SERVICE
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keyChainService
        ]
        
        let secResult = SecItemDelete(query as CFDictionary)
        
        if (secResult == errSecSuccess) {
            result(nil)
        } else {
            result(
                FlutterError(
                    code: "KEYCHAIN_CLEAR_ERROR",
                    message: getSecErrorMessage(errorCode: secResult),
                    details: nil)
            )
        }
    }
    
    private func getValue(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [:]
        
        let keyChainService = call.getKeychainName() ?? KEYCHAIN_SERVICE
        
        let key: String? = call.getKey()
        
        if (key == nil) {
            result(nil)
            
            return
        }
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keyChainService,
            kSecReturnData: kCFBooleanTrue!,
            kSecAttrAccount: key!,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        
        var value: AnyObject?
        
        let secResult = SecItemCopyMatching(query as CFDictionary, &value)
        
        guard secResult == errSecSuccess, let keyChainValue = value as? Data else {
            result(nil)
            
            return
        }
        
        guard let stringValue = String(data: keyChainValue, encoding: .utf8) else {
            result(nil)
            
            return
        }
        
        result(stringValue)
    }
    
    private func putValue(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [:]
        
        let keyChainService = call.getKeychainName() ?? KEYCHAIN_SERVICE
        
        let key: String? = call.getKey()
        let value: String? = call.getValue()
        
        if (key == nil || value == nil) {
            result(nil)
            
            return
        }
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keyChainService,
            kSecAttrAccount: key!
        ]
        
        // Delete the existing item
        let deleteStatus = SecItemDelete(query as CFDictionary)
        
        // The deletion failed, abort.
        // If the item was not found, continue anyway.
        if (deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound) {
            result(
                FlutterError(
                    code: "KEYCHAIN_PUT_VALUE_ERROR",
                    message: getSecErrorMessage(errorCode: deleteStatus),
                    details: nil)
            )
            
            return
        }
        
        let updateFields: [CFString: Any] = [
            kSecValueData: value!.data(using: .utf8)!
        ]
        
        let updateStatus = SecItemUpdate(query as CFDictionary,
                                         updateFields as CFDictionary)
        
        if (updateStatus == errSecSuccess) {
            result(nil)
        } else {
            result(
                FlutterError(
                    code: "KEYCHAIN_PUT_VALUE_ERROR",
                    message: getSecErrorMessage(errorCode: updateStatus),
                    details: nil)
            )
        }
    }
    
    private func removeValue(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [:]
        
        let keyChainService = call.getKeychainName() ?? KEYCHAIN_SERVICE
        
        let key: String? = call.getKey()
        
        if (key == nil) {
            result(nil)
            
            return
        }
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keyChainService,
            kSecReturnData: kCFBooleanFalse!,
            kSecAttrAccount: key!,
        ]
        
        let secResult = SecItemDelete(query as CFDictionary)
        
        if (secResult == errSecSuccess) {
            result(nil)
        } else {
            result(
                FlutterError(
                    code: "KEYCHAIN_REMOVE_VALUE_ERROR",
                    message: getSecErrorMessage(errorCode: secResult),
                    details: nil)
            )
        }
    }
    
    private func getSecErrorMessage(errorCode: OSStatus) -> String? {
        if #available(iOS 11.3, *) {
            return SecCopyErrorMessageString(errorCode, nil) as String?
        } else {
            return "Keychain error: \(errorCode)"
        }
    }
}

extension FlutterMethodCall {
    func getKey() -> String? {
        let arguments = self.arguments as? [String: Any] ?? [:]
        
        return arguments["key"] as? String
    }
    
    func getKeychainName() -> String? {
        let arguments = self.arguments as? [String: Any] ?? [:]
        
        return arguments["keyChainName"] as? String
    }
    
    func getValue() -> String? {
        let arguments = self.arguments as? [String: Any] ?? [:]
        
        return arguments["value"] as? String
    }
}
