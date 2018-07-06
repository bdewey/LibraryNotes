# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'CommonplaceBookApp' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  platform :ios, '11.0'

  # Pods for remember
  pod 'CommonplaceBook', :path => '../CommonplaceBook'
  pod 'MiniMarkdown', :path => '../MiniMarkdown'
  pod 'MaterialComponents', :git => 'https://github.com/material-components/material-components-ios'
  pod 'Yoga', :git => 'https://github.com/facebook/yoga', :tag => '1.7.0'
  pod 'YogaKit', :git => 'https://github.com/facebook/yoga', :tag => '1.7.0'

  target 'CommonplaceBookAppTests' do
    inherit! :search_paths
    # Pods for testing
  end

end
