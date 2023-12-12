#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_keychain.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_keychain'
  s.version          = '2.3.1'
  s.summary          = 'Flutter secure storage via Keychain and Keystore'
  s.description      = <<-DESC
Flutter secure storage via Keychain and Keystore
                       DESC
  s.homepage         = 'https://github.com/jeroentrappers/flutter_keychain'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Jeroen Trappers' => 'jeroen@apple.be' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
