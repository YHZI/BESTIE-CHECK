# Podfile for Face Mesh AI Bubble Demo
# 使用 CocoaPods 集成 MediaPipe Tasks Vision

platform :ios, '15.0'
use_frameworks!

target 'Bestie-Check' do
  # MediaPipe Tasks Vision (Face Landmarker)
  pod 'MediaPipeTasksVision'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
