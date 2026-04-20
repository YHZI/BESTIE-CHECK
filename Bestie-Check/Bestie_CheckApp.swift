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
        // 在 App 启动时就开始预热相机 session，
        // 让用户打开 Share 界面时立即看到实时画面
        _ = SharedCameraSession.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
