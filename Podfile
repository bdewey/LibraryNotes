# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'CommonplaceBookApp' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  platform :ios, '13.0'

  # Pods for remember
  pod 'CocoaLumberjack/Swift'
  pod 'DataCompression'
  pod 'SnapKit'
  pod 'Yams'

  target 'CommonplaceBookAppTests' do
    inherit! :search_paths
    # Pods for testing
  end

  swift_4_1_pod_targets = ['CwlSignal', 'CwlUtils']

  post_install do |installer|
    installer.pods_project.main_group.tab_width = '2';
    installer.pods_project.main_group.indent_width = '2';
    installer.pods_project.targets.each do |target|
      if swift_4_1_pod_targets.include?(target.name)
        target.build_configurations.each do |config|
          config.build_settings['SWIFT_VERSION'] = '4.1'
        end
      end
    end
  end
end
