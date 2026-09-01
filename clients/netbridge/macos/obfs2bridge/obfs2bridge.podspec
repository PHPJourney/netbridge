Pod::Spec.new do |s|
  s.name             = 'obfs2bridge'
  s.version          = '1.0.0'
  s.summary          = 'NetBridge obfs2 client bridge (gomobile xcframework)'
  s.description      = 'In-process obfs2 transport client for the NetBridge macOS app.'
  s.homepage         = 'https://netbridge.dev'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'NetBridge' => 'admin@libaoka.com' }
  s.platform         = :osx, '12.0'
  s.source           = { :path => '.' }
  s.vendored_frameworks = 'Obfs2bridge.xcframework'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
