#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'crypt_local_data'
  s.version          = '0.1.1'
  s.summary          = 'Crypted Encrypted Local Data'
  s.description      = <<-DESC
Crypted Encrypted Local Data
                       DESC
  s.homepage         = 'https://github.com/Sigma-Softwares/crypt_local_data'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Sigma Softwares' => 'softwareteam@sigmatelecom.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  
  s.ios.deployment_target = '8.0'
end

