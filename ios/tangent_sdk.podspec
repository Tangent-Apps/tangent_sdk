Pod::Spec.new do |s|
  s.name             = 'tangent_sdk'
  s.version          = '0.2.0'
  s.summary          = 'Native billing issue detection for Tangent SDK'
  s.description      = 'Provides StoreKit 2 billing issue detection via platform channels.'
  s.homepage         = 'https://github.com/Tangent-Apps/tangent-sdk'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Tangent Apps' => 'dev@tangentapps.com' }
  s.source           = { :http => 'https://github.com/Tangent-Apps/tangent-sdk' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
