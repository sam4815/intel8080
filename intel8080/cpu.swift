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
    var cc = ConditionCodes()
    var int_enable: UInt8 = 0
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

func setAccumulatorFlags(state: inout State8080, result: UInt16) {
    // Set zero flag to 1 if answer is zero; otherwise set to 0
    state.cc.z = ((result & 0xff) == 0) ? 1 : 0
    // Set sign flag to 1 if answer has bit 7 set; otherwise set to 0
    state.cc.s = ((result & 0x80) != 0) ? 1 : 0
    // Set carry flag to 1 if answer is greater than 8 bits
    state.cc.cy = (result > 0xff) ? 1 : 0
    // Set parity flag to 1 if parity of answer is odd; otherwise set to 0
    state.cc.p = parity(n: UInt8(result & 0xff))
}

func setIncrementorFlags(state: inout State8080, result: UInt8) {
    state.cc.z = ((result & 0xff) == 0) ? 1 : 0
    state.cc.s = ((result & 0x80) != 0) ? 1 : 0
    state.cc.p = parity(n: UInt8(result & 0xff))
}

func setLogicFlags(state: inout State8080, result: UInt8) {
    state.cc.z = ((result & 0xff) == 0) ? 1 : 0
    state.cc.s = ((result & 0x80) != 0) ? 1 : 0
    state.cc.p = parity(n: UInt8(result & 0xff))
    // Always set carry flag to 0
    state.cc.cy = (result > 0xff) ? 1 : 0
}

enum RegisterPair {
    case B
    case D
    case H
}

func getRegisterValue(state: State8080, pair: RegisterPair) -> UInt16 {
    switch pair {
    case RegisterPair.B:
        return UInt16((state.b << 8) | state.c)
        
    case RegisterPair.D:
        return UInt16((state.d << 8) | state.e)
        
    case RegisterPair.H:
        return UInt16((state.h << 8) | state.l)
    }
}

func setRegisterValue(state: inout State8080, pair: RegisterPair, value: UInt16) -> State8080 {
    // Split 16-bit value into two 8-bit values
    let MSB = UInt8((value >> 8) & 0xff)
    let LSB = UInt8(value & 0xff)
    
    switch pair {
    case RegisterPair.B:
        state.b = MSB
        state.c = LSB
        
    case RegisterPair.D:
        state.d = MSB
        state.e = LSB
        
    case RegisterPair.H:
        state.h = MSB
        state.l = LSB
    }
    
    return state
}

func emulateOperation(state: inout State8080) -> State8080 {
    let opcode = state.memory[Int(state.pc)]
    var opBytes: UInt16 = 1

    switch opcode {

    // NOP
    case 0x00: ()

    // LXI B,D16
    case 0x01:
        print("LXI B,D16 - NOT IMPLEMENTED")
        opBytes = 3

    // STAX B
    case 0x02:
        let offset = getRegisterValue(state: state, pair: .B)
        state.memory[Int(offset)] = state.a

    // INX B
    case 0x03:
        setRegisterValue(
            state: &state,
            pair: .B,
            value: getRegisterValue(state: state, pair: .B) + 1
        )

    // INR B
    case 0x04:
        state.b = state.b + 1
        setIncrementorFlags(state: &state, result: state.b)

    // DCR B
    case 0x05:
        state.b = state.b - 1
        setIncrementorFlags(state: &state, result: state.b)

    // MVI B, D8
    case 0x06:
        print("MVI B, D8 - NOT IMPLEMENTED")
        opBytes = 2

    // RLC
    case 0x07:
        print("RLC - NOT IMPLEMENTED")

    // NOP
    case 0x08: ()

    // DAD B
    case 0x09:
        print("DAD B - NOT IMPLEMENTED")

    // LDAX B
    case 0x0a:
        let offset = getRegisterValue(state: state, pair: .B)
        state.a = state.memory[Int(offset)]

    // DCX B
    case 0x0b:
        setRegisterValue(
            state: &state,
            pair: .B,
            value: getRegisterValue(state: state, pair: .B) - 1
        )

    // INR C
    case 0x0c:
        state.c = state.c + 1
        setIncrementorFlags(state: &state, result: state.c)

    // DCR C
    case 0x0d:
        state.c = state.c - 1
        setIncrementorFlags(state: &state, result: state.c)

    // MVI C,D8
    case 0x0e:
        print("MVI C,D8 - NOT IMPLEMENTED")
        opBytes = 2

    // RRC
    case 0x0f:
        print("RRC - NOT IMPLEMENTED")

    // NOP
    case 0x10: ()

    // LXI D,D16
    case 0x11:
        print("LXI D,D16 - NOT IMPLEMENTED")
        opBytes = 3

    // STAX D
    case 0x12:
        let offset = getRegisterValue(state: state, pair: .D)
        state.memory[Int(offset)] = state.a

    // INX D
    case 0x13:
        setRegisterValue(
            state: &state,
            pair: .D,
            value: getRegisterValue(state: state, pair: .D) + 1
        )

    // INR D
    case 0x14:
        state.d = state.d + 1
        setIncrementorFlags(state: &state, result: state.d)

    // DCR D
    case 0x15:
        state.d = state.d - 1
        setIncrementorFlags(state: &state, result: state.d)

    // MVI D, D8
    case 0x16:
        print("MVI D, D8 - NOT IMPLEMENTED")
        opBytes = 2

    // RAL
    case 0x17:
        print("RAL - NOT IMPLEMENTED")

    // NOP
    case 0x18: ()

    // DAD D
    case 0x19:
        print("DAD D - NOT IMPLEMENTED")

    // LDAX D
    case 0x1a:
        let offset = getRegisterValue(state: state, pair: .D)
        state.a = state.memory[Int(offset)]

    // DCX D
    case 0x1b:
        setRegisterValue(
            state: &state,
            pair: .D,
            value: getRegisterValue(state: state, pair: .D) - 1
        )

    // INR E
    case 0x1c:
        state.e = state.e + 1
        setIncrementorFlags(state: &state, result: state.e)

    // DCR E
    case 0x1d:
        state.e = state.e - 1
        setIncrementorFlags(state: &state, result: state.e)

    // MVI E,D8
    case 0x1e:
        print("MVI E,D8 - NOT IMPLEMENTED")
        opBytes = 2

    // RAR
    case 0x1f:
        print("RAR - NOT IMPLEMENTED")

    // RIM
    case 0x20:
        print("RIM - NOT IMPLEMENTED")

    // LXI H,D16
    case 0x21:
        print("LXI H,D16 - NOT IMPLEMENTED")
        opBytes = 3

    // SHLD adr
    case 0x22:
        print("SHLD adr - NOT IMPLEMENTED")
        opBytes = 3

    // INX H
    case 0x23:
        setRegisterValue(
            state: &state,
            pair: .H,
            value: getRegisterValue(state: state, pair: .H) + 1
        )

    // INR H
    case 0x24:
        state.h = state.h + 1
        setIncrementorFlags(state: &state, result: state.h)

    // DCR H
    case 0x25:
        state.h = state.h - 1
        setIncrementorFlags(state: &state, result: state.h)

    // MVI H,D8
    case 0x26:
        print("MVI H,D8 - NOT IMPLEMENTED")
        opBytes = 2

    // DAA
    case 0x27:
        print("DAA - NOT IMPLEMENTED")

    // NOP
    case 0x28: ()

    // DAD H
    case 0x29:
        print("DAD H - NOT IMPLEMENTED")

    // LHLD adr
    case 0x2a:
        print("LHLD adr - NOT IMPLEMENTED")
        opBytes = 3

    // DCX H
    case 0x2b:
        setRegisterValue(
            state: &state,
            pair: .H,
            value: getRegisterValue(state: state, pair: .H) - 1
        )

    // INR L
    case 0x2c:
        state.l = state.l + 1
        setIncrementorFlags(state: &state, result: state.l)

    // DCR L
    case 0x2d:
        state.l = state.l - 1
        setIncrementorFlags(state: &state, result: state.l)

    // MVI L, D8
    case 0x2e:
        print("MVI L, D8 - NOT IMPLEMENTED")
        opBytes = 2

    // CMA
    case 0x2f:
        print("CMA - NOT IMPLEMENTED")

    // SIM
    case 0x30:
        print("SIM - NOT IMPLEMENTED")

    // LXI SP, D16
    case 0x31:
        print("LXI SP, D16 - NOT IMPLEMENTED")
        opBytes = 3

    // STA adr
    case 0x32:
        print("STA adr - NOT IMPLEMENTED")
        opBytes = 3

    // INX SP
    case 0x33:
        state.sp = (state.sp + 1) & 0xffff

    // INR M
    case 0x34:
        let offset = getRegisterValue(state: state, pair: .H)
        state.memory[Int(offset)] = state.memory[Int(offset)] + 1
        setIncrementorFlags(state: &state, result: state.memory[Int(offset)])

    // DCR M
    case 0x35:
        let offset = getRegisterValue(state: state, pair: .H)
        state.memory[Int(offset)] = state.memory[Int(offset)] - 1
        setIncrementorFlags(state: &state, result: state.memory[Int(offset)])

    // MVI M,D8
    case 0x36:
        print("MVI M,D8 - NOT IMPLEMENTED")
        opBytes = 2

    // STC
    case 0x37:
        print("STC - NOT IMPLEMENTED")

    // NOP
    case 0x38: ()

    // DAD SP
    case 0x39:
        print("DAD SP - NOT IMPLEMENTED")

    // LDA adr
    case 0x3a:
        print("LDA adr - NOT IMPLEMENTED")
        opBytes = 3

    // DCX SP
    case 0x3b:
        state.sp = (state.sp - 1) & 0xffff

    // INR A
    case 0x3c:
        state.a = state.a + 1
        setIncrementorFlags(state: &state, result: state.a)

    // DCR A
    case 0x3d:
        state.a = state.a - 1
        setIncrementorFlags(state: &state, result: state.a)

    // MVI A,D8
    case 0x3e:
        print("MVI A,D8 - NOT IMPLEMENTED")
        opBytes = 2

    // CMC
    case 0x3f:
        print("CMC - NOT IMPLEMENTED")

    // MOV B,B (NOP)
    case 0x40: ()

    // MOV B,C
    case 0x41:
        state.b = state.c

    // MOV B,D
    case 0x42:
        state.b = state.d

    // MOV B,E
    case 0x43:
        state.b = state.e

    // MOV B,H
    case 0x44:
        state.b = state.h

    // MOV B,L
    case 0x45:
        state.b = state.l

    // MOV B,M
    case 0x46:
        let offset = getRegisterValue(state: state, pair: .H)
        state.b = state.memory[Int(offset)]

    // MOV B,A
    case 0x47:
        state.b = state.a

    // MOV C,B
    case 0x48:
        state.c = state.b

    // MOV C,C (NOP)
    case 0x49: ()

    // MOV C,D
    case 0x4a:
        state.c = state.d

    // MOV C,E
    case 0x4b:
        state.c = state.e

    // MOV C,H
    case 0x4c:
        state.c = state.h

    // MOV C,L
    case 0x4d:
        state.c = state.l

    // MOV C,M
    case 0x4e:
        let offset = getRegisterValue(state: state, pair: .H)
        state.c = state.memory[Int(offset)]

    // MOV C,A
    case 0x4f:
        state.c = state.a

    // MOV D,B
    case 0x50:
        state.d = state.b

    // MOV D,C
    case 0x51:
        state.d = state.c

    // MOV D,D (NOP)
    case 0x52: ()

    // MOV D,E
    case 0x53:
        state.d = state.e

    // MOV D,H
    case 0x54:
        state.d = state.h

    // MOV D,L
    case 0x55:
        state.d = state.l

    // MOV D,M
    case 0x56:
        let offset = getRegisterValue(state: state, pair: .H)
        state.d = state.memory[Int(offset)]

    // MOV D,A
    case 0x57:
        state.d = state.a

    // MOV E,B
    case 0x58:
        state.e = state.b

    // MOV E,C
    case 0x59:
        state.e = state.c

    // MOV E,D
    case 0x5a:
        state.e = state.d

    // MOV E,E (NOP)
    case 0x5b: ()

    // MOV E,H
    case 0x5c:
        state.e = state.h

    // MOV E,L
    case 0x5d:
        state.e = state.l

    // MOV E,M
    case 0x5e:
        let offset = getRegisterValue(state: state, pair: .H)
        state.e = state.memory[Int(offset)]

    // MOV E,A
    case 0x5f:
        state.e = state.a

    // MOV H,B
    case 0x60:
        state.h = state.b

    // MOV H,C
    case 0x61:
        state.h = state.c

    // MOV H,D
    case 0x62:
        state.h = state.d

    // MOV H,E
    case 0x63:
        state.h = state.e

    // MOV H,H (NOP)
    case 0x64: ()

    // MOV H,L
    case 0x65:
        state.h = state.l

    // MOV H,M
    case 0x66:
        let offset = getRegisterValue(state: state, pair: .H)
        state.h = state.memory[Int(offset)]

    // MOV H,A
    case 0x67:
        state.h = state.a

    // MOV L,B
    case 0x68:
        state.l = state.b

    // MOV L,C
    case 0x69:
        state.l = state.c

    // MOV L,D
    case 0x6a:
        state.l = state.d

    // MOV L,E
    case 0x6b:
        state.l = state.e

    // MOV L,H
    case 0x6c:
        state.l = state.h

    // MOV L,L (NOP)
    case 0x6d: ()

    // MOV L,M
    case 0x6e:
        let offset = getRegisterValue(state: state, pair: .H)
        state.l = state.memory[Int(offset)]

    // MOV L,A
    case 0x6f:
        state.l = state.a

    // MOV M,B
    case 0x70:
        let offset = getRegisterValue(state: state, pair: .H)
        state.memory[Int(offset)] = state.b

    // MOV M,C
    case 0x71:
        let offset = getRegisterValue(state: state, pair: .H)
        state.memory[Int(offset)] = state.c

    // MOV M,D
    case 0x72:
        let offset = getRegisterValue(state: state, pair: .H)
        state.memory[Int(offset)] = state.d

    // MOV M,E
    case 0x73:
        let offset = getRegisterValue(state: state, pair: .H)
        state.memory[Int(offset)] = state.e

    // MOV M,H
    case 0x74:
        let offset = getRegisterValue(state: state, pair: .H)
        state.memory[Int(offset)] = state.h

    // MOV M,L
    case 0x75:
        let offset = getRegisterValue(state: state, pair: .H)
        state.memory[Int(offset)] = state.l

    // HLT
    case 0x76:
        print("HLT - NOT IMPLEMENTED")

    // MOV M,A
    case 0x77:
        let offset = getRegisterValue(state: state, pair: .H)
        state.memory[Int(offset)] = state.a

    // MOV A,B
    case 0x78:
        state.a = state.b

    // MOV A,C
    case 0x79:
        state.a = state.c

    // MOV A,D
    case 0x7a:
        state.a = state.d

    // MOV A,E
    case 0x7b:
        state.a = state.e

    // MOV A,H
    case 0x7c:
        state.a = state.h

    // MOV A,L
    case 0x7d:
        state.a = state.l

    // MOV A,M
    case 0x7e:
        let offset = getRegisterValue(state: state, pair: .H)
        state.a = state.memory[Int(offset)]

    // MOV A,A (NOP)
    case 0x7f: ()

    // ADD B
    case 0x80:
        // Perform addition using 16 bits; makes it easier to see 8-bit overflow
        let result = UInt16(state.a) + UInt16(state.b)
        // Set condition codes (aka flags) based on properties of the result
        setAccumulatorFlags(state: &state, result: result)
        // Set a to first 8 bits of answer
        state.a = UInt8(result & 0xff)

    // ADD C
    case 0x81:
        let result = UInt16(state.a) + UInt16(state.c)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // ADD D
    case 0x82:
        let result = UInt16(state.a) + UInt16(state.d)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // ADD E
    case 0x83:
        let result = UInt16(state.a) + UInt16(state.e)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // ADD H
    case 0x84:
        let result = UInt16(state.a) + UInt16(state.h)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // ADD L
    case 0x85:
        let result = UInt16(state.a) + UInt16(state.l)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // ADD M
    case 0x86:
        let offset = getRegisterValue(state: state, pair: .H)
        let result = UInt16(state.a) + UInt16(state.memory[Int(offset)])
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // ADD A
    case 0x87:
        let result = UInt16(state.a) + UInt16(state.a)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // ADC B
    case 0x88:
        // Also add the carry
        let result = UInt16(state.a) + UInt16(state.b) + UInt16(state.cc.cy)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // ADC C
    case 0x89:
        let result = UInt16(state.a) + UInt16(state.c) + UInt16(state.cc.cy)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // ADC D
    case 0x8a:
        let result = UInt16(state.a) + UInt16(state.d) + UInt16(state.cc.cy)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // ADC E
    case 0x8b:
        let result = UInt16(state.a) + UInt16(state.e) + UInt16(state.cc.cy)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // ADC H
    case 0x8c:
        let result = UInt16(state.a) + UInt16(state.h) + UInt16(state.cc.cy)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // ADC L
    case 0x8d:
        let result = UInt16(state.a) + UInt16(state.l) + UInt16(state.cc.cy)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // ADC M
    case 0x8e:
        let offset = getRegisterValue(state: state, pair: .H)
        let result = UInt16(state.a) + UInt16(state.memory[Int(offset)]) + UInt16(state.cc.cy)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // ADC A
    case 0x8f:
        let result = UInt16(state.a) + UInt16(state.a) + UInt16(state.cc.cy)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // SUB B
    case 0x90:
        let result = UInt16(state.a) - UInt16(state.b)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // SUB C
    case 0x91:
        let result = UInt16(state.a) - UInt16(state.c)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // SUB D
    case 0x92:
        let result = UInt16(state.a) - UInt16(state.d)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // SUB E
    case 0x93:
        let result = UInt16(state.a) - UInt16(state.e)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // SUB H
    case 0x94:
        let result = UInt16(state.a) - UInt16(state.h)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // SUB L
    case 0x95:
        let result = UInt16(state.a) - UInt16(state.l)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // SUB M
    case 0x96:
        let offset = getRegisterValue(state: state, pair: .H)
        let result = UInt16(state.a) - UInt16(state.memory[Int(offset)])
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // SUB A
    case 0x97:
        let result = UInt16(state.a) - UInt16(state.a)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // SBB B
    case 0x98:
        // Add the carry to the addend before subtracting it from the accumulator
        let result = UInt16(state.a) - (UInt16(state.b) + UInt16(state.cc.cy))
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // SBB C
    case 0x99:
        let result = UInt16(state.a) - (UInt16(state.c) + UInt16(state.cc.cy))
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // SBB D
    case 0x9a:
        let result = UInt16(state.a) - (UInt16(state.d) + UInt16(state.cc.cy))
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // SBB E
    case 0x9b:
        let result = UInt16(state.a) - (UInt16(state.e) + UInt16(state.cc.cy))
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // SBB H
    case 0x9c:
        let result = UInt16(state.a) - (UInt16(state.h) + UInt16(state.cc.cy))
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // SBB L
    case 0x9d:
        let result = UInt16(state.a) - (UInt16(state.l) + UInt16(state.cc.cy))
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // SBB M
    case 0x9e:
        let offset = getRegisterValue(state: state, pair: .H)
        let result = UInt16(state.a) - (UInt16(state.memory[Int(offset)]) + UInt16(state.cc.cy))
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // SBB A
    case 0x9f:
        let result = UInt16(state.a) - (UInt16(state.a) + UInt16(state.cc.cy))
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)

    // ANA B
    case 0xa0:
        let result = state.a & state.b
        setLogicFlags(state: &state, result: result)
        state.a = result

    // ANA C
    case 0xa1:
        let result = state.a & state.c
        setLogicFlags(state: &state, result: result)
        state.a = result

    // ANA D
    case 0xa2:
        let result = state.a & state.d
        setLogicFlags(state: &state, result: result)
        state.a = result

    // ANA E
    case 0xa3:
        let result = state.a & state.e
        setLogicFlags(state: &state, result: result)
        state.a = result

    // ANA H
    case 0xa4:
        let result = state.a & state.h
        setLogicFlags(state: &state, result: result)
        state.a = result

    // ANA L
    case 0xa5:
        let result = state.a & state.l
        setLogicFlags(state: &state, result: result)
        state.a = result

    // ANA M
    case 0xa6:
        let offset = getRegisterValue(state: state, pair: .H)
        let result = state.a & state.memory[Int(offset)]
        setLogicFlags(state: &state, result: result)
        state.a = result

    // ANA A
    case 0xa7:
        let result = state.a & state.a
        setLogicFlags(state: &state, result: result)
        state.a = result

    // XRA B
    case 0xa8:
        let result = state.a ^ state.b
        setLogicFlags(state: &state, result: result)
        state.a = result

    // XRA C
    case 0xa9:
        let result = state.a ^ state.c
        setLogicFlags(state: &state, result: result)
        state.a = result

    // XRA D
    case 0xaa:
        let result = state.a ^ state.d
        setLogicFlags(state: &state, result: result)
        state.a = result

    // XRA E
    case 0xab:
        let result = state.a ^ state.e
        setLogicFlags(state: &state, result: result)
        state.a = result

    // XRA H
    case 0xac:
        let result = state.a ^ state.h
        setLogicFlags(state: &state, result: result)
        state.a = result

    // XRA L
    case 0xad:
        let result = state.a ^ state.l
        setLogicFlags(state: &state, result: result)
        state.a = result

    // XRA M
    case 0xae:
        let offset = getRegisterValue(state: state, pair: .H)
        let result = state.a ^ state.memory[Int(offset)]
        setLogicFlags(state: &state, result: result)
        state.a = result

    // XRA A
    case 0xaf:
        let result = state.a ^ state.a
        setLogicFlags(state: &state, result: result)
        state.a = result

    // ORA B
    case 0xb0:
        let result = state.a | state.b
        setLogicFlags(state: &state, result: result)
        state.a = result

    // ORA C
    case 0xb1:
        let result = state.a | state.c
        setLogicFlags(state: &state, result: result)
        state.a = result

    // ORA D
    case 0xb2:
        let result = state.a | state.d
        setLogicFlags(state: &state, result: result)
        state.a = result

    // ORA E
    case 0xb3:
        let result = state.a | state.e
        setLogicFlags(state: &state, result: result)
        state.a = result

    // ORA H
    case 0xb4:
        let result = state.a | state.h
        setLogicFlags(state: &state, result: result)
        state.a = result

    // ORA L
    case 0xb5:
        let result = state.a | state.l
        setLogicFlags(state: &state, result: result)
        state.a = result

    // ORA M
    case 0xb6:
        let offset = getRegisterValue(state: state, pair: .H)
        let result = state.a | state.memory[Int(offset)]
        setLogicFlags(state: &state, result: result)
        state.a = result

    // ORA A
    case 0xb7:
        let result = state.a | state.a
        setLogicFlags(state: &state, result: result)
        state.a = result

    // CMP B
    case 0xb8:
        let result = UInt16(state.a) - UInt16(state.b)
        setAccumulatorFlags(state: &state, result: result)

    // CMP C
    case 0xb9:
        let result = UInt16(state.a) - UInt16(state.c)
        setAccumulatorFlags(state: &state, result: result)

    // CMP D
    case 0xba:
        let result = UInt16(state.a) - UInt16(state.d)
        setAccumulatorFlags(state: &state, result: result)

    // CMP E
    case 0xbb:
        let result = UInt16(state.a) - UInt16(state.e)
        setAccumulatorFlags(state: &state, result: result)

    // CMP H
    case 0xbc:
        let result = UInt16(state.a) - UInt16(state.h)
        setAccumulatorFlags(state: &state, result: result)

    // CMP L
    case 0xbd:
        let result = UInt16(state.a) - UInt16(state.l)
        setAccumulatorFlags(state: &state, result: result)

    // CMP M
    case 0xbe:
        let offset = getRegisterValue(state: state, pair: .H)
        let result = UInt16(state.a) - UInt16(state.memory[Int(offset)])
        setAccumulatorFlags(state: &state, result: result)

    // CMP A
    case 0xbf:
        let result = UInt16(state.a) - UInt16(state.a)
        setAccumulatorFlags(state: &state, result: result)

    // RNZ
    case 0xc0:
        print("RNZ - NOT IMPLEMENTED")

    // POP B
    case 0xc1:
        print("POP B - NOT IMPLEMENTED")

    // JNZ adr
    case 0xc2:
        print("JNZ adr - NOT IMPLEMENTED")
        opBytes = 3

    // JMP adr
    case 0xc3:
        print("JMP adr - NOT IMPLEMENTED")
        opBytes = 3

    // CNZ adr
    case 0xc4:
        print("CNZ adr - NOT IMPLEMENTED")
        opBytes = 3

    // PUSH B
    case 0xc5:
        print("PUSH B - NOT IMPLEMENTED")

    // ADI D8
    case 0xc6:
        // Immediate form; add the byte that comes after the instruction
        let byte = state.memory[Int(state.pc + 1)]
        let result = UInt16(state.a) + UInt16(byte)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)
        
        opBytes = 2

    // RST 0
    case 0xc7:
        print("RST 0 - NOT IMPLEMENTED")

    // RZ
    case 0xc8:
        print("RZ - NOT IMPLEMENTED")

    // RET
    case 0xc9:
        print("RET - NOT IMPLEMENTED")

    // JZ adr
    case 0xca:
        print("JZ adr - NOT IMPLEMENTED")
        opBytes = 3

    // NOP
    case 0xcb: ()

    // CZ adr
    case 0xcc:
        print("CZ adr - NOT IMPLEMENTED")
        opBytes = 3

    // CALL adr
    case 0xcd:
        print("CALL adr - NOT IMPLEMENTED")
        opBytes = 3

    // ACI D8
    case 0xce:
        // Immediate form (with carry); add the byte that comes after the instruction
        let byte = state.memory[Int(state.pc + 1)]
        let result = UInt16(state.a) + UInt16(byte) + UInt16(state.cc.cy)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)
        
        opBytes = 2

    // RST 1
    case 0xcf:
        print("RST 1 - NOT IMPLEMENTED")

    // RNC
    case 0xd0:
        print("RNC - NOT IMPLEMENTED")

    // POP D
    case 0xd1:
        print("POP D - NOT IMPLEMENTED")

    // JNC adr
    case 0xd2:
        print("JNC adr - NOT IMPLEMENTED")
        opBytes = 3

    // OUT D8
    case 0xd3:
        print("OUT D8 - NOT IMPLEMENTED")
        opBytes = 2

    // CNC adr
    case 0xd4:
        print("CNC adr - NOT IMPLEMENTED")
        opBytes = 3

    // PUSH D
    case 0xd5:
        print("PUSH D - NOT IMPLEMENTED")

    // SUI D8
    case 0xd6:
        // Immediate form; subtract the byte that comes after the instruction
        let byte = state.memory[Int(state.pc + 1)]
        let result = UInt16(state.a) - UInt16(byte)
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)
        
        opBytes = 2

    // RST 2
    case 0xd7:
        print("RST 2 - NOT IMPLEMENTED")

    // RC
    case 0xd8:
        print("RC - NOT IMPLEMENTED")

    // NOP
    case 0xd9: ()

    // JC adr
    case 0xda:
        print("JC adr - NOT IMPLEMENTED")
        opBytes = 3

    // IN D8
    case 0xdb:
        print("IN D8 - NOT IMPLEMENTED")
        opBytes = 2

    // CC adr
    case 0xdc:
        print("CC adr - NOT IMPLEMENTED")
        opBytes = 3

    // NOP
    case 0xdd: ()

    // SBI D8
    case 0xde:
        // Immediate form (with carry); subtract the byte that comes after the instruction
        let byte = state.memory[Int(state.pc + 1)]
        let result = UInt16(state.a) - (UInt16(byte) + UInt16(state.cc.cy))
        setAccumulatorFlags(state: &state, result: result)
        state.a = UInt8(result & 0xff)
        
        opBytes = 2

    // RST 3
    case 0xdf:
        print("RST 3 - NOT IMPLEMENTED")

    // RPO
    case 0xe0:
        print("RPO - NOT IMPLEMENTED")

    // POP H
    case 0xe1:
        print("POP H - NOT IMPLEMENTED")

    // JPO adr
    case 0xe2:
        print("JPO adr - NOT IMPLEMENTED")
        opBytes = 3

    // XTHL
    case 0xe3:
        print("XTHL - NOT IMPLEMENTED")

    // CPO adr
    case 0xe4:
        print("CPO adr - NOT IMPLEMENTED")
        opBytes = 3

    // PUSH H
    case 0xe5:
        print("PUSH H - NOT IMPLEMENTED")

    // ANI D8
    case 0xe6:
        print("ANI D8 - NOT IMPLEMENTED")
        opBytes = 2

    // RST 4
    case 0xe7:
        print("RST 4 - NOT IMPLEMENTED")

    // RPE
    case 0xe8:
        print("RPE - NOT IMPLEMENTED")

    // PCHL
    case 0xe9:
        print("PCHL - NOT IMPLEMENTED")

    // JPE adr
    case 0xea:
        print("JPE adr - NOT IMPLEMENTED")
        opBytes = 3

    // XCHG
    case 0xeb:
        print("XCHG - NOT IMPLEMENTED")

    // CPE adr
    case 0xec:
        print("CPE adr - NOT IMPLEMENTED")
        opBytes = 3

    // NOP
    case 0xed: ()

    // XRI D8
    case 0xee:
        print("XRI D8 - NOT IMPLEMENTED")
        opBytes = 2

    // RST 5
    case 0xef:
        print("RST 5 - NOT IMPLEMENTED")

    // RP
    case 0xf0:
        print("RP - NOT IMPLEMENTED")

    // POP PSW
    case 0xf1:
        print("POP PSW - NOT IMPLEMENTED")

    // JP adr
    case 0xf2:
        print("JP adr - NOT IMPLEMENTED")
        opBytes = 3

    // DI
    case 0xf3:
        print("DI - NOT IMPLEMENTED")

    // CP adr
    case 0xf4:
        print("CP adr - NOT IMPLEMENTED")
        opBytes = 3

    // PUSH PSW
    case 0xf5:
        print("PUSH PSW - NOT IMPLEMENTED")

    // ORI D8
    case 0xf6:
        print("ORI D8 - NOT IMPLEMENTED")
        opBytes = 2

    // RST 6
    case 0xf7:
        print("RST 6 - NOT IMPLEMENTED")

    // RM
    case 0xf8:
        print("RM - NOT IMPLEMENTED")

    // SPHL
    case 0xf9:
        print("SPHL - NOT IMPLEMENTED")

    // JM adr
    case 0xfa:
        print("JM adr - NOT IMPLEMENTED")
        opBytes = 3

    // EI
    case 0xfb:
        print("EI - NOT IMPLEMENTED")

    // CM adr
    case 0xfc:
        print("CM adr - NOT IMPLEMENTED")
        opBytes = 3

    // NOP
    case 0xfd: ()

    // CPI D8
    case 0xfe:
        print("CPI D8 - NOT IMPLEMENTED")
        opBytes = 2

    // RST 7
    case 0xff:
        print("RST 7 - NOT IMPLEMENTED")

    default:
        print("ERROR")
    }

    state.pc += opBytes

    return state
}
