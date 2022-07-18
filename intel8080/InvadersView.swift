import SwiftUI
import CoreGraphics

struct InvadersView: NSViewRepresentable {
    @Binding var game: Game.RawValue
    typealias NSViewType = InvadersNSView
    
    func makeNSView(context: Context) -> InvadersNSView {
        let view = InvadersNSView(game: game)
        
        DispatchQueue.main.async { [weak view] in
            // Match the window color space with the CGContext color space
            // to avoid sampling and improve performance.
            view?.window?.colorSpace = NSColorSpace.sRGB
            // Make view the first responder in order to catch keyboard events.
            view?.window?.makeFirstResponder(view)
            // Fix aspect ratio to game's aspect ratio (accounting for toolbar).
            view?.window?.aspectRatio = NSSize(width: 224, height: 256 + 26)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: InvadersNSView, context: Context) {
        nsView.game = game
    }
}

class InvadersNSView: NSView {
    var machine: InvadersMachine = InvadersMachine()
    
    var bitmap = UnsafeMutablePointer<UInt32>.allocate(capacity: 224 * 256)
    var pixels:  UnsafeMutableBufferPointer<UInt32>
    
    weak var timer: Timer?
    
    var colour: [UInt32] = UserDefaults.standard.array(forKey: "colours") as? [UInt32] ?? COLOURS[0]
    
    var game: Game.RawValue {
        didSet {
            machine.stop()
            machine = InvadersMachine()
            machine.load(game: game)
            machine.start()
        }
    }
    
    init(game: Game.RawValue) {
        self.pixels = UnsafeMutableBufferPointer<UInt32>(start: bitmap, count: 224 * 256)
        self.game = game
        
        super.init(frame: .zero)
        
        NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true, block: {[weak self] _ in
            self?.needsDisplay = true
        })
    }
    
    deinit {
        machine.stop()
        self.timer?.invalidate()
        self.timer = nil
        NotificationCenter.default.removeObserver(self, name: UserDefaults.didChangeNotification, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func userDefaultsDidChange(_ notification: Notification) {
        colour = UserDefaults.standard.array(forKey: "colours") as? [UInt32] ?? [UInt32]()
    }
    
    // Handle keyboard events.
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
                if (j%8 != 0) { continue }

                let pixel = machine.state.memory[0x2400 + (i * 32) + Int(j/8)];
                let offset: Int = (255 - j) * 224 + i;

                for p in 0..<8 {
                    if ((pixel & (1 << p)) != 0) {
                        pixels[offset - (p * 224)] = colour[j/32]
                    } else {
                        pixels[offset - (p * 224)] = colour[8]
                    }
                }
            }
        }

        guard let image = bitmapCtx.makeImage() else { return }
        guard let context = NSGraphicsContext.current else { return }
        let ctx = context.cgContext
        ctx.draw(image, in: self.frame)
    }
}

let COLOURS: [[UInt32]] = [
    [0xffdfe2ee, 0xffc5d7ee, 0xff9c9fc8, 0xff5d7cc9, 0xff5e6ab3, 0xff271601, 0xffd4ea41, 0xff3b4660, 0xff38312e],
    [0xff466ebe, 0xffb0e7cd, 0xffa8bfa3, 0xffa08672, 0xff4a5959, 0xff525544, 0xff4a4d29, 0xff1f0232, 0xff392e4b],
    [0xff75906e, 0xff9bc4ff, 0xffd3efff, 0xffc4b6ad, 0xff3500ff, 0xff9c938b, 0xff6c5459, 0xff5f4038, 0xff1f130e],
    [0xfff8f8f9, 0xffced3cd, 0xffbdb5bb, 0xffa36daa, 0xffa67792, 0xff271601, 0xff3517f7, 0xff1c9fff, 0xff464750],
    [0xff222921, 0xff364929, 0xff59623e, 0xff66825b, 0xffc7f6ae, 0xffd7d9d7, 0xffcbc5c9, 0xffffebff, 0xffae8eb4],
    [0xff89d2ff, 0xff88c6f9, 0xff7db1f9, 0xff2a81fc, 0xff0066a5, 0xffcbc5b7, 0xff4a8383, 0xff686868, 0xff474747],
    [0xffacb0d5, 0xffaea0ce, 0xff514568, 0xff2a2e40, 0xff8fd09c, 0xff8c7900, 0xff5b3d00, 0xff1f1700, 0xffa77e00]
]
