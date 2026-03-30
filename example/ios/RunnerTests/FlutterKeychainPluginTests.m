/**
 * FlutterKeychainPluginTests.m
 *
 * XCTest suite for FlutterKeychainPlugin (iOS / Objective-C).
 *
 * SETUP – add this file to a test target in Xcode:
 *   1. Open example/ios/Runner.xcworkspace in Xcode.
 *   2. File > New > Target > Unit Testing Bundle, name it "RunnerTests".
 *      (If RunnerTests already exists, skip this step.)
 *   3. Set "Host Application" to "Runner".
 *   4. Add this file to the RunnerTests target's "Compile Sources".
 *   5. In the RunnerTests target's Build Settings, under "Framework Search Paths",
 *      add "$(BUILT_PRODUCTS_DIR)/flutter_keychain.framework/.." if not already present.
 *
 * RUN:
 *   Product > Test  (⌘U)
 *   or: xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,...'
 */

#import <XCTest/XCTest.h>
#import <Flutter/Flutter.h>

// The plugin header is available through the CocoaPods integration.
// If the import fails, make sure `pod install` has been run in example/ios/.
#import <flutter_keychain/FlutterKeychainPlugin.h>


// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

@interface FlutterKeychainPluginTests : XCTestCase
@property (nonatomic, strong) FlutterKeychainPlugin *plugin;
@end

@implementation FlutterKeychainPluginTests

- (void)setUp {
    [super setUp];
    self.plugin = [[FlutterKeychainPlugin alloc] init];
    // Start every test with a clean keychain service.
    [self invokeMethod:@"clear" arguments:@{}];
}

- (void)tearDown {
    [self invokeMethod:@"clear" arguments:@{}];
    [super tearDown];
}

/**
 * Synchronously invoke a plugin method and return its result.
 * All Keychain operations are synchronous, so the result block fires before
 * handleMethodCall:result: returns.
 */
- (id)invokeMethod:(NSString *)method arguments:(NSDictionary *)arguments {
    __block id returnValue = nil;
    FlutterMethodCall *call = [FlutterMethodCall methodCallWithMethodName:method
                                                               arguments:arguments];
    [self.plugin handleMethodCall:call result:^(id result) {
        returnValue = result;
    }];
    return returnValue;
}


// ---------------------------------------------------------------------------
// put
// ---------------------------------------------------------------------------

- (void)testPut_basicValue_doesNotThrow {
    XCTAssertNoThrow(
        [self invokeMethod:@"put" arguments:@{@"key": @"token", @"value": @"abc123"}]
    );
}

- (void)testPut_returnsNil {
    id result = [self invokeMethod:@"put"
                         arguments:@{@"key": @"k", @"value": @"v"}];
    XCTAssertNil(result, @"put should return nil");
}

- (void)testPut_multipleKeys_storedIndependently {
    [self invokeMethod:@"put" arguments:@{@"key": @"k1", @"value": @"v1"}];
    [self invokeMethod:@"put" arguments:@{@"key": @"k2", @"value": @"v2"}];
    [self invokeMethod:@"put" arguments:@{@"key": @"k3", @"value": @"v3"}];

    XCTAssertEqualObjects([self invokeMethod:@"get" arguments:@{@"key": @"k1"}], @"v1");
    XCTAssertEqualObjects([self invokeMethod:@"get" arguments:@{@"key": @"k2"}], @"v2");
    XCTAssertEqualObjects([self invokeMethod:@"get" arguments:@{@"key": @"k3"}], @"v3");
}

- (void)testPut_overwritesExistingValue {
    [self invokeMethod:@"put" arguments:@{@"key": @"k", @"value": @"old"}];
    [self invokeMethod:@"put" arguments:@{@"key": @"k", @"value": @"new"}];
    XCTAssertEqualObjects([self invokeMethod:@"get" arguments:@{@"key": @"k"}], @"new");
}

- (void)testPut_emptyStringValue {
    [self invokeMethod:@"put" arguments:@{@"key": @"empty", @"value": @""}];
    XCTAssertEqualObjects([self invokeMethod:@"get" arguments:@{@"key": @"empty"}], @"");
}

- (void)testPut_unicodeValue {
    NSString *v = @"日本語テスト 🔑 àéîõü";
    [self invokeMethod:@"put" arguments:@{@"key": @"unicode", @"value": v}];
    XCTAssertEqualObjects([self invokeMethod:@"get" arguments:@{@"key": @"unicode"}], v);
}

- (void)testPut_specialCharactersInValue {
    NSString *v = @"!@#$%^&*()_+-=[]{}|;:\"',.<>?/\\`~";
    [self invokeMethod:@"put" arguments:@{@"key": @"special", @"value": v}];
    XCTAssertEqualObjects([self invokeMethod:@"get" arguments:@{@"key": @"special"}], v);
}

- (void)testPut_newlinesAndTabsInValue {
    NSString *v = @"line1\nline2\ttabbed\r\nwindows";
    [self invokeMethod:@"put" arguments:@{@"key": @"whitespace", @"value": v}];
    XCTAssertEqualObjects([self invokeMethod:@"get" arguments:@{@"key": @"whitespace"}], v);
}

- (void)testPut_longValue {
    NSMutableString *v = [NSMutableString string];
    for (int i = 0; i < 10000; i++) [v appendString:@"A"];
    [self invokeMethod:@"put" arguments:@{@"key": @"long", @"value": v}];
    XCTAssertEqualObjects([self invokeMethod:@"get" arguments:@{@"key": @"long"}], v);
}

- (void)testPut_jsonFormattedValue {
    NSString *v = @"{\"user\":\"alice\",\"token\":\"eyJhbGci\",\"roles\":[\"admin\"]}";
    [self invokeMethod:@"put" arguments:@{@"key": @"json", @"value": v}];
    XCTAssertEqualObjects([self invokeMethod:@"get" arguments:@{@"key": @"json"}], v);
}

- (void)testPut_keyWithSpacesAndSpecialChars {
    [self invokeMethod:@"put" arguments:@{@"key": @"my key name!", @"value": @"val"}];
    XCTAssertEqualObjects(
        [self invokeMethod:@"get" arguments:@{@"key": @"my key name!"}], @"val");
}

- (void)testPut_repeatedOverwrite_onlyLatestValueReturned {
    for (int i = 0; i < 20; i++) {
        [self invokeMethod:@"put"
                arguments:@{@"key": @"rotating", @"value": [NSString stringWithFormat:@"v%d", i]}];
    }
    XCTAssertEqualObjects([self invokeMethod:@"get" arguments:@{@"key": @"rotating"}], @"v19");
}


// ---------------------------------------------------------------------------
// get
// ---------------------------------------------------------------------------

- (void)testGet_existingKey_returnsStoredValue {
    [self invokeMethod:@"put" arguments:@{@"key": @"token", @"value": @"secret"}];
    id result = [self invokeMethod:@"get" arguments:@{@"key": @"token"}];
    XCTAssertEqualObjects(result, @"secret");
}

- (void)testGet_nonExistentKey_returnsNil {
    id result = [self invokeMethod:@"get" arguments:@{@"key": @"never_stored"}];
    XCTAssertNil(result, @"get for a missing key must return nil");
}

- (void)testGet_afterOverwrite_returnsLatestValue {
    [self invokeMethod:@"put" arguments:@{@"key": @"k", @"value": @"v1"}];
    [self invokeMethod:@"put" arguments:@{@"key": @"k", @"value": @"v2"}];
    XCTAssertEqualObjects([self invokeMethod:@"get" arguments:@{@"key": @"k"}], @"v2");
}

- (void)testGet_returnsCorrectValueForEachKey {
    NSDictionary *pairs = @{@"a": @"alpha", @"b": @"beta", @"c": @"gamma"};
    [pairs enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSString *v, BOOL *stop) {
        [self invokeMethod:@"put" arguments:@{@"key": k, @"value": v}];
    }];
    [pairs enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSString *expected, BOOL *stop) {
        XCTAssertEqualObjects(
            [self invokeMethod:@"get" arguments:@{@"key": k}], expected,
            @"Wrong value for key '%@'", k);
    }];
}


// ---------------------------------------------------------------------------
// remove
// ---------------------------------------------------------------------------

- (void)testRemove_deletesKey {
    [self invokeMethod:@"put" arguments:@{@"key": @"del", @"value": @"bye"}];
    [self invokeMethod:@"remove" arguments:@{@"key": @"del"}];
    XCTAssertNil([self invokeMethod:@"get" arguments:@{@"key": @"del"}]);
}

- (void)testRemove_returnsNil {
    [self invokeMethod:@"put" arguments:@{@"key": @"del", @"value": @"bye"}];
    id result = [self invokeMethod:@"remove" arguments:@{@"key": @"del"}];
    XCTAssertNil(result, @"remove should return nil");
}

- (void)testRemove_nonExistentKey_doesNotThrow {
    XCTAssertNoThrow(
        [self invokeMethod:@"remove" arguments:@{@"key": @"ghost"}]
    );
}

- (void)testRemove_onlyRemovesSpecifiedKey {
    [self invokeMethod:@"put" arguments:@{@"key": @"keep", @"value": @"safe"}];
    [self invokeMethod:@"put" arguments:@{@"key": @"del",  @"value": @"bye"}];
    [self invokeMethod:@"remove" arguments:@{@"key": @"del"}];

    XCTAssertEqualObjects([self invokeMethod:@"get" arguments:@{@"key": @"keep"}], @"safe");
    XCTAssertNil([self invokeMethod:@"get" arguments:@{@"key": @"del"}]);
}

- (void)testRemove_canReAddKeyAfterRemoval {
    [self invokeMethod:@"put"    arguments:@{@"key": @"k", @"value": @"v1"}];
    [self invokeMethod:@"remove" arguments:@{@"key": @"k"}];
    [self invokeMethod:@"put"    arguments:@{@"key": @"k", @"value": @"v2"}];
    XCTAssertEqualObjects([self invokeMethod:@"get" arguments:@{@"key": @"k"}], @"v2");
}

- (void)testRemove_allKeys_storeIsEmpty {
    NSArray *keys = @[@"a", @"b", @"c", @"d", @"e"];
    for (NSString *k in keys) {
        [self invokeMethod:@"put" arguments:@{@"key": k, @"value": @"v"}];
    }
    for (NSString *k in keys) {
        [self invokeMethod:@"remove" arguments:@{@"key": k}];
    }
    for (NSString *k in keys) {
        XCTAssertNil([self invokeMethod:@"get" arguments:@{@"key": k}],
                     @"Key '%@' should be nil after removal", k);
    }
}


// ---------------------------------------------------------------------------
// clear
// ---------------------------------------------------------------------------

- (void)testClear_removesAllEntries {
    [self invokeMethod:@"put" arguments:@{@"key": @"a", @"value": @"1"}];
    [self invokeMethod:@"put" arguments:@{@"key": @"b", @"value": @"2"}];
    [self invokeMethod:@"put" arguments:@{@"key": @"c", @"value": @"3"}];
    [self invokeMethod:@"clear" arguments:@{}];

    XCTAssertNil([self invokeMethod:@"get" arguments:@{@"key": @"a"}]);
    XCTAssertNil([self invokeMethod:@"get" arguments:@{@"key": @"b"}]);
    XCTAssertNil([self invokeMethod:@"get" arguments:@{@"key": @"c"}]);
}

- (void)testClear_returnsNil {
    id result = [self invokeMethod:@"clear" arguments:@{}];
    XCTAssertNil(result, @"clear should return nil");
}

- (void)testClear_emptyStore_doesNotThrow {
    // setUp already called clear; calling again on an empty store must not throw.
    XCTAssertNoThrow([self invokeMethod:@"clear" arguments:@{}]);
}

- (void)testClear_canStoreManyValuesAfterClear {
    [self invokeMethod:@"put" arguments:@{@"key": @"x", @"value": @"old"}];
    [self invokeMethod:@"clear" arguments:@{}];

    NSArray *keys = @[@"p", @"q", @"r", @"s"];
    for (NSString *k in keys) {
        [self invokeMethod:@"put"
                arguments:@{@"key": k, @"value": [NSString stringWithFormat:@"val_%@", k]}];
    }
    for (NSString *k in keys) {
        XCTAssertEqualObjects(
            [self invokeMethod:@"get" arguments:@{@"key": k}],
            [NSString stringWithFormat:@"val_%@", k]);
    }
}

- (void)testClear_doubleClear_isIdempotent {
    [self invokeMethod:@"put" arguments:@{@"key": @"k", @"value": @"v"}];
    [self invokeMethod:@"clear" arguments:@{}];
    XCTAssertNoThrow([self invokeMethod:@"clear" arguments:@{}]);
    XCTAssertNil([self invokeMethod:@"get" arguments:@{@"key": @"k"}]);
}

- (void)testClear_partialDataThenClear {
    // Store some keys, remove one, then clear – nothing should remain.
    [self invokeMethod:@"put"    arguments:@{@"key": @"a", @"value": @"1"}];
    [self invokeMethod:@"put"    arguments:@{@"key": @"b", @"value": @"2"}];
    [self invokeMethod:@"remove" arguments:@{@"key": @"a"}];
    [self invokeMethod:@"clear"  arguments:@{}];
    XCTAssertNil([self invokeMethod:@"get" arguments:@{@"key": @"b"}]);
}


// ---------------------------------------------------------------------------
// configure
// ---------------------------------------------------------------------------

- (void)testConfigure_defaultArgs_returnsNil {
    id result = [self invokeMethod:@"configure" arguments:@{}];
    XCTAssertNil(result, @"configure should return nil");
}

- (void)testConfigure_withNullArgs_returnsNil {
    id result = [self invokeMethod:@"configure"
                         arguments:@{@"accessGroup": [NSNull null],
                                     @"label": [NSNull null]}];
    XCTAssertNil(result);
}

- (void)testConfigure_withLabel_itemsStillRetrievable {
    // Reconfigure with a label, then verify basic put/get still works.
    [self invokeMethod:@"configure"
             arguments:@{@"label": @"Test Credentials"}];
    [self invokeMethod:@"put" arguments:@{@"key": @"lk", @"value": @"lv"}];
    XCTAssertEqualObjects([self invokeMethod:@"get" arguments:@{@"key": @"lk"}], @"lv");
    // Reset for subsequent tests.
    [self invokeMethod:@"configure" arguments:@{}];
}

- (void)testConfigure_withAccessGroup_doesNotThrow {
    // Using an access group requires an entitlement; on simulator without one
    // the put will silently fail. We just verify configure itself does not throw.
    XCTAssertNoThrow(
        [self invokeMethod:@"configure"
                 arguments:@{@"accessGroup": @"group.be.appmire.test"}]
    );
    // Reset for subsequent tests.
    [self invokeMethod:@"configure" arguments:@{}];
}

// ---------------------------------------------------------------------------
// Method channel – unimplemented method
// ---------------------------------------------------------------------------

- (void)testHandleMethodCall_unknownMethod_returnsNotImplemented {
    __block id returnValue = nil;
    FlutterMethodCall *call = [FlutterMethodCall methodCallWithMethodName:@"unknownMethod"
                                                               arguments:@{}];
    [self.plugin handleMethodCall:call result:^(id result) {
        returnValue = result;
    }];
    XCTAssertEqualObjects(returnValue, FlutterMethodNotImplemented,
                          @"Unknown methods must return FlutterMethodNotImplemented");
}

@end
