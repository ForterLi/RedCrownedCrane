
Pod::Spec.new do |s|

  s.name     = "RedCrownedCrane"
  s.version  = "1.0.0"
  
  s.license  = { :type => 'MIT', :file => 'LICENSE' }
  s.summary  = "Local databases can be synchronized to iCloud using Sqlite Realm WCDB"
  s.homepage = "https://github.com/ForterLi/RedCrownedCrane.git"
  s.author   = { "liyongqiang" => "forterli@163.com" }
  s.source   = {:git => "https://github.com/ForterLi/RedCrownedCrane.git", :tag => s.version}
  s.module_name = 'RedCrownedCrane'

  s.swift_versions = ['5.7']
  s.platform     = :ios, "11.0"
  s.ios.deployment_target = '11.0'
  s.osx.deployment_target = '10.13'
  s.tvos.deployment_target = '11.0'
  s.watchos.deployment_target = '4.0'

  s.requires_arc = true
  s.source_files  = 'Source/*.{h,m,swift}'
  s.framework = 'Foundation','UIKit'

   
end

