# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'CommonplaceBookApp' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  platform :ios, '11.0'

  # Pods for remember
  # pod 'CommonplaceBook', :path => '../CommonplaceBook'
  pod 'CommonplaceBook', :git => 'https://github.com/bdewey/CommonplaceBook.git'
  pod 'CwlSignal', :git => 'https://github.com/bdewey/CwlSignal'
  pod 'CwlUtils', :git => 'https://github.com/bdewey/CwlUtils'
  pod 'IGListKit', '~> 3.0'
  # pod 'MiniMarkdown', :path => '../MiniMarkdown', :testspecs => ['Tests']
  pod 'MiniMarkdown', :git => 'https://github.com/bdewey/MiniMarkdown', :testspecs => ['Tests']
  pod 'MaterialComponents', :git => 'https://github.com/material-components/material-components-ios'
  pod 'SwipeCellKit', :git => 'https://github.com/SwipeCellKit/SwipeCellKit.git', :branch => 'swift_4.2'
  # pod 'TextBundleKit', :path => '../textbundle-swift', :testspecs => ['Tests']
  pod 'TextBundleKit', :git => 'https://github.com/bdewey/textbundle-swift', :testspecs => ['Tests']

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
