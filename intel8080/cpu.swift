import Foundation

let filePath = Bundle.main.path(forResource: "invaders", ofType: "rom")

let data = NSData(contentsOfFile: filePath!)!
let dataBuffer = [UInt8](data)

struct ConditionCodes {
    var z: UInt8 = 1
    var s: UInt8 = 1
    var p: UInt8 = 1
    var cy: UInt8 = 1
    var ac: UInt8 = 1
    var pad: UInt8 = 3
}

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
    var memory: Array<UInt8> = [0]
    var cc: ConditionCodes = ConditionCodes()
    var int_enable: UInt8 = 0
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

func parity(n: UInt8) -> UInt8 {
    var num = n
    var parityBit: UInt8 = 0
    
    while (num > 0) {
        parityBit = parityBit ^ (num & 1)
        num = num >> 1
    }
    
    return parityBit
}

func emulateOperation(state: inout State8080) -> State8080 {
    let opcode: UInt8 = state.memory[Int(state.pc)]
    var opbytes: UInt16 = 1
    
    func getRegisterPair(pair: UInt8) -> UInt16 {
        switch pair {
        case RegisterPair.BC.rawValue: return UInt16((state.b << 8) | state.c)
        case RegisterPair.DE.rawValue: return UInt16((state.d << 8) | state.e)
        case RegisterPair.HL.rawValue: return UInt16((state.h << 8) | state.l)
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
        
        state.memory[Int(state.sp) - 1] = MSB
        state.memory[Int(state.sp) - 2] = LSB
        state.sp = state.sp - 2
    }
    
    func popStack() -> UInt16 {
        let MSB = state.memory[Int(state.sp) + 2]
        let LSB = state.memory[Int(state.sp) + 1]
        state.sp = state.sp + 2
        
        return UInt16((MSB << 8) | LSB)
    }
    
    func call() {
        // Push return address (next pc) to stack, then jump to memory address
        pushToStack(value: state.pc + 2)
        state.pc = getHiLo()
    }
    
    func ret() {
        let ret = popStack()
        state.pc = ret
    }
    
    func getHiLo() -> UInt16 {
        return UInt16((state.memory[Int(state.pc + 2)] << 8) | state.memory[Int(state.pc + 1)])
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
        // Set parity flag to 1 if parity of answer is odd; otherwise set to 0
        state.cc.p = parity(n: UInt8(result & 0xff))
    }
    
    func add(val1: UInt8, val2: UInt8, setCarry: Bool) {
        // Perform addition using 16 bits; makes it easier to see 8-bit overflow
        let result = UInt16(val1) + UInt16(val2)
        // Set condition codes (aka flags) based on properties of the result
        setFlags(result: UInt8(result & 0xff))
        
        if (setCarry) {
            // Set carry flag to 1 if answer is greater than 8 bits
            state.cc.cy = (result > 0xff) ? 1 : 0
        }
        
        state.a = UInt8(result & 0xff)
    }

    switch opcode {

    // NOP
    case 0x00, 0x08, 0x10, 0x18, 0x28, 0x38, 0xcb, 0xdd, 0xd9, 0xed, 0xfd:
        print("NOP")

    // LXI
    case 0x01, 0x11, 0x21, 0x31:
        let pair = opcode & 0b110001
        let data = UInt16((state.memory[Int(state.pc + 2)] << 8) | state.memory[Int(state.pc + 1)])
        setRegisterPair(pair: pair, value: data)
        opbytes = 3

    // STAX
    case 0x02, 0x12:
        let pair = (opcode >> 4) & 0b1
        let offset = getRegisterPair(pair: pair)
        state.memory[Int(offset)] = state.a
        
    // INX
    case 0x03, 0x13, 0x23, 0x33:
        let pair = (opcode >> 4) & 0b11
        setRegisterPair(pair: pair, value: getRegisterPair(pair: pair) + 1)
        
    // INR
    case 0x04, 0x0c, 0x14, 0x1c, 0x24, 0x2c, 0x34, 0x3c:
        let reg = opcode & 0b111
        let result = getRegister(register: reg) + 1
        setFlags(result: result)
        setRegister(register: reg, value: result)
    
    // DCR
    case 0x05, 0x0d, 0x15, 0x1d, 0x25, 0x2d, 0x35, 0x3d:
        let reg = opcode & 0b111
        let result = getRegister(register: reg) - 1
        setFlags(result: result)
        setRegister(register: reg, value: result)
        
    // MVI
    case 0x06, 0x0e, 0x16, 0x1e, 0x26, 0x2e, 0x36, 0x3e:
        let reg = (opcode >> 3) & 0b111
        let data = state.memory[Int(state.pc + 1)]
        setRegister(register: reg, value: data)
        opbytes = 2

    // RLC
    case 0x07:
        // Set carry to high order bit, then rotate accumulator one bit position to the left
        let high = (opcode >> 7) & 0b1
        state.cc.cy = high
        state.a = ((state.a << 1) | high) & 0xff

    // DAD
    case 0x09, 0x19, 0x29, 0x39:
        let pair = (opcode >> 4) & 0b11
        let num1 = getRegisterPair(pair: pair)
        let num2 = getRegisterPair(pair: RegisterPair.HL.rawValue)
        let sum = Int32(num1) + Int32(num2)
        
        state.cc.cy = (sum > 0xffff) ? 1 : 0
        
        setRegisterPair(pair: RegisterPair.HL.rawValue, value: UInt16(sum & 0xffff))

    // LDAX
    case 0x0a, 0x1a:
        let pair = (opcode >> 4) & 0b1
        let offset = getRegisterPair(pair: pair)
        state.a = state.memory[Int(offset)]

    // DCX
    case 0x0b, 0x1b, 0x2b, 0x3b:
        let pair = (opcode >> 4) & 0b11
        setRegisterPair(pair: pair, value: getRegisterPair(pair: pair) - 1)

    // RRC
    case 0x0f:
        // Set carry to low order bit, then rotate accumulator one bit position to the right
        let low = opcode & 0b1
        state.cc.cy = low
        state.a = ((low << 7) | (state.a >> 1)) & 0xff

    // RAL
    case 0x17:
        // Swap carry with high order bit, then rotate accumulator one bit position to the left
        let high = (opcode >> 7) & 0b1
        state.a = ((state.a << 1) | state.cc.cy) & 0xff
        state.cc.cy = high

    // RAR
    case 0x1f:
        // Swap carry with low order bit, then rotate accumulator one bit position to the right
        let low = opcode & 0b1
        state.a = ((state.cc.cy << 1) | (state.a >> 1)) & 0xff
        state.cc.cy = low

    // RIM
    case 0x20:
        print("RIM - NOT USED")

    // SHLD adr
    case 0x22:
        let data = getHiLo()
        let l = getRegister(register: Register.L.rawValue)
        let h = getRegister(register: Register.H.rawValue)
        state.memory[Int(data)] = l
        state.memory[Int(data) + 1] = h
        opbytes = 3

    // DAA
    case 0x27:
        print("DAA - NOT USED")

    // LHLD adr
    case 0x2a:
        let data = getHiLo()
        setRegister(register: Register.L.rawValue, value: state.memory[Int(data)])
        setRegister(register: Register.H.rawValue, value: state.memory[Int(data) + 1])
        opbytes = 3

    // CMA
    case 0x2f:
        state.a = ~state.a

    // SIM
    case 0x30:
        print("SIM - NOT USED")

    // STA adr
    case 0x32:
        let data = getHiLo()
        state.memory[Int(data)] = state.a
        opbytes = 3
        
    // STC
    case 0x37:
        state.cc.cy = 1

    // LDA adr
    case 0x3a:
        let data = getHiLo()
        state.a = state.memory[Int(data)]
        opbytes = 3

    // CMC
    case 0x3f:
        // If the carry bit is zero, set it to 1. Otherwise, set to zero.
        state.cc.cy = state.cc.cy ^ 1

    // MOV
    case 0x40..<0x76,
         0x77..<0x80:
        let src = opcode & 0b111
        let dst = (opcode >> 3) & 0b111
        setRegister(register: dst, value: getRegister(register: src))

    // HLT
    case 0x76:
        print("HALT")

    // ADD
    case 0x80..<0x88:
        let reg = opcode & 0b111
        add(val1: state.a, val2: getRegister(register: reg), setCarry: true)

    // ADC
    case 0x88..<0x90:
        let reg = opcode & 0b111
        add(val1: state.a, val2: getRegister(register: reg) + state.cc.cy, setCarry: true)

    // SUB
    case 0x90..<0x98:
        let reg = opcode & 0b111
        let complement = ~getRegister(register: reg) + 1
        add(val1: state.a, val2: complement, setCarry: true)

    // SBB
    case 0x98..<0xa0:
        // Add the carry to the addend before subtracting it from the accumulator
        let reg = opcode & 0b111
        let complement = ~(getRegister(register: reg) + state.cc.cy) + 1
        add(val1: state.a, val2: complement, setCarry: true)

    // ANA
    case 0xa0..<0xa8:
        let reg = opcode & 0b111
        let result = state.a & getRegister(register: reg)
        
        setFlags(result: result)
        state.cc.cy = 0
        state.a = result

    // XRA
    case 0xa8..<0xb0:
        let reg = opcode & 0b111
        let result = state.a ^ getRegister(register: reg)
        
        setFlags(result: result)
        state.cc.cy = 0
        state.a = result

    // ORA
    case 0xb0..<0xb8:
        let reg = opcode & 0b111
        let result = state.a | getRegister(register: reg)
        
        setFlags(result: result)
        state.cc.cy = 0
        state.a = result

    // CMP
    case 0xb8..<0xc0:
        let reg = opcode & 0b111
        let result = UInt16(state.a) - UInt16(getRegister(register: reg))
        setFlags(result: UInt8(result & 0xff))
        // Set carry flag to 1 if answer is greater than 8 bits
        state.cc.cy = (result > 0xff) ? 1 : 0

    // RNZ
    case 0xc0:
        if (state.cc.z == 0) {
            ret()
        }
        
    // POP B
    case 0xc1, 0xd1, 0xe1:
        let pair = (opcode >> 4) & 0b11
        setRegisterPair(pair: pair, value: popStack())

    // POP PSW
    case 0xf1:
        let data = popStack()
        setRegister(register: Register.A.rawValue, value: UInt8((data >> 8) & 0xff))
        setConditionByte(byte: UInt8(data & 0xff))

    // JNZ adr
    case 0xc2:
        if (state.cc.z == 0) {
            state.pc = getHiLo()
        }
        opbytes = 3

    // JMP adr
    case 0xc3:
        state.pc = getHiLo()
        opbytes = 3

    // CNZ adr
    case 0xc4:
        if (state.cc.z == 0) {
            call()
        }
        opbytes = 3

    // PUSH B
    case 0xc5, 0xd5, 0xe5:
        let pair = (opcode >> 4) & 0b11
        pushToStack(value: getRegisterPair(pair: pair))
        
    // PUSH PSW
    case 0xf5:
        let data = UInt16((state.a << 8) | getConditionByte())
        pushToStack(value: data)

    // ADI D8
    case 0xc6:
        // Immediate form; add the byte that comes after the instruction
        let data = state.memory[Int(state.pc + 1)]
        add(val1: state.a, val2: data, setCarry: true)
        opbytes = 2
        
    // RST
    case 0xc7, 0xcf, 0xd7, 0xdf, 0xe7, 0xef, 0xf7, 0xff:
        pushToStack(value: state.pc + 2)
        let exp = UInt16(opcode & 0b000111)
        state.pc = exp

    // RZ
    case 0xc8:
        if (state.cc.z == 1) {
            ret()
        }

    // RET
    case 0xc9:
        ret()

    // JZ adr
    case 0xca:
        if (state.cc.z == 1) {
            state.pc = getHiLo()
        }
        opbytes = 3

    // CZ adr
    case 0xcc:
        if (state.cc.z == 1) {
            call()
        }
        opbytes = 3

    // CALL adr
    case 0xcd:
        call()
        opbytes = 3

    // ACI D8
    case 0xce:
        // Immediate form (with carry); add the byte that comes after the instruction
        let data = state.memory[Int(state.pc + 1)]
        add(val1: state.a, val2: data + state.cc.cy, setCarry: true)
        opbytes = 2

    // RNC
    case 0xd0:
        if (state.cc.cy == 0) {
            ret()
        }

    // JNC adr
    case 0xd2:
        if (state.cc.cy == 0) {
            state.pc = getHiLo()
        }
        opbytes = 3

    // OUT D8
    case 0xd3:
        print("OUT D8 - NOT IMPLEMENTED")
        opbytes = 2

    // CNC adr
    case 0xd4:
        if (state.cc.cy == 0) {
            call()
        }
        opbytes = 3

    // SUI D8
    case 0xd6:
        // Immediate form; subtract the byte that comes after the instruction
        let data = state.memory[Int(state.pc + 1)]
        let complement = ~getRegister(register: data) + 1
        add(val1: state.a, val2: complement, setCarry: true)
        
        opbytes = 2

    // RC
    case 0xd8:
        if (state.cc.cy == 1) {
            ret()
        }

    // JC adr
    case 0xda:
        if (state.cc.cy == 1) {
            state.pc = getHiLo()
        }
        opbytes = 3

    // IN D8
    case 0xdb:
        print("IN D8 - NOT IMPLEMENTED")
        opbytes = 2

    // CC adr
    case 0xdc:
        if (state.cc.cy == 1) {
            call()
        }
        opbytes = 3

    // SBI D8
    case 0xde:
        // Immediate form (with carry); subtract the byte that comes after the instruction
        let data = state.memory[Int(state.pc + 1)]
        let complement = ~(getRegister(register: data) + state.cc.cy) + 1
        add(val1: state.a, val2: complement, setCarry: true)
        
        opbytes = 2

    // RPO
    case 0xe0:
        if (state.cc.p == 0) {
            ret()
        }

    // JPO adr
    case 0xe2:
        if (state.cc.p == 0) {
            state.pc = getHiLo()
        }
        opbytes = 3

    // XTHL
    case 0xe3:
        let l = getRegister(register: Register.L.rawValue)
        let h = getRegister(register: Register.H.rawValue)
        let sp = getRegisterPair(pair: RegisterPair.SP.rawValue)
        
        setRegister(register: Register.L.rawValue, value: state.memory[Int(sp)])
        setRegister(register: Register.H.rawValue, value: state.memory[Int(sp) + 1])
        state.memory[Int(sp)] = l
        state.memory[Int(sp) + 1] = h

    // CPO adr
    case 0xe4:
        if (state.cc.p == 0) {
            call()
        }
        opbytes = 3

    // ANI D8
    case 0xe6:
        let data = state.memory[Int(state.pc + 1)]
        let result = getRegister(register: Register.A.rawValue) & data
        
        setFlags(result: result)
        state.cc.cy = 0
        state.a = result
        opbytes = 2

    // RPE
    case 0xe8:
        if (state.cc.p == 1) {
            ret()
        }

    // PCHL
    case 0xe9:
        state.pc = getRegisterPair(pair: RegisterPair.HL.rawValue)

    // JPE adr
    case 0xea:
        if (state.cc.p == 1) {
            state.pc = getHiLo()
        }
        opbytes = 3

    // XCHG
    case 0xeb:
        let de = getRegisterPair(pair: RegisterPair.DE.rawValue)
        let hl = getRegisterPair(pair: RegisterPair.HL.rawValue)
        setRegisterPair(pair: RegisterPair.DE.rawValue, value: hl)
        setRegisterPair(pair: RegisterPair.HL.rawValue, value: de)

    // CPE adr
    case 0xec:
        if (state.cc.p == 1) {
            call()
        }
        opbytes = 3

    // XRI D8
    case 0xee:
        let data = state.memory[Int(state.pc + 1)]
        let result = getRegister(register: Register.A.rawValue) ^ data
        
        setFlags(result: result)
        state.cc.cy = 0
        state.a = result
        opbytes = 2

    // RP
    case 0xf0:
        if (state.cc.s == 0) {
            ret()
        }

    // JP adr
    case 0xf2:
        if (state.cc.s == 0) {
            state.pc = getHiLo()
        }
        opbytes = 3

    // DI
    case 0xf3:
        state.int_enable = 0

    // CP adr
    case 0xf4:
        if (state.cc.s == 0) {
            call()
        }
        opbytes = 3

    // ORI D8
    case 0xf6:
        let data = state.memory[Int(state.pc + 1)]
        let result = getRegister(register: Register.A.rawValue) | data
        
        setFlags(result: result)
        state.cc.cy = 0
        state.a = result
        opbytes = 2

    // RM
    case 0xf8:
        if (state.cc.s == 1) {
            ret()
        }

    // SPHL
    case 0xf9:
        setRegisterPair(pair: RegisterPair.SP.rawValue, value: getRegisterPair(pair: RegisterPair.HL.rawValue))

    // JM adr
    case 0xfa:
        if (state.cc.s == 1) {
            state.pc = getHiLo()
        }
        opbytes = 3

    // EI
    case 0xfb:
        state.int_enable = 1

    // CM adr
    case 0xfc:
        if (state.cc.s == 1) {
            call()
        }
        opbytes = 3

    // CPI D8
    case 0xfe:
        let data = state.memory[Int(state.pc + 1)]
        let result = UInt16(state.a) - UInt16(data)
        setFlags(result: UInt8(result & 0xff))
        // Set carry flag to 1 if answer is greater than 8 bits
        state.cc.cy = (result > 0xff) ? 1 : 0
        
        opbytes = 2

    default:
        print("ERROR ATTEMPTING TO PARSE OPCODE")
    }

    state.pc += opbytes

    return state
}
