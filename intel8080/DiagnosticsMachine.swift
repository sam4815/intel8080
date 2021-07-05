import Cocoa

class DiagnosticsMachine: NSObject {
    public var state: State8080 = State8080()
    
    public var consoleBuffer: [String] = []
    
    var lastTimer: Double?
    var timer: Timer?
    
    public func load() {
        let filePath = Bundle.main.path(forResource: "8080EXER", ofType: "COM", inDirectory: "roms")
        let data = NSData(contentsOfFile: filePath!)!
        let dataBuffer = [UInt8](data)
        
        // Inject RET (0xC9) at 0x0005 to handle CALL 5 (signalling test completion)
        state.memory[0x0005] = 0xc9;

        // Tests begin at 0x0100
        state.pc = 0x0100
        for (index, byte) in dataBuffer.enumerated() {
            state.memory[index + 0x0100] = byte
        }
        
        lastTimer = CACurrentMediaTime()
        timer = Timer.scheduledTimer(timeInterval: 0.005, target: self, selector: #selector(run), userInfo: nil, repeats: true)
    }
    
    @objc func run() {
        let elapsedTime = CACurrentMediaTime() - lastTimer!
        // Emulate CPU running at 2MHz (2,000,000 cycles/second)
        let elapsedCycles = Int(elapsedTime * 2000000)
        
        while (state.cycle < elapsedCycles) {
            // Write characters to console
            if (state.pc == 0x0005) {
                storeTestOutput()
            }
            
            if (state.pc == 0) {
                print("TEST SUITE COMPLETE")
                break;
            }
            
            emulateOperation(state: &state, io: nil)
        }
    
        state.cycle = 0
        self.lastTimer = CACurrentMediaTime()
    }
    
    func storeTestOutput() {
        if (state.c == 0x0009) {
            var de = (UInt16(state.d) << 8) | UInt16(state.e)
            var line = ""
            var char = ""
            
            while (char != "$") {
                line += char
                de = de &+ 1
                char = String(UnicodeScalar(state.memory[Int(de)]))
            }
            
            consoleBuffer.append(line)
        }
        
        if (state.c == 0x0002) {
            consoleBuffer.append(String(UnicodeScalar(state.e)))
        }
    }
    
    public func exit() {
        print("TEST SUITE TERMINATED")
        timer?.invalidate()
    }
}
