source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '9.2'
use_frameworks!

def library
    pod 'Alamofire'
    pod 'ICSMainFramework', :path => "./Library/ICSMainFramework/"
    pod 'MMWormhole', '~> 2.0.0'
    pod "MMDB-Swift"
end

def tunnel
    pod 'MMWormhole', '~> 2.0.0'
end

def socket
    pod 'CocoaAsyncSocket', '~> 7.4.3'
end

def model
    pod 'RealmSwift', '~> 3.16.2'
    pod 'ObjectMapper', '3.4.2'
end

target "Potatso" do
    pod 'Alamofire'
    pod 'Aspects', :path => "./Library/Aspects/"
    pod 'Cartography', '4.0.0'
    pod 'AsyncSwift'
    pod 'SwiftColor'
    pod 'Eureka', '~> 4.3.0'
    pod 'MBProgressHUD'
    pod 'CallbackURLKit'
    pod 'SVPullToRefresh', :git => 'https://github.com/samvermette/SVPullToRefresh'
    pod 'ObjectMapper', '3.4.2'
    pod 'PSOperations', '~> 4.0'
#    pod 'PSOperations/Core'
    pod 'Fabric'
    pod 'Crashlytics'
    pod "EFQRCode", '~> 1.2.5'
    tunnel
    library
    socket
    model
end

target "PacketTunnel" do
    tunnel
    socket
end

target "PacketProcessor" do
    socket
end

target "TodayWidget" do
    pod 'Cartography'
    pod 'SwiftColor'
    library
    socket
    model
end

target "PotatsoLibrary" do
    library
    model
end

target "PotatsoModel" do
    model
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['ENABLE_BITCODE'] = 'NO'
        end
    end
end

