import SwiftUI
import CoreGraphics

let COLORS: [[UInt32]] = [
    [0xffdfe2ee, 0xffc5d7ee, 0xff9c9fc8, 0xff5d7cc9, 0xff5e6ab3, 0xff271601, 0xffd4ea41, 0xff3b4660, 0xff38312e],
    [0xff466ebe, 0xffb0e7cd, 0xffa8bfa3, 0xffa08672, 0xff4a5959, 0xff525544, 0xff4a4d29, 0xff1f0232, 0xff392e4b],
    [0xff75906e, 0xff9bc4ff, 0xffd3efff, 0xffc4b6ad, 0xff3500ff, 0xff9c938b, 0xff6c5459, 0xff5f4038, 0xff1f130e],
    [0xfff8f8f9, 0xffced3cd, 0xffbdb5bb, 0xffa36daa, 0xffa67792, 0xff271601, 0xff3517f7, 0xff1c9fff, 0xff464750],
    [0xff222921, 0xff364929, 0xff59623e, 0xff66825b, 0xffc7f6ae, 0xffd7d9d7, 0xffcbc5c9, 0xffffebff, 0xffae8eb4],
    [0xff89d2ff, 0xff88c6f9, 0xff7db1f9, 0xff2a81fc, 0xff0066a5, 0xffcbc5b7, 0xff4a8383, 0xff686868, 0xff474747],
    [0xffacb0d5, 0xffaea0ce, 0xff514568, 0xff2a2e40, 0xff8fd09c, 0xff8c7900, 0xff5b3d00, 0xff1f1700, 0xffa77e00]
]

class Settings: ObservableObject {
    @Published var color: [UInt32] = [0xffacb0d5, 0xffaea0ce, 0xff514568, 0xff2a2e40, 0xff8fd09c, 0xff8c7900, 0xff5b3d00, 0xff1f1700, 0xffa77e00]
}

struct Intel8080View: View {
    @ObservedObject var settings: Settings = Settings()
    var testMachine = TestMachine()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Game.allCases, id: \.rawValue) { game in
                    NavigationLink(
                        destination: NavigationLazyView(InvadersView(game: game.rawValue)),
                        label: {
                            Text(game.rawValue)
                        })
                }
            }
        }.toolbar(content: {
            ToolbarItem(placement: .primaryAction) {
                Button(
                    action: changeColour,
                    label: {
                        Image(systemName: "paintbrush")
                            .font(Font.system(.largeTitle))
                    })
            }
        })
    }
    
    func changeColour() {
//        let colorIndex = (COLORS.firstIndex(of: settings.color) + 1) % COLORS.count
//        settings.color = COLORS[colorIndex]
    }
}

struct InvadersView: NSViewRepresentable {
    let game: Game.RawValue
    typealias NSViewType = InvadersNSView
    
    func makeNSView(context: Context) -> InvadersNSView {
        let view = InvadersNSView(game: game)
        
        DispatchQueue.main.async { [weak view] in
            // Match the window color space with the CGContext color space
            // to avoid sampling and improve performance.
            view?.window?.colorSpace = NSColorSpace.sRGB
            
            // Make first responder to catch keyboard events.
            view?.window?.makeFirstResponder(view)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: InvadersNSView, context: Context) {
    }
}

class InvadersNSView: NSView {
    var machine: InvadersMachine = InvadersMachine()
    @StateObject var settings = Settings()
    
    var bitmap = UnsafeMutablePointer<UInt32>.allocate(capacity: 224 * 256)
    var pixels:  UnsafeMutableBufferPointer<UInt32>
    
    weak var timer: Timer?
    
    var color: [UInt32] = [0xffacb0d5, 0xffaea0ce, 0xff514568, 0xff2a2e40, 0xff8fd09c, 0xff8c7900, 0xff5b3d00, 0xff1f1700, 0xffa77e00]
    
    init(game: Game.RawValue) {
        self.pixels = UnsafeMutableBufferPointer<UInt32>(start: bitmap, count: 224 * 256)
        machine.load(game: game)
        
        super.init(frame: .zero)
        
        machine.start()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true, block: {[weak self] _ in
            self?.needsDisplay = true
        })
    }
    
    deinit {
        machine.stop()
        self.timer?.invalidate()
        self.timer = nil
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Handle keyboard events
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {
        let wasHandled = machine.keyDown(code: event.keyCode)
        if (!wasHandled) { super.keyDown(with: event) }
    }
    override func keyUp(with event: NSEvent) {
        let wasHandled = machine.keyUp(code: event.keyCode)
        if (!wasHandled) { super.keyUp(with: event) }
    }
    
    override func draw(_ dirtyRect: CGRect) {
        let bitmapCtx = CGContext(
            data: bitmap,
            width: 224,
            height: 256,
            bitsPerComponent: 8,
            bytesPerRow: 224 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        
        for i in 0..<224 {
            for j in 0..<256 {
                let (quotient, remainder) = j.quotientAndRemainder(dividingBy: 8)

                let pixel = machine.state.memory[0x2400 + (i * 32) + quotient];
                let offset: Int = ((255 - (quotient * 8)) * 224) + i - (remainder * 224);

                if ((pixel & (1 << remainder)) != 0) {
                    pixels[offset] = color[j/32]
                } else {
                    pixels[offset] = color[8]
                }
            }
        }

        guard let image = bitmapCtx.makeImage() else { return }
        guard let context = NSGraphicsContext.current else { return }
        let ctx = context.cgContext
        ctx.draw(image, in: self.frame)
    }
}

struct NavigationLazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Intel8080View()
            .frame(width: 500, height: 500)
    }
}
