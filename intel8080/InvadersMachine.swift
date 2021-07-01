import Cocoa

class InvadersMachine: NSObject {
    public var state: State8080 = State8080()
    public var io: IO?
    
    // The Space Invaders machine implements its own multi-byte
    // shift routine to improve rendering performance.
    var shiftX: UInt8 = 0
    var shiftY: UInt8 = 0
    var shiftOffset: UInt8 = 0
    
    var port1: UInt8 = 0
    var lastInterrupt: Double = 0
    var whichInterrupt: UInt16 = 2
    
    var lastTimer: Double?
    var timer: Timer?
    
    func input(port: UInt8) -> UInt8 {
        switch port {
        case 0: return 1
        case 1: return 0
        case 3:
            let pair = (UInt16(shiftX) << 8) | (UInt16(shiftY))
            return UInt8((pair >> (8 - shiftOffset)) & 0xff)
        default: return 0
        }
    }
    
    func output(port: UInt8, value: UInt8) {
        switch port {
        case 2:
            self.shiftOffset = value
        case 4:
            self.shiftY = self.shiftX
            self.shiftX = value
        default: ()
        }
    }
    
    func keyDown(code: UInt16) {
        switch code {
        // Left: set bit 5 (left)
        case 123: port1 |= 0b00100000
        // Right: set bit 6 (right)
        case 124: port1 |= 0b01000000
        // Up: set bit 4 (shoot)
        case 126: port1 |= 0b00010000
        // Enter: set bit 2 (start)
        case 36: port1 |= 0b00000100
        default: ()
        }
    }
        
    func keyUp(code: UInt16) {
        switch code {
        // Left: unset bit 5 (left)
        case 123: port1 &= 0b11011111
        // Right: unset bit 6 (right)
        case 124: port1 &= 0b10111111
        // Up: unset bit 4 (shoot)
        case 126: port1 &= 0b11101111
        // Enter: unset bit 2 (start)
        case 36: port1 &= 0b11111011
        default: ()
        }
    }
    
    func interrupt(state: inout State8080, num: UInt16) {
        let MSB = UInt8((state.pc >> 8) & 0xff)
        let LSB = UInt8(state.pc & 0xff)
        state.memory[Int(state.sp) &- 1] = MSB
        state.memory[Int(state.sp) &- 2] = LSB
        state.sp = state.sp &- 2
        
        state.intEnable = 0
        state.pc = num * 8
    }
    
    public func load() {
        let filePath = Bundle.main.path(forResource: "invaders", ofType: "rom", inDirectory: "roms")
        let data = NSData(contentsOfFile: filePath!)!
        let dataBuffer = [UInt8](data)
        
        for (index, byte) in dataBuffer.enumerated() {
            state.memory[index] = byte
        }
        
        io = IO(input: input, output: output)
        
        toggleOnOff()
    }
    
    @objc func run() {
        // Interrupt handling
        if (CACurrentMediaTime() - self.lastInterrupt > (1/100) && state.intEnable == 1) {
            if (whichInterrupt == 1) {
                interrupt(state: &state, num: whichInterrupt)
                whichInterrupt = 2
            } else if (whichInterrupt == 2) {
                interrupt(state: &state, num: whichInterrupt)
                whichInterrupt = 1
            }
            self.lastInterrupt = CACurrentMediaTime()
        }
        
        let elapsedTime = CACurrentMediaTime() - lastTimer!
        // Emulate CPU running at 2MHz (2,000,000 cycles/second)
        let elapsedCycles = Int(elapsedTime * 2000000)
        
        while (state.cycle < elapsedCycles) {
            emulateOperation(state: &state, io: io!)
        }
    
        state.cycle = 0
        self.lastTimer = CACurrentMediaTime()
    }
    
    public func toggleOnOff() {
        if (timer == nil) {
            lastTimer = CACurrentMediaTime()
            timer = Timer.scheduledTimer(timeInterval: 0.005, target: self, selector: #selector(run), userInfo: nil, repeats: true)
        } else {
            timer?.invalidate()
            timer = nil
        }
    }
    
    public func reset() {
        timer?.invalidate()
        timer = nil
        state = State8080()
        load()
    }
}
