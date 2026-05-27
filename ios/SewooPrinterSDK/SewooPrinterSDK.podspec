Pod::Spec.new do |s|
  s.name = 'SewooPrinterSDK'
  s.version = '1.90.0'
  s.summary = 'Sewoo iOS Printer SDK for LK mobile printers.'
  s.description = 'Local vendored Sewoo PrinterSDK.xcframework used by Controller App Flutter.'
  s.homepage = 'https://www.miniprinter.com'
  s.license = { :type => 'Commercial', :text => 'Provided by Sewoo.' }
  s.author = { 'Sewoo' => 'support@miniprinter.com' }
  s.platform = :ios, '15.0'
  s.source = { :path => '.' }
  s.vendored_frameworks = 'PrinterSDK.xcframework'
  s.frameworks = 'ExternalAccessory', 'UIKit', 'Foundation'
end
