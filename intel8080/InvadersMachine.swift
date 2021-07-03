import Cocoa

enum Game: String, Equatable, CaseIterable {
    case SpaceInvaders = "Space Invaders"
    case BalloonBomber = "Balloon Bomber"
    case LunarRescue = "Lunar Rescue"
}

class InvadersMachine: NSObject {
    public var state: State8080 = State8080()
    public var io: IO?
    
    // The Space Invaders machine implements its own multi-byte
    // shift routine to improve rendering performance.
    var shiftX: UInt8 = 0
    var shiftY: UInt8 = 0
    var shiftOffset: UInt8 = 0
    
    // The CPU will poll these ports to see which keys are pressed.
    var port1: UInt8 = 0
    var port2: UInt8 = 0
    
    // The CPU will set these ports, and the machine
    // polls them to know which sounds to play.
    var port3: (curr: UInt8, prev: UInt8) = (0, 0)
    var port5: (curr: UInt8, prev: UInt8) = (0, 0)
    
    var muted: Bool = true
    var sounds: [NSSound] = []
    
    // Used to keep track of interrupts.
    var lastInterrupt: Double = 0
    var whichInterrupt: UInt16 = 2
    
    var lastTimer: Double?
    public var timer: Timer?
    
    override init() {
        super.init()
        self.io = IO(input: input, output: output)
    }
    
    func input(port: UInt8) -> UInt8 {
        switch port {
        case 0: return self.port2
        case 1: return self.port1
        case 3:
            let pair = (UInt16(self.shiftX) << 8) | (UInt16(self.shiftY))
            return UInt8((pair >> (8 - self.shiftOffset)) & 0xff)
        default: return 0
        }
    }
    
    func output(port: UInt8, value: UInt8) {
        switch port {
        case 2: self.shiftOffset = value
        case 3: self.port3 = (curr: value, prev: self.port3.curr)
        case 4:
            self.shiftY = self.shiftX
            self.shiftX = value
        case 5: self.port5 = (curr: value, prev: self.port5.curr)
        default: ()
        }
        
        playSounds()
    }
    
    func initSounds() {
        var paths = Bundle.main.paths(forResourcesOfType: "wav", inDirectory: "sounds")
        paths.sort()
        sounds = paths.map {
            NSSound(contentsOfFile: $0, byReference: true)!
        }
    }
    
    func playSounds() {
        if (muted) { return }
        
        let port3Bits = (port3.curr ^ port3.prev) & port3.curr
        let port5Bits = (port5.curr ^ port5.prev) & port5.curr
        
        if (port3Bits & 0x2 != 0) { sounds[1].play() }
        if (port3Bits & 0x4 != 0) { sounds[2].play() }
        if (port3Bits & 0x8 != 0) { sounds[3].play() }
        
        if (port5Bits & 0x1 != 0) { sounds[4].play() }
        if (port5Bits & 0x2 != 0) { sounds[5].play() }
        if (port5Bits & 0x4 != 0) { sounds[6].play() }
        if (port5Bits & 0x8 != 0) { sounds[7].play() }
    }
    
    func toggleMute() {
        muted = !muted
    }
    
    func keyDown(code: UInt16) -> Bool {
        switch code {
        // Left: set bit 5 (left)
        case 123: port1 |= 0b00100000
        // Right: set bit 6 (right)
        case 124: port1 |= 0b01000000
        // Up/Space: set bit 4 (shoot)
        case 126, 49: port1 |= 0b00010000
        // Enter: set bit 2 (start)
        case 36: port1 |= 0b00000100
        // C: set bit 5 (coin)
        case 8: port1 |= 0b00000001
        default: return false
        }
        
        return true
    }
        
    func keyUp(code: UInt16) -> Bool {
        switch code {
        // Left: unset bit 5 (left)
        case 123: port1 &= 0b11011111
        // Right: unset bit 6 (right)
        case 124: port1 &= 0b10111111
        // Up: unset bit 4 (shoot)
        case 126, 49: port1 &= 0b11101111
        // Enter: unset bit 2 (start)
        case 36: port1 &= 0b11111011
        // C: unset bit 5 (coin)
        case 8: port1 &= 0b11111110
        default: return false
        }
        
        return true
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
    
    func copyData(data: NSData, memOffset: Int) {
        let dataBuffer = [UInt8](data)
        
        for (index, byte) in dataBuffer.enumerated() {
            state.memory[memOffset + index] = byte
        }
    }
    
    public func load(game: Game.RawValue) {
        switch (game) {
        case Game.BalloonBomber.rawValue:
            let ballbombData: [(String, Int)] = [("tn01", 0x0000), ("tn02", 0x0800), ("tn03", 0x1000), ("tn04", 0x1800), ("tn05-1", 0x4000)]
            for data in ballbombData {
                copyData(
                    data: NSData(contentsOfFile: Bundle.main.path(forResource: data.0, ofType: nil, inDirectory: "roms/ballbomb")!)!,
                    memOffset: data.1
                )
            }
        
        case Game.SpaceInvaders.rawValue:
            copyData(
                data: NSData(contentsOfFile: Bundle.main.path(forResource: "invaders", ofType: "rom", inDirectory: "roms")!)!,
                memOffset: 0
            )
        
        case Game.LunarRescue.rawValue:
            copyData(
                data: NSData(contentsOfFile: Bundle.main.path(forResource: "lrescue", ofType: "rom", inDirectory: "roms")!)!,
                memOffset: 0
            )
        default: ()
        }
        
        initSounds()
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
            emulateOperation(state: &state, io: io)
        }
    
        state.cycle = 0
        self.lastTimer = CACurrentMediaTime()
    }
    
    public func start() {
        if (timer != nil) { stop() }

        lastTimer = CACurrentMediaTime()
        timer = Timer.scheduledTimer(timeInterval: 0.005, target: self, selector: #selector(run), userInfo: nil, repeats: true)
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
    }
}
