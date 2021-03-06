import Foundation

struct State8080 {
    var a: UInt8 = 0
    var b: UInt8 = 0
    var c: UInt8 = 0
    var d: UInt8 = 0
    var e: UInt8 = 0
    var h: UInt8 = 0
    var l: UInt8 = 0
    var sp: UInt16 = 0
    var pc: UInt16 = 0
    var memory: Array<UInt8> = Array.init(repeating: 0, count: 0x10000)
    var cc: ConditionCodes = ConditionCodes()
    var intEnable: UInt8 = 0
    var cycle: Int = 0
}

struct ConditionCodes {
    var z: UInt8 = 0
    var s: UInt8 = 0
    var p: UInt8 = 0
    var cy: UInt8 = 0
    var ac: UInt8 = 0
    var pad: UInt8 = 0
}

struct IO {
    let input: (UInt8) -> UInt8
    let output: (UInt8, UInt8) -> Void
}

enum Register: UInt8 {
    case B = 0
    case C = 1
    case D = 2
    case E = 3
    case H = 4
    case L = 5
    case M = 6
    case A = 7
}
    
enum RegisterPair: UInt8 {
    case BC = 0
    case DE = 1
    case HL = 2
    case SP = 3
}

// Return 1 for even parity; 0 for odd parity
func parity(n: UInt8) -> UInt8 {
    var num = n
    var parityBit: UInt8 = 1
    
    while (num > 0) {
        parityBit = parityBit ^ (num & 1)
        num = num >> 1
    }
    
    return parityBit
}

func emulateOperation(state: inout State8080, io: IO?) {
    let opcode: UInt8 = state.memory[Int(state.pc)]
    
    func getRegisterPair(pair: UInt8) -> UInt16 {
        switch pair {
        case RegisterPair.BC.rawValue: return (UInt16(state.b) << 8) | UInt16(state.c)
        case RegisterPair.DE.rawValue: return (UInt16(state.d) << 8) | UInt16(state.e)
        case RegisterPair.HL.rawValue: return (UInt16(state.h) << 8) | UInt16(state.l)
        case RegisterPair.SP.rawValue: return state.sp
        default:
            print("ERROR ATTEMPTING TO ACCESS REGISTER PAIR")
            return 0
        }
    }

    func setRegisterPair(pair: UInt8, value: UInt16) {
        // Split 16-bit value into two 8-bit values
        let MSB = UInt8((value >> 8) & 0xff)
        let LSB = UInt8(value & 0xff)
        
        switch pair {
        case RegisterPair.BC.rawValue:
            state.b = MSB
            state.c = LSB
        case RegisterPair.DE.rawValue:
            state.d = MSB
            state.e = LSB
        case RegisterPair.HL.rawValue:
            state.h = MSB
            state.l = LSB
        case RegisterPair.SP.rawValue:
            state.sp = value
        default:
            print("ERROR ATTEMPTING TO SET REGISTER PAIR")
        }
    }
    
    func getRegister(register: UInt8) -> UInt8 {
        switch register {
        case Register.B.rawValue: return state.b
        case Register.C.rawValue: return state.c
        case Register.D.rawValue: return state.d
        case Register.E.rawValue: return state.e
        case Register.H.rawValue: return state.h
        case Register.L.rawValue: return state.l
        case Register.M.rawValue:
            let offset = getRegisterPair(pair: RegisterPair.HL.rawValue)
            return state.memory[Int(offset)]
        case Register.A.rawValue: return state.a
        default:
            print("ERROR ATTEMPTING TO ACCESS REGISTER")
            return 0
        }
    }
    
    func setRegister(register: UInt8, value: UInt8) {
        switch register {
        case Register.B.rawValue: state.b = value
        case Register.C.rawValue: state.c = value
        case Register.D.rawValue: state.d = value
        case Register.E.rawValue: state.e = value
        case Register.H.rawValue: state.h = value
        case Register.L.rawValue: state.l = value
        case Register.M.rawValue:
            let offset = getRegisterPair(pair: RegisterPair.HL.rawValue)
            state.memory[Int(offset)] = value
        case Register.A.rawValue: state.a = value
        default:
            print("ERROR ATTEMPTING TO ACCESS REGISTER")
        }
    }
    
    func pushToStack(value: UInt16) {
        // Split 16-bit value into two 8-bit values
        let MSB = UInt8((value >> 8) & 0xff)
        let LSB = UInt8(value & 0xff)
        
        state.memory[Int(state.sp &- 1)] = MSB
        state.memory[Int(state.sp &- 2)] = LSB
        state.sp = state.sp &- 2
    }
    
    func popStack() -> UInt16 {
        let MSB = state.memory[Int(state.sp) &+ 1]
        let LSB = state.memory[Int(state.sp)]
        state.sp = state.sp &+ 2
        
        return (UInt16(MSB) << 8) | UInt16(LSB)
    }
    
    func call() {
        // Push return address (next pc) to stack, then jump to memory address
        pushToStack(value: state.pc &+ 3)
        state.pc = getHiLo()
    }
    
    func ret() {
        let ret = popStack()
        state.pc = ret
    }
    
    func getHiLo() -> UInt16 {
        let high = state.memory[Int(state.pc &+ 2)]
        let low = state.memory[Int(state.pc &+ 1)]
        
        return (UInt16(high) << 8) | UInt16(low)
    }
    
    func getConditionByte() -> UInt8 {
        return (state.cc.s << 7) | (state.cc.z << 6) | (state.cc.p << 2) | (1 << 1) | state.cc.cy
    }
    
    func setConditionByte(byte: UInt8) {
        state.cc.s = (byte >> 7) & 0b1
        state.cc.z = (byte >> 6) & 0b1
        state.cc.p = (byte >> 2) & 0b1
        state.cc.cy = byte & 0b1
    }
    
    func setFlags(result: UInt8) {
        // Set zero flag to 1 if answer is zero; otherwise set to 0
        state.cc.z = ((result & 0xff) == 0) ? 1 : 0
        // Set sign flag to 1 if answer has bit 7 set; otherwise set to 0
        state.cc.s = ((result & 0x80) != 0) ? 1 : 0
        // Set parity flag to 1 if parity of answer is even; otherwise set to 0
        state.cc.p = parity(n: UInt8(result & 0xff))
    }
    
    func add(val1: UInt8, val2: UInt8, setCarry: Bool) {
        let result = UInt16(val1) + UInt16(val2)
        // Set condition codes (aka flags) based on properties of the result
        setFlags(result: UInt8(result & 0xff))
        
        if (setCarry) {
            // Set carry flag to 1 if answer is greater than 8 bits
            state.cc.cy = (result > 0xff) ? 1 : 0
            
            // Set auxiliary carry flag to 1 if there was a carry out of bit 3; otherwise set to 0
            let val1Bit4 = (val1 >> 4) & 0b1
            let val2Bit4 = (val2 >> 4) & 0b1
            let sumBit4 = (val1Bit4 + val2Bit4) & 0b1
            let resultBit4 = (result >> 4) & 0b1
            
            state.cc.ac = (sumBit4 == resultBit4) ? 0 : 1
        }
        
        state.a = UInt8(result & 0xff)
    }
    
    func incrementCPU(pc: UInt16, cycles: Int) {
        state.pc = state.pc &+ pc
        state.cycle = state.cycle &+ cycles
    }

    switch opcode {

    // NOP
    case 0x00, 0x08, 0x10, 0x18, 0x20, 0x28, 0x38, 0xcb, 0xdd, 0xd9, 0xed, 0xfd:
        incrementCPU(pc: 1, cycles: 4)

    // LXI
    case 0x01, 0x11, 0x21, 0x31:
        let pair = (opcode >> 4) & 0b11
        let data = getHiLo()
        setRegisterPair(pair: pair, value: data)
        
        incrementCPU(pc: 3, cycles: 10)

    // STAX
    case 0x02, 0x12:
        let pair = (opcode >> 4) & 0b1
        let offset = getRegisterPair(pair: pair)
        state.memory[Int(offset)] = state.a
        
        incrementCPU(pc: 1, cycles: 7)
        
    // INX
    case 0x03, 0x13, 0x23, 0x33:
        let pair = (opcode >> 4) & 0b11
        setRegisterPair(pair: pair, value: getRegisterPair(pair: pair) &+ 1)
        
        incrementCPU(pc: 1, cycles: 5)
        
    // INR
    case 0x04, 0x0c, 0x14, 0x1c, 0x24, 0x2c, 0x34, 0x3c:
        let reg = (opcode >> 3) & 0b111
        let result = getRegister(register: reg) &+ 1
        setFlags(result: result)
        setRegister(register: reg, value: result)
        
        incrementCPU(pc: 1, cycles: opcode == 0x34 ? 10 : 5)
    
    // DCR
    case 0x05, 0x0d, 0x15, 0x1d, 0x25, 0x2d, 0x35, 0x3d:
        let reg = (opcode >> 3) & 0b111
        let result = getRegister(register: reg) &- 1
        setFlags(result: result)
        setRegister(register: reg, value: result)
        
        incrementCPU(pc: 1, cycles: opcode == 0x35 ? 10 : 5)
        
    // MVI
    case 0x06, 0x0e, 0x16, 0x1e, 0x26, 0x2e, 0x36, 0x3e:
        let reg = (opcode >> 3) & 0b111
        let data = state.memory[Int(state.pc + 1)]
        setRegister(register: reg, value: data)
        
        incrementCPU(pc: 2, cycles: opcode == 0x36 ? 10 : 7)

    // RLC
    case 0x07:
        // Set carry to high order bit, then rotate accumulator one bit position to the left
        let high = (state.a >> 7) & 0b1
        state.cc.cy = high
        state.a = ((state.a << 1) | high) & 0xff
        
        incrementCPU(pc: 1, cycles: 4)

    // DAD
    case 0x09, 0x19, 0x29, 0x39:
        let pair = (opcode >> 4) & 0b11
        let num1 = getRegisterPair(pair: pair)
        let num2 = getRegisterPair(pair: RegisterPair.HL.rawValue)
        let sum = Int32(num1) + Int32(num2)
        
        state.cc.cy = (sum > 0xffff) ? 1 : 0
        
        setRegisterPair(pair: RegisterPair.HL.rawValue, value: UInt16(sum & 0xffff))
        
        incrementCPU(pc: 1, cycles: 10)

    // LDAX
    case 0x0a, 0x1a:
        let pair = (opcode >> 4) & 0b1
        let offset = getRegisterPair(pair: pair)
        state.a = state.memory[Int(offset)]
        
        incrementCPU(pc: 1, cycles: 7)

    // DCX
    case 0x0b, 0x1b, 0x2b, 0x3b:
        let pair = (opcode >> 4) & 0b11
        setRegisterPair(pair: pair, value: getRegisterPair(pair: pair) &- 1)
        
        incrementCPU(pc: 1, cycles: 5)

    // RRC
    case 0x0f:
        // Set carry to low order bit of accumulator, then rotate accumulator one bit position to the right
        let low = state.a & 0b1
        state.cc.cy = low
        state.a = ((low << 7) | (state.a >> 1)) & 0xff
        
        incrementCPU(pc: 1, cycles: 4)

    // RAL
    case 0x17:
        // Swap carry with high order bit, then rotate accumulator one bit position to the left
        let high = (state.a >> 7) & 0b1
        state.a = ((state.a << 1) | state.cc.cy) & 0xff
        state.cc.cy = high
        
        incrementCPU(pc: 1, cycles: 4)

    // RAR
    case 0x1f:
        // Swap carry with low order bit, then rotate accumulator one bit position to the right
        let low = state.a & 0b1
        state.a = ((state.cc.cy << 7) | (state.a >> 1)) & 0xff
        state.cc.cy = low
        
        incrementCPU(pc: 1, cycles: 4)

    // SHLD adr
    case 0x22:
        let data = getHiLo()
        let l = getRegister(register: Register.L.rawValue)
        let h = getRegister(register: Register.H.rawValue)
        state.memory[Int(data)] = l
        state.memory[Int(data) + 1] = h
        
        incrementCPU(pc: 3, cycles: 16)

    // DAA
    case 0x27:
        var LSB = state.a & 0xf
        if (LSB > 9 || state.cc.ac == 1) {
            state.a = state.a &+ 6
            LSB = state.a & 0xff
            state.cc.ac = LSB < 6 ? 1 : 0
        }
        
        var MSB = (state.a >> 4) & 0xf
        if (MSB > 9 || state.cc.cy == 1) {
            MSB = MSB &+ 6
            state.a = (MSB << 4) | LSB
            if (MSB < 6) { state.cc.cy = 1 }
        }
        
        incrementCPU(pc: 1, cycles: 4)

    // LHLD adr
    case 0x2a:
        let data = getHiLo()
        setRegister(register: Register.L.rawValue, value: state.memory[Int(data)])
        setRegister(register: Register.H.rawValue, value: state.memory[Int(data) + 1])
        
        incrementCPU(pc: 3, cycles: 16)

    // CMA
    case 0x2f:
        state.a = ~state.a
        
        incrementCPU(pc: 1, cycles: 4)

    // SIM
    case 0x30:
        print("SIM - NOT USED")
        incrementCPU(pc: 1, cycles: 0)

    // STA adr
    case 0x32:
        let data = getHiLo()
        state.memory[Int(data)] = state.a
        
        incrementCPU(pc: 3, cycles: 13)
        
    // STC
    case 0x37:
        state.cc.cy = 1
        
        incrementCPU(pc: 1, cycles: 4)

    // LDA adr
    case 0x3a:
        let data = getHiLo()
        state.a = state.memory[Int(data)]
        incrementCPU(pc: 3, cycles: 0)

    // CMC
    case 0x3f:
        // If the carry bit is zero, set it to 1. Otherwise, set to zero.
        state.cc.cy = state.cc.cy ^ 1
        
        incrementCPU(pc: 1, cycles: 4)

    // MOV
    case 0x40..<0x76,
         0x77..<0x80:
        let src = opcode & 0b111
        let dst = (opcode >> 3) & 0b111
        setRegister(register: dst, value: getRegister(register: src))
        
        incrementCPU(pc: 1, cycles: (src == 6 || dst == 6) ? 7 : 5)

    // HLT
    case 0x76:
        print("HALT")

    // ADD
    case 0x80..<0x88:
        let reg = opcode & 0b111
        add(val1: state.a, val2: getRegister(register: reg), setCarry: true)
        
        incrementCPU(pc: 1, cycles: reg == 6 ? 7 : 4)

    // ADC
    case 0x88..<0x90:
        let reg = opcode & 0b111
        add(val1: state.a, val2: getRegister(register: reg) &+ state.cc.cy, setCarry: true)
        
        incrementCPU(pc: 1, cycles: reg == 6 ? 7 : 4)

    // SUB
    case 0x90..<0x98:
        let reg = opcode & 0b111
        let complement = ~getRegister(register: reg) &+ 1
        add(val1: state.a, val2: complement, setCarry: true)
        
        incrementCPU(pc: 1, cycles: reg == 6 ? 7 : 4)

    // SBB
    case 0x98..<0xa0:
        // Add the carry to the addend before subtracting it from the accumulator
        let reg = opcode & 0b111
        let complement = ~(getRegister(register: reg) &+ state.cc.cy) &+ 1
        add(val1: state.a, val2: complement, setCarry: true)
        
        incrementCPU(pc: 1, cycles: reg == 6 ? 7 : 4)

    // ANA
    case 0xa0..<0xa8:
        let reg = opcode & 0b111
        let result = state.a & getRegister(register: reg)
        
        setFlags(result: result)
        state.cc.cy = 0
        state.a = result
        
        incrementCPU(pc: 1, cycles: reg == 6 ? 7 : 4)

    // XRA
    case 0xa8..<0xb0:
        let reg = opcode & 0b111
        let result = state.a ^ getRegister(register: reg)
        
        setFlags(result: result)
        state.cc.cy = 0
        state.a = result
        
        incrementCPU(pc: 1, cycles: reg == 6 ? 7 : 4)

    // ORA
    case 0xb0..<0xb8:
        let reg = opcode & 0b111
        let result = state.a | getRegister(register: reg)
        
        setFlags(result: result)
        state.cc.cy = 0
        state.a = result
        
        incrementCPU(pc: 1, cycles: reg == 6 ? 7 : 4)

    // CMP
    case 0xb8..<0xc0:
        let reg = opcode & 0b111
        let result = UInt16(state.a) &- UInt16(getRegister(register: reg))
        setFlags(result: UInt8(result & 0xff))
        // Set carry flag to 1 if answer is greater than 8 bits
        state.cc.cy = (result > 0xff) ? 1 : 0
        
        incrementCPU(pc: 1, cycles: reg == 6 ? 7 : 4)

    // RNZ, RZ, RNC, RC, RPO, RPE, RP, RM
    case 0xc0, 0xc8, 0xd0, 0xd8, 0xe0, 0xe8, 0xf0, 0xf8:
        let flags = [state.cc.z, state.cc.cy, state.cc.p, state.cc.s]
        let flag = flags[Int((opcode >> 4) & 0b11)]
        let direction = (opcode >> 3) & 0b1
        
        if (flag == direction) {
            ret()
            incrementCPU(pc: 0, cycles: 11)
        } else {
            incrementCPU(pc: 1, cycles: 5)
        }
        
    // POP
    case 0xc1, 0xd1, 0xe1:
        let pair = (opcode >> 4) & 0b11
        setRegisterPair(pair: pair, value: popStack())
        
        incrementCPU(pc: 1, cycles: 11)

    // POP PSW
    case 0xf1:
        let data = popStack()
        setRegister(register: Register.A.rawValue, value: UInt8((data >> 8) & 0xff))
        setConditionByte(byte: UInt8(data & 0xff))
        
        incrementCPU(pc: 1, cycles: 11)

    // JNZ, JZ, JNC, JC, JPO, JPE, JP, JM
    case 0xc2, 0xca, 0xd2, 0xda, 0xe2, 0xea, 0xf2, 0xfa:
        let flags = [state.cc.z, state.cc.cy, state.cc.p, state.cc.s]
        let flag = flags[Int((opcode >> 4) & 0b11)]
        let direction = (opcode >> 3) & 0b1
        
        if (flag == direction) {
            state.pc = getHiLo()
        } else {
            incrementCPU(pc: 3, cycles: 0)
        }
        
        incrementCPU(pc: 0, cycles: 10)

    // JMP adr
    case 0xc3:
        state.pc = getHiLo()
        
        incrementCPU(pc: 0, cycles: 10)

    // CNZ, CZ, CNC, CC, CPO, CPE, CP, CM
    case 0xc4, 0xcc, 0xd4, 0xdc, 0xe4, 0xec, 0xf4, 0xfc:
        let flags = [state.cc.z, state.cc.cy, state.cc.p, state.cc.s]
        let flag = flags[Int((opcode >> 4) & 0b11)]
        let direction = (opcode >> 3) & 0b1
        
        if (flag == direction) {
            call()
            incrementCPU(pc: 0, cycles: 17)
        } else {
            incrementCPU(pc: 3, cycles: 11)
        }

    // PUSH
    case 0xc5, 0xd5, 0xe5:
        let pair = (opcode >> 4) & 0b11
        pushToStack(value: getRegisterPair(pair: pair))
        
        incrementCPU(pc: 1, cycles: 11)
        
    // PUSH PSW
    case 0xf5:
        let data = (UInt16(state.a) << 8) | UInt16(getConditionByte())
        pushToStack(value: data)
        
        incrementCPU(pc: 1, cycles: 11)

    // ADI D8
    case 0xc6:
        // Immediate form; add the byte that comes after the instruction
        let data = state.memory[Int(state.pc + 1)]
        add(val1: state.a, val2: data, setCarry: true)
        
        incrementCPU(pc: 2, cycles: 7)
        
    // RST
    case 0xc7, 0xcf, 0xd7, 0xdf, 0xe7, 0xef, 0xf7, 0xff:
        pushToStack(value: state.pc)
        let exp = UInt16(opcode & 0b000111)
        state.pc = exp
        
        incrementCPU(pc: 0, cycles: 11)

    // RET
    case 0xc9:
        ret()
        incrementCPU(pc: 0, cycles: 10)

    // CALL adr
    case 0xcd:
        call()
        incrementCPU(pc: 0, cycles: 17)

    // ACI D8
    case 0xce:
        // Immediate form (with carry); add the byte that comes after the instruction
        let data = state.memory[Int(state.pc + 1)]
        add(val1: state.a, val2: data &+ state.cc.cy, setCarry: true)
        
        incrementCPU(pc: 2, cycles: 7)
        
    // IN D8
    case 0xdb:
        if (io != nil) {
            state.a = io!.input(state.memory[Int(state.pc &+ 1)])
        }

        incrementCPU(pc: 2, cycles: 0)
    
    // OUT D8
    case 0xd3:
        if (io != nil) {
            io!.output(state.memory[Int(state.pc &+ 1)], state.a)
        }
        
        incrementCPU(pc: 2, cycles: 0)

    // SUI D8
    case 0xd6:
        // Immediate form; subtract the byte that comes after the instruction
        let data = state.memory[Int(state.pc + 1)]
        let complement = ~data &+ 1
        add(val1: state.a, val2: complement, setCarry: true)
        
        incrementCPU(pc: 2, cycles: 7)

    // SBI D8
    case 0xde:
        // Immediate form (with carry); subtract the byte that comes after the instruction
        let data = state.memory[Int(state.pc + 1)]
        let complement = ~(data &+ state.cc.cy) &+ 1
        add(val1: state.a, val2: complement, setCarry: true)
        
        incrementCPU(pc: 2, cycles: 7)

    // XTHL
    case 0xe3:
        let l = getRegister(register: Register.L.rawValue)
        let h = getRegister(register: Register.H.rawValue)
        let sp = getRegisterPair(pair: RegisterPair.SP.rawValue)
        
        setRegister(register: Register.L.rawValue, value: state.memory[Int(sp)])
        setRegister(register: Register.H.rawValue, value: state.memory[Int(sp) + 1])
        state.memory[Int(sp)] = l
        state.memory[Int(sp) + 1] = h
        
        incrementCPU(pc: 1, cycles: 18)

    // ANI D8
    case 0xe6:
        let data = state.memory[Int(state.pc + 1)]
        let result = getRegister(register: Register.A.rawValue) & data
        
        setFlags(result: result)
        state.cc.cy = 0
        state.a = result
        
        incrementCPU(pc: 2, cycles: 7)

    // PCHL
    case 0xe9:
        state.pc = getRegisterPair(pair: RegisterPair.HL.rawValue)
        
        incrementCPU(pc: 0, cycles: 5)

    // XCHG
    case 0xeb:
        let de = getRegisterPair(pair: RegisterPair.DE.rawValue)
        let hl = getRegisterPair(pair: RegisterPair.HL.rawValue)
        setRegisterPair(pair: RegisterPair.DE.rawValue, value: hl)
        setRegisterPair(pair: RegisterPair.HL.rawValue, value: de)
        
        incrementCPU(pc: 1, cycles: 4)

    // XRI D8
    case 0xee:
        let data = state.memory[Int(state.pc + 1)]
        let result = getRegister(register: Register.A.rawValue) ^ data
        
        setFlags(result: result)
        state.cc.cy = 0
        state.a = result
        
        incrementCPU(pc: 2, cycles: 7)

    // DI
    case 0xf3:
        state.intEnable = 0
        
        incrementCPU(pc: 1, cycles: 4)

    // ORI D8
    case 0xf6:
        let data = state.memory[Int(state.pc + 1)]
        let result = getRegister(register: Register.A.rawValue) | data
        
        setFlags(result: result)
        state.cc.cy = 0
        state.a = result
        
        incrementCPU(pc: 2, cycles: 7)

    // SPHL
    case 0xf9:
        setRegisterPair(pair: RegisterPair.SP.rawValue, value: getRegisterPair(pair: RegisterPair.HL.rawValue))
        
        incrementCPU(pc: 1, cycles: 5)

    // EI
    case 0xfb:
        state.intEnable = 1
        
        incrementCPU(pc: 1, cycles: 4)

    // CPI D8
    case 0xfe:
        let data = state.memory[Int(state.pc + 1)]
        let result = UInt16(state.a) &- UInt16(data)
        setFlags(result: UInt8(result & 0xff))
        // Set carry flag to 1 if answer is greater than 8 bits
        state.cc.cy = (result > 0xff) ? 1 : 0
        
        incrementCPU(pc: 2, cycles: 7)

    default:
        print("ERROR ATTEMPTING TO PARSE OPCODE")
    }

    func toHex(n: UInt16) -> String {
        return String(format:"%04x", n)
    }

//    if (state.debug && state.pc != 0x0ada && state.pc != 0x0ade && state.pc != 0x0add) {
//        print(
//            state.hit, " - ",
//            "cycle:", state.cycle,
//            "opcode:", toHex(n: UInt16(opcode)), "  ",
//            "bc:", toHex(n: getRegisterPair(pair: RegisterPair.BC.rawValue)), "  ",
//            "de:", toHex(n: getRegisterPair(pair: RegisterPair.DE.rawValue)), "  ",
//            "hl:", toHex(n: getRegisterPair(pair: RegisterPair.HL.rawValue)), "  ",
//            "pc:", toHex(n: state.pc), "  ",
//            "sp:", toHex(n: getRegisterPair(pair: RegisterPair.SP.rawValue)), "  ",
//            "z:", state.cc.z,
//            "cy:", state.cc.cy,
//            "p:", state.cc.p,
//            "s:", state.cc.s
//        )
//    }
}
