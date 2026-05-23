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
/// Identity query: class, service, optional access group/label. Never includes
/// kSecAttrAccessible so reads/deletes remain compatible with legacy items.
@property (nonatomic, copy) NSDictionary *identityQuery;
/// Configured accessible token from Dart, or nil for system default on add.
@property (nonatomic, copy, nullable) NSString *configuredAccessible;
/// When YES, lazily migrate existing items after successful get/put update.
@property (nonatomic, assign) BOOL automaticAccessibilityMigration;
@end

// Maps Dart [FlutterKeychainAccessible] values to kSecAttrAccessible constants.
static CFStringRef AccessibleConstantForString(NSString *accessible) {
    if ([@"whenUnlocked" isEqualToString:accessible]) {
        return kSecAttrAccessibleWhenUnlocked;
    }
    if ([@"afterFirstUnlock" isEqualToString:accessible]) {
        return kSecAttrAccessibleAfterFirstUnlock;
    }
    if ([@"whenPasscodeSetThisDeviceOnly" isEqualToString:accessible]) {
        return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly;
    }
    if ([@"whenUnlockedThisDeviceOnly" isEqualToString:accessible]) {
        return kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
    }
    if ([@"afterFirstUnlockThisDeviceOnly" isEqualToString:accessible]) {
        return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    }
    return NULL;
}

static NSString *AccessibleTokenForConstant(CFStringRef accessible) {
    if (accessible == NULL) {
        return @"unknown";
    }
    if (CFEqual(accessible, kSecAttrAccessibleWhenUnlocked)) {
        return @"whenUnlocked";
    }
    if (CFEqual(accessible, kSecAttrAccessibleAfterFirstUnlock)) {
        return @"afterFirstUnlock";
    }
    if (CFEqual(accessible, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)) {
        return @"whenPasscodeSetThisDeviceOnly";
    }
    if (CFEqual(accessible, kSecAttrAccessibleWhenUnlockedThisDeviceOnly)) {
        return @"whenUnlockedThisDeviceOnly";
    }
    if (CFEqual(accessible, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)) {
        return @"afterFirstUnlockThisDeviceOnly";
    }
    return @"unknown";
}

@implementation FlutterKeychainPlugin

- (instancetype)init {
    self = [super init];
    if (self) {
        [self configureWithAccessGroup:nil
                                 label:nil
                            accessible:nil
               accessibilityMigration:@"none"];
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
                           label:(nullable NSString *)label
                      accessible:(nullable NSString *)accessible
         accessibilityMigration:(nullable NSString *)accessibilityMigration {
    NSMutableDictionary *q = [NSMutableDictionary dictionary];
    q[(__bridge id)kSecClass]       = (__bridge id)kSecClassGenericPassword;
    q[(__bridge id)kSecAttrService] = KEYCHAIN_SERVICE;
    if (accessGroup.length > 0) {
        q[(__bridge id)kSecAttrAccessGroup] = accessGroup;
    }
    if (label.length > 0) {
        q[(__bridge id)kSecAttrLabel] = label;
    }
    self.identityQuery = [q copy];
    self.configuredAccessible = accessible.length > 0 ? [accessible copy] : nil;
    self.automaticAccessibilityMigration =
        [@"automatic" isEqualToString:accessibilityMigration];
}

- (NSMutableDictionary *)identityQueryForKey:(NSString *)key {
    NSMutableDictionary *query = [self.identityQuery mutableCopy];
    query[(__bridge id)kSecAttrAccount] = key;
    return query;
}

- (BOOL)shouldAttemptAccessibilityMigration {
    return self.automaticAccessibilityMigration &&
           self.configuredAccessible.length > 0 &&
           AccessibleConstantForString(self.configuredAccessible) != NULL;
}

- (nullable CFStringRef)currentAccessibleConstantForKey:(NSString *)key {
    NSMutableDictionary *search = [self identityQueryForKey:key];
    search[(__bridge id)kSecReturnAttributes] = (__bridge id)kCFBooleanTrue;
    search[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

    CFDictionaryRef attrs = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)search,
                                          (CFTypeRef *)&attrs);
    if (status != noErr || attrs == NULL) {
        return NULL;
    }
    NSDictionary *dict = (__bridge_transfer NSDictionary *)attrs;
    return (__bridge CFStringRef)dict[(__bridge id)kSecAttrAccessible];
}

- (void)migrateAccessibilityForKey:(NSString *)key
                          withData:(NSData *)data
                            source:(NSString *)source {
    if (![self shouldAttemptAccessibilityMigration]) {
        return;
    }
    CFStringRef accessibleConstant =
        AccessibleConstantForString(self.configuredAccessible);
    CFStringRef currentAccessible = [self currentAccessibleConstantForKey:key];
    if (currentAccessible != NULL &&
        CFEqual(currentAccessible, accessibleConstant)) {
        NSLog(@"[flutter_keychain] accessibility migration skipped for key "
              @"'%@' (already %@, trigger: %@)",
              key, self.configuredAccessible, source);
        return;
    }

    NSString *fromToken = currentAccessible != NULL
        ? AccessibleTokenForConstant(currentAccessible)
        : @"legacy/default";
    NSLog(@"[flutter_keychain] accessibility migration started for key '%@' "
          @"from %@ to %@ (trigger: %@)",
          key, fromToken, self.configuredAccessible, source);

    NSMutableDictionary *query = [self identityQueryForKey:key];
    NSDictionary *update = @{
        (__bridge id)kSecAttrAccessible: (__bridge id)accessibleConstant,
        (__bridge id)kSecValueData: data,
    };
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query,
                                    (__bridge CFDictionaryRef)update);
    if (status == noErr) {
        NSLog(@"[flutter_keychain] accessibility migration succeeded for key "
              @"'%@' (trigger: %@)",
              key, source);
    } else {
        NSLog(@"[flutter_keychain] accessibility migration failed for key "
              @"'%@' status = %d (trigger: %@)",
              key, (int)status, source);
    }
}

- (void)migrateAccessibilityForKey:(NSString *)key withData:(NSData *)data {
    [self migrateAccessibilityForKey:key withData:data source:@"get"];
}

// ---------------------------------------------------------------------------
// Method channel dispatch
// ---------------------------------------------------------------------------

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([@"configure" isEqualToString:call.method]) {
        NSDictionary *args = call.arguments;
        NSString *accessGroup = [args[@"accessGroup"] isKindOfClass:[NSString class]]
            ? args[@"accessGroup"] : nil;
        NSString *label = [args[@"label"] isKindOfClass:[NSString class]]
            ? args[@"label"] : nil;
        NSString *accessible = [args[@"accessible"] isKindOfClass:[NSString class]]
            ? args[@"accessible"] : nil;
        NSString *migration =
            [args[@"accessibilityMigration"] isKindOfClass:[NSString class]]
            ? args[@"accessibilityMigration"] : @"none";
        if (accessible.length > 0 &&
            AccessibleConstantForString(accessible) == NULL) {
            result([FlutterError errorWithCode:@"INVALID_ACCESSIBLE"
                                       message:@"Unknown accessible value"
                                       details:accessible]);
            return;
        }
        if (![@"none" isEqualToString:migration] &&
            ![@"automatic" isEqualToString:migration]) {
            result([FlutterError errorWithCode:@"INVALID_ACCESSIBILITY_MIGRATION"
                                       message:@"Unknown accessibilityMigration value"
                                       details:migration]);
            return;
        }
        [self configureWithAccessGroup:accessGroup
                                 label:label
                            accessible:accessible
               accessibilityMigration:migration];
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
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *search = [self identityQueryForKey:key];
    search[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)search, NULL);
    if (status == noErr) {
        NSMutableDictionary *updateQuery = [self identityQueryForKey:key];
        NSMutableDictionary *update = [NSMutableDictionary dictionary];
        update[(__bridge id)kSecValueData] = data;
        if ([self shouldAttemptAccessibilityMigration]) {
            CFStringRef accessibleConstant =
                AccessibleConstantForString(self.configuredAccessible);
            CFStringRef currentAccessible =
                [self currentAccessibleConstantForKey:key];
            if (currentAccessible != NULL &&
                CFEqual(currentAccessible, accessibleConstant)) {
                NSLog(@"[flutter_keychain] accessibility migration skipped for "
                      @"key '%@' (already %@, trigger: put)",
                      key, self.configuredAccessible);
            } else {
                NSString *fromToken = currentAccessible != NULL
                    ? AccessibleTokenForConstant(currentAccessible)
                    : @"legacy/default";
                NSLog(@"[flutter_keychain] accessibility migration started for "
                      @"key '%@' from %@ to %@ (trigger: put)",
                      key, fromToken, self.configuredAccessible);
                update[(__bridge id)kSecAttrAccessible] =
                    (__bridge id)accessibleConstant;
            }
        }
        status = SecItemUpdate((__bridge CFDictionaryRef)updateQuery,
                               (__bridge CFDictionaryRef)update);
        if (status != noErr) {
            NSLog(@"[flutter_keychain] SecItemUpdate status = %d", (int)status);
            if ([self shouldAttemptAccessibilityMigration] &&
                update[(__bridge id)kSecAttrAccessible] != nil) {
                NSLog(@"[flutter_keychain] accessibility migration failed for "
                      @"key '%@' status = %d (trigger: put)",
                      key, (int)status);
            }
        } else if ([self shouldAttemptAccessibilityMigration] &&
                   update[(__bridge id)kSecAttrAccessible] != nil) {
            NSLog(@"[flutter_keychain] accessibility migration succeeded for "
                  @"key '%@' (trigger: put)",
                  key);
        }
    } else {
        NSMutableDictionary *add = [self identityQueryForKey:key];
        add[(__bridge id)kSecValueData] = data;
        if (self.configuredAccessible.length > 0) {
            CFStringRef accessibleConstant =
                AccessibleConstantForString(self.configuredAccessible);
            if (accessibleConstant != NULL) {
                add[(__bridge id)kSecAttrAccessible] =
                    (__bridge id)accessibleConstant;
            }
        }
        status = SecItemAdd((__bridge CFDictionaryRef)add, NULL);
        if (status != noErr) {
            NSLog(@"[flutter_keychain] SecItemAdd status = %d", (int)status);
        }
    }
}

- (nullable NSString *)get:(NSString *)key {
    NSMutableDictionary *search = [self identityQueryForKey:key];
    search[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    search[(__bridge id)kSecMatchLimit]  = (__bridge id)kSecMatchLimitOne;

    CFDataRef resultData = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)search,
                                          (CFTypeRef *)&resultData);
    if (status == noErr && resultData != NULL) {
        NSData *data = (__bridge_transfer NSData *)resultData;
        [self migrateAccessibilityForKey:key withData:data];
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    if (resultData != NULL) {
        CFRelease(resultData);
    }
    return nil;
}

- (void)remove:(NSString *)key {
    NSMutableDictionary *search = [self identityQueryForKey:key];
    SecItemDelete((__bridge CFDictionaryRef)search);
}

- (void)clear {
    NSMutableDictionary *search = [self.identityQuery mutableCopy];
    SecItemDelete((__bridge CFDictionaryRef)search);
}

@end
