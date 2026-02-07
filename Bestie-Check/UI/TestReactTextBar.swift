//
//  TestReactTextBar.swift
//  Bestie-Check
//
//  Test file to verify ReactTextBar component
//

import SwiftUI

struct TestReactTextBarView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                ReactTextBar(text: "Test bubble message")
                    .padding()
                
                Text("If you can see the bubble above, ReactTextBar is working!")
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}

#Preview {
    TestReactTextBarView()
}
