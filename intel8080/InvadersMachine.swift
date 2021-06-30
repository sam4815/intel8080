import Cocoa

class InvadersMachine: NSObject {
    public var state: State8080 = State8080()
    var shiftOffset: UInt8 = 0
    var shiftX: UInt8 = 0
    var shiftY: UInt8 = 0
    var port1: UInt8 = 0
    var running: Bool = false
    var lastInterrupt: Double = 0
    var whichInterrupt: UInt16 = 2
    var lastTimer: Double = CACurrentMediaTime()
    var timer: Timer?
    
    public func stop() {
        print("STOPPED")
        timer?.invalidate()
    }
    
    func input(port: UInt8) -> UInt8 {
        switch port {
        case 0:
            return 1
        case 1:
            return 0
        case 3:
            let pair = (UInt16(shiftX) << 8) | (UInt16(shiftY))
            return UInt8((pair >> (8 - shiftOffset)) & 0xff)
        default:
//            print("ERROR ACCESSING INPUT PORT")
            return 0
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
//            print("ERROR ACCESSING OUTPUT PORT")
        }
    }
    
    func keyDown(code: UInt16) {
        switch code {
        // Left
        case 123:
            port1 |= 0b00100000 // Set bit 5 (left)
        // Right
        case 124:
            port1 |= 0b01000000 // Set bit 6 (right)
        // Up
        case 126:
            port1 |= 0b00010000 // Set bit 4 (shoot)
        // Enter
        case 36:
            port1 |= 0b00000100 // Set bit 2 (start)
        default: ()
        }
    }
        
    func keyUp(code: UInt16) {
        switch code {
        // Left
        case 123:
            port1 &= 0b11011111 // Unset bit 5 (left)
        // Right
        case 124:
            port1 &= 0b10111111 // Unset bit 6 (right)
        // Up
        case 126:
            port1 &= 0b11101111 // Unset bit 4 (shoot)
        // Enter
        case 36:
            port1 &= 0b11111011 // Unset bit 2 (start)
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
    
    public func start() {
        let filePath = Bundle.main.path(forResource: "invaders", ofType: "rom")
        let data = NSData(contentsOfFile: filePath!)!
        let dataBuffer = [UInt8](data)

        for (index, byte) in dataBuffer.enumerated() {
            state.memory[index] = byte
        }
        
        timer = Timer.scheduledTimer(timeInterval: 0.005, target: self, selector: #selector(run), userInfo: nil, repeats: true)
    }
    
    @objc func run() {
        if (self.running == true) {
            return
        }
        self.running = true
        // Interrupt handling
        if (CACurrentMediaTime() - self.lastInterrupt > (1/60) && state.intEnable == 1) {
            if (whichInterrupt == 1) {
                interrupt(state: &state, num: whichInterrupt)
                whichInterrupt = 2
            } else if (whichInterrupt == 2) {
                interrupt(state: &state, num: whichInterrupt)
                whichInterrupt = 1
            }
            self.lastInterrupt = CACurrentMediaTime()
        }
        
        let elapsedTime = CACurrentMediaTime() - lastTimer
        // Emulate CPU running at 2MHz (2,000,000 cycles/second)
        let elapsedCycles = Int(elapsedTime * 2000000)
        
        while (state.cycle < elapsedCycles) {
            let opcode = state.memory[Int(state.pc)]
            // IN D8
            if (opcode == 0xdb) {
                state.a = input(port: state.memory[Int(state.pc) &+ 1])
                state.pc += 2
//                print(state.pc)
                continue
            }
            
            // OUT D8
            if (opcode == 0xd3) {
                output(port: state.memory[Int(state.pc) &+ 1], value: state.a)
                state.pc += 2
//                print(state.pc)
                continue
            }
            
            emulateOperation(state: &state)
        }
    
        state.cycle = 0
        self.lastTimer = CACurrentMediaTime()
        self.running = false
    }
}
