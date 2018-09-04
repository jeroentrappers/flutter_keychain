#import "FlutterKeychainPlugin.h"
#import <flutter_keychain/flutter_keychain-Swift.h>

@implementation FlutterKeychainPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterKeychainPlugin registerWithRegistrar:registrar];
}
@end
