//
//  Bestie_CheckApp.swift
//  Bestie-Check
//
//  Created by mike on 1/27/26.
//

import SwiftUI

@main
struct Bestie_CheckApp: App {
    init() {
        // 触发资源预加载器（非阻塞，在后台并行加载所有资源）
        _ = ResourcePreloader.shared
        print("🚀 App initialized, resource preloading started in background")
    }

    var body: some Scene {
        WindowGroup {
            LaunchLoadingContainerView()
        }
    }
}
