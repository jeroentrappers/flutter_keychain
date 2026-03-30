#import "FlutterKeychainPlugin.h"

static NSString *const KEYCHAIN_SERVICE = @"flutter_keychain";
static NSString *const CHANNEL_NAME     = @"plugin.appmire.be/flutter_keychain";

// ---------------------------------------------------------------------------
// FlutterMethodCall convenience category
// ---------------------------------------------------------------------------

@interface FlutterMethodCall (KeyValue)
- (nullable NSString *)key;
- (nullable NSString *)value;
@end

@implementation FlutterMethodCall (KeyValue)

- (nullable NSString *)key {
    id v = [self arguments][@"key"];
    return [v isKindOfClass:[NSString class]] ? v : nil;
}

- (nullable NSString *)value {
    id v = [self arguments][@"value"];
    return [v isKindOfClass:[NSString class]] ? v : nil;
}

@end

// ---------------------------------------------------------------------------
// FlutterKeychainPlugin
// ---------------------------------------------------------------------------

@interface FlutterKeychainPlugin ()
/// Base query dictionary rebuilt by -configureWithAccessGroup:label:.
@property (nonatomic, copy) NSDictionary *baseQuery;
@end

@implementation FlutterKeychainPlugin

- (instancetype)init {
    self = [super init];
    if (self) {
        // Default: app-specific access group, no label.
        [self configureWithAccessGroup:nil label:nil];
    }
    return self;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel =
        [FlutterMethodChannel methodChannelWithName:CHANNEL_NAME
                                    binaryMessenger:[registrar messenger]];
    FlutterKeychainPlugin *instance = [[FlutterKeychainPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

- (void)configureWithAccessGroup:(nullable NSString *)accessGroup
                           label:(nullable NSString *)label {
    NSMutableDictionary *q = [NSMutableDictionary dictionary];
    q[(__bridge id)kSecClass]       = (__bridge id)kSecClassGenericPassword;
    q[(__bridge id)kSecAttrService] = KEYCHAIN_SERVICE;
    if (accessGroup.length > 0) {
        q[(__bridge id)kSecAttrAccessGroup] = accessGroup;
    }
    if (label.length > 0) {
        q[(__bridge id)kSecAttrLabel] = label;
    }
    self.baseQuery = [q copy];
}

// ---------------------------------------------------------------------------
// Method channel dispatch
// ---------------------------------------------------------------------------

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([@"configure" isEqualToString:call.method]) {
        NSDictionary *args = call.arguments;
        // Dart sends NSNull when an optional String? is nil.
        NSString *accessGroup = [args[@"accessGroup"] isKindOfClass:[NSString class]]
            ? args[@"accessGroup"] : nil;
        NSString *label = [args[@"label"] isKindOfClass:[NSString class]]
            ? args[@"label"] : nil;
        [self configureWithAccessGroup:accessGroup label:label];
        result(nil);
    } else if ([@"get" isEqualToString:call.method]) {
        result([self get:call.key]);
    } else if ([@"put" isEqualToString:call.method]) {
        [self put:call.value forKey:call.key];
        result(nil);
    } else if ([@"remove" isEqualToString:call.method]) {
        [self remove:call.key];
        result(nil);
    } else if ([@"clear" isEqualToString:call.method]) {
        [self clear];
        result(nil);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

// ---------------------------------------------------------------------------
// Keychain operations
// ---------------------------------------------------------------------------

- (void)put:(NSString *)value forKey:(NSString *)key {
    NSMutableDictionary *search = [self.baseQuery mutableCopy];
    search[(__bridge id)kSecAttrAccount] = key;
    search[(__bridge id)kSecMatchLimit]  = (__bridge id)kSecMatchLimitOne;

    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)search, NULL);
    if (status == noErr) {
        // Item exists — update its data.
        search[(__bridge id)kSecMatchLimit] = nil;
        NSDictionary *update = @{
            (__bridge id)kSecValueData: [value dataUsingEncoding:NSUTF8StringEncoding]
        };
        status = SecItemUpdate((__bridge CFDictionaryRef)search,
                               (__bridge CFDictionaryRef)update);
        if (status != noErr) {
            NSLog(@"[flutter_keychain] SecItemUpdate status = %d", (int)status);
        }
    } else {
        // Item does not exist — add it.
        search[(__bridge id)kSecValueData] = [value dataUsingEncoding:NSUTF8StringEncoding];
        search[(__bridge id)kSecMatchLimit] = nil;
        status = SecItemAdd((__bridge CFDictionaryRef)search, NULL);
        if (status != noErr) {
            NSLog(@"[flutter_keychain] SecItemAdd status = %d", (int)status);
        }
    }
}

- (nullable NSString *)get:(NSString *)key {
    NSMutableDictionary *search = [self.baseQuery mutableCopy];
    search[(__bridge id)kSecAttrAccount] = key;
    search[(__bridge id)kSecReturnData]  = (__bridge id)kCFBooleanTrue;
    search[(__bridge id)kSecMatchLimit]  = (__bridge id)kSecMatchLimitOne;

    CFDataRef resultData = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)search,
                                          (CFTypeRef *)&resultData);
    if (status == noErr && resultData != NULL) {
        // __bridge_transfer gives ARC ownership, so no manual CFRelease needed.
        NSData *data = (__bridge_transfer NSData *)resultData;
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    if (resultData != NULL) {
        CFRelease(resultData);
    }
    return nil;
}

- (void)remove:(NSString *)key {
    NSMutableDictionary *search = [self.baseQuery mutableCopy];
    search[(__bridge id)kSecAttrAccount] = key;
    SecItemDelete((__bridge CFDictionaryRef)search);
}

- (void)clear {
    NSMutableDictionary *search = [self.baseQuery mutableCopy];
    SecItemDelete((__bridge CFDictionaryRef)search);
}

@end
