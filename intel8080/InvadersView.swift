import SwiftUI
import CoreGraphics

struct Intel8080View: View {
    var invadersMachine = InvadersMachine()
    var testMachine = TestMachine()
    
    var body: some View {
        VStack(content: {
            InvadersViewBridge(machine: invadersMachine)
            
            HStack(content: {
                Button(action: stop) {
                    Text("TOGGLE PAUSE")
                }
                Button(action: play) {
                    Text("PLAY")
                }
            })
        })
    }
    
    func stop() {
        invadersMachine.toggleOnOff()
    }
    
    func play() {
        invadersMachine.load()
    }
}

struct InvadersViewBridge: NSViewRepresentable {
    let machine: InvadersMachine
    typealias NSViewType = InvadersView
    
    func makeNSView(context: Context) -> InvadersView {
        let view = InvadersView(machine: machine)
        
        DispatchQueue.main.async { [weak view] in
            // Match the window color space with the CGContext color space
            // to avoid sampling and improve performance.
            view?.window?.colorSpace = NSColorSpace.sRGB
            
            // Make first responder to catch keyboard events.
            view?.window?.makeFirstResponder(view)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: InvadersView, context: Context) {
        nsView.machine = machine
    }
}

class InvadersView: NSView {
    var machine: InvadersMachine
    var bitmap = UnsafeMutablePointer<UInt32>.allocate(capacity: 224 * 256)
    var pixels:  UnsafeMutableBufferPointer<UInt32>
    var timer: Timer?
    
    init(machine: InvadersMachine) {
        self.machine = machine

        self.pixels = UnsafeMutableBufferPointer<UInt32>(start: bitmap, count: 224 * 256)
        super.init(frame: .zero)

        self.timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(done), userInfo: nil, repeats: true)
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            self.keyDown(with: $0)
            return $0
        }
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
    
    @objc func done() {
        self.needsDisplay = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
                        pixels[offset - (p * 224)] = 0xFFFFFFFF
                    } else {
                        pixels[offset - (p * 224)] = 0x00000000
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Intel8080View()
            .frame(width: 500, height: 500)
    }
}
