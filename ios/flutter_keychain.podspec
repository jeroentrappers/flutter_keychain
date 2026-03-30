Pod::Spec.new do |s|
  s.name             = 'flutter_keychain'
  s.version          = '3.0.0'
  s.summary          = 'Flutter secure storage via native Keychain (iOS) and Keystore (Android).'
  s.description      = <<-DESC
    Flutter plugin for secure string storage using the iOS Keychain and Android Keystore.
    Supports optional access groups (kSecAttrAccessGroup) for cross-app sharing and
    item labels (kSecAttrLabel) for iOS Passwords visibility.
  DESC
  s.homepage         = 'https://github.com/jeroentrappers/flutter_keychain'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Jeroen Trappers' => 'jeroen@apple.be' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.ios.deployment_target = '12.0'
end
