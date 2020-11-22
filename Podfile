# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'CommonplaceBookApp' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  platform :ios, '14.0'

  # Pods for remember
  pod 'DataCompression'

  target 'CommonplaceBookAppTests' do
    inherit! :search_paths
    # Pods for testing
  end

  post_install do |installer|
    installer.pods_project.main_group.tab_width = '2';
    installer.pods_project.main_group.indent_width = '2';
  end
end
