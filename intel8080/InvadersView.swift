import SwiftUI
import CoreGraphics

struct InvadersContainer: View {
    var machine = InvadersMachine()
    
    var body: some View {
        VStack(content: {
            InvadersViewRep(machine: machine)
            
            Button(action: stop) {
                Text("STOP")
            }
        })
    }
    
    func stop() {
        machine.stop()
    }
}

struct InvadersViewRep: NSViewRepresentable {
    let machine: InvadersMachine
    typealias NSViewType = InvadersView
    
    func makeNSView(context: Context) -> InvadersView {
        return InvadersView(machine: machine)
    }
    
    func updateNSView(_ nsView: InvadersView, context: Context) {
        nsView.machine = machine
    }
}

class InvadersView: NSView {
    var machine: InvadersMachine
    var bitmapCtx: CGContext
    var bitmap = UnsafeMutablePointer<UInt32>.allocate(capacity: 224 * 256)
    var timer: Timer?
    
    var iter: Int = 0
    
    init(machine: InvadersMachine) {
        self.machine = machine
        self.machine.start()
        
        self.bitmapCtx = CGContext(
            data: bitmap,
            width: 224,
            height: 256,
            bitsPerComponent: 8,
            bytesPerRow: 224 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        )!

        super.init(frame: .zero)

        self.timer = Timer.scheduledTimer(timeInterval: 0.016, target: self, selector: #selector(setNeedsDisplay(_:)), userInfo: nil, repeats: true)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: CGRect) {
        let pixels = UnsafeMutableBufferPointer<UInt32>(start: bitmap, count: 224 * 256)
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
        ctx.draw(image, in: self.visibleRect)
        
        self.setNeedsDisplay(_:dirtyRect)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        InvadersContainer()
            .frame(width: 500, height: 500)
    }
}
