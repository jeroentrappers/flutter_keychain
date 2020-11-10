#import "FlutterKeychainPlugin.h"

static NSString *const KEYCHAIN_SERVICE = @"flutter_keychain";
static NSString *const CHANNEL_NAME = @"plugin.appmire.be/flutter_keychain";

static NSString *const InvalidParameters = @"Invalid parameter's type";

@interface FlutterMethodCall (KeyValue)

- (NSString *) key;
- (NSString *) value;

@end

@implementation FlutterMethodCall (KeyValue)

- (NSString *) key{
    return [self arguments][@"key"];
}

- (NSString *) value {
    return [self arguments][@"value"];
}

@end

@interface FlutterKeychainPlugin()

@property (strong, nonatomic) NSDictionary *query;

@end

@implementation FlutterKeychainPlugin

- (instancetype)init {
    self = [super init];
    if (self){
        self.query = @{
            (__bridge id)kSecClass :(__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService :KEYCHAIN_SERVICE,
        };
    }
    return self;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    @try {
        FlutterMethodChannel* channel = [FlutterMethodChannel
                                         methodChannelWithName:CHANNEL_NAME
                                         binaryMessenger:[registrar messenger]];
        FlutterKeychainPlugin* instance = [[FlutterKeychainPlugin alloc] init];
        [registrar addMethodCallDelegate:instance channel:channel];
    }
    @catch (NSException *exception) {
        NSLog(@"%@", exception.reason);
    }
    @catch (NSObject *object){
        NSLog(@"%@", object);
    }
}



- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"get" isEqualToString:call.method]) {
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
    }else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)put:(NSString *)value forKey:(NSString *)key {
    NSMutableDictionary *search = [self.query mutableCopy];
    search[(__bridge id)kSecAttrAccount] = key;
    search[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    
    OSStatus status;
    status = SecItemCopyMatching((__bridge CFDictionaryRef)search, NULL);
    if (status == noErr){
        search[(__bridge id)kSecMatchLimit] = nil;
        
        NSDictionary *update = @{(__bridge id)kSecValueData: [value dataUsingEncoding:NSUTF8StringEncoding]};
        
        status = SecItemUpdate((__bridge CFDictionaryRef)search, (__bridge CFDictionaryRef)update);
        if (status != noErr){
            NSLog(@"SecItemUpdate status = %d", (int) status);
        }
    }else{
        search[(__bridge id)kSecValueData] = [value dataUsingEncoding:NSUTF8StringEncoding];
        search[(__bridge id)kSecMatchLimit] = nil;
        
        status = SecItemAdd((__bridge CFDictionaryRef)search, NULL);
        if (status != noErr){
            NSLog(@"SecItemAdd status = %d", (int) status);
        }
    }
}

- (NSString *)get:(NSString *)key {
    NSMutableDictionary *search = [self.query mutableCopy];
    search[(__bridge id)kSecAttrAccount] = key;
    search[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    
    CFDataRef resultData = NULL;
    
    OSStatus status;
    status = SecItemCopyMatching((__bridge CFDictionaryRef)search, (CFTypeRef*)&resultData);
    NSString *value;
    if (status == noErr){
        NSData *data = (__bridge NSData*)resultData;
        value = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return value;
}

- (void)remove:(NSString *)key {
    NSMutableDictionary *search = [self.query mutableCopy];
    search[(__bridge id)kSecAttrAccount] = key;
    search[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    SecItemDelete((__bridge CFDictionaryRef)search);
}

- (void)clear {
    NSMutableDictionary *search = [self.query mutableCopy];
    SecItemDelete((__bridge CFDictionaryRef)search);
}

@end
