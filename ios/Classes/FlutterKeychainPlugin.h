#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

@interface FlutterKeychainPlugin : NSObject <FlutterPlugin>

/**
 * Optional configuration for all subsequent Keychain operations.
 * Must be called before any get / put / remove / clear if non-default
 * values are desired.
 *
 * @param accessGroup  kSecAttrAccessGroup value, e.g. "com.example.shared".
 *                     Pass nil to use the default (app-specific) access group.
 * @param label        kSecAttrLabel string shown in iOS Passwords
 *                     (Settings > Passwords). Pass nil to omit the label.
 * @param accessible   kSecAttrAccessible value as a stable string token
 *                     (e.g. "afterFirstUnlock"). Pass nil for system default
 *                     on newly added items only.
 * @param accessibilityMigration  "none" or "automatic". When "automatic",
 *                     successful reads/updates attempt to migrate existing
 *                     items to @p accessible.
 */
- (void)configureWithAccessGroup:(nullable NSString *)accessGroup
                           label:(nullable NSString *)label
                      accessible:(nullable NSString *)accessible
         accessibilityMigration:(nullable NSString *)accessibilityMigration;

@end

NS_ASSUME_NONNULL_END
