import SwiftUI

@main
struct Intel8080App: App {
    var body: some Scene {
        WindowGroup {
            Intel8080View()
        }.windowStyle(HiddenTitleBarWindowStyle())
    }
}

struct Intel8080View: View {
    @State private var selectedGame = Game.SpaceInvaders.rawValue
    @AppStorage("muted") var muted = false
    @AppStorage("paused") var paused = false
    
    func changeColour() {
        let colours = UserDefaults.standard.array(forKey: "colours") as? [UInt32] ?? [UInt32]()
        let colorIndex = ((COLOURS.firstIndex(of: colours) ?? 0) + 1) % COLOURS.count
        UserDefaults.standard.set(COLOURS[colorIndex], forKey: "colours")
    }
    
    var body: some View {
        VStack {
            InvadersView(game: $selectedGame)
        }.toolbar(content: {
            ToolbarItemGroup(placement: .navigation) {
                Picker("Game", selection: $selectedGame) {
                    ForEach(Game.allCases, id: \.rawValue) { game in
                        Text(game.rawValue)
                    }
                }
            }
            ToolbarItem() { Spacer() }
            ToolbarItem() {
                Button(action: { muted = !muted }) {
                        Image(systemName: muted ? "speaker" : "speaker.slash")
                            .font(Font.system(.headline))
                    }.help("Toggle sound")
            }
            ToolbarItem() {
                Button(action: changeColour) {
                        Image(systemName: "paintbrush")
                            .font(Font.system(.headline))
                    }.help("Change colour")
            }
            ToolbarItem() {
                Button(action: { paused = !paused }) {
                        Image(systemName: paused ? "play.circle" : "pause.circle")
                            .font(Font.system(.headline))
                    }.help(paused ? "Resume game" : "Pause game")
            }
        })
    }
}
