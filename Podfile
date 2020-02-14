# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

# Comment the next line if you're not using Swift and don't want to use dynamic frameworks
use_frameworks!

def shared_pods
    pod 'YapDatabase', '~> 4.0'
    pod 'Alamofire', '~> 4.8'
    pod 'FilesProvider', '~> 0.26'
    pod 'SwiftyDropbox', '~> 5.1'
    pod 'Localize', '~> 2.2'
    pod 'Eureka', '~> 5.1'
    pod 'ImageRow', '~> 4.0'
    pod 'UIImage-Resize', '~> 1.0'
    pod 'AlignedCollectionViewFlowLayout', '~> 1.1'
    pod 'DownloadButton', '~> 0.1'
    pod 'MBProgressHUD', '~> 1.1'
    pod 'ReachabilitySwift', '~> 4.3'
    pod 'FormatterKit', '~> 1.8'
    pod 'UIImageViewAlignedSwift', git: 'https://github.com/mirego/UIImageViewAlignedSwift.git'
    pod 'FontBlaster', '~> 5.1'
    pod 'CrossroadRegex', git: 'https://github.com/crossroadlabs/Regex.git', tag: '1.2.0'
end

def app_only
    pod 'FavIcon', git: 'https://github.com/tladesignz/FavIcon.git', branch: 'swift-5'
    pod 'TUSafariActivity', '~> 1.0'
    pod 'ARChromeActivity', '~> 1.0'
    pod 'SDCAlertView', '~> 10.0'
    pod 'TLPhotoPicker', '~> 2.0'
end

target 'OpenArchive' do
    shared_pods
    app_only
end

target 'ShareExtension' do
    shared_pods
end

target 'OpenArchive Screenshots' do
    shared_pods
    app_only
end
