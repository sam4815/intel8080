import SwiftUI

@main
struct intel8080App: App {
    var body: some Scene {
        WindowGroup {
            Intel8080View()
        }.windowStyle(HiddenTitleBarWindowStyle())
    }
}
