//
//  Use.swift
//  DLVM
//
//  Copyright 2016-2017 Richard Wei.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

public indirect enum Use {
    case argument(Type, Argument)
    case instruction(Type, Instruction)
    case global(Type, GlobalValue)
    case literal(Type, Literal)
    case function(Type, Function)
    case constant(Type, InstructionKind)
}

// MARK: - Equatable
extension Use : Equatable {
    public static func ==(lhs: Use, rhs: Use) -> Bool {
        switch (lhs, rhs) {
        case let (.argument(t1, v1), .argument(t2, v2)):
            return t1 == t2 && v1 === v2
        case let (.instruction(t1, v1), .instruction(t2, v2)):
            return t1 == t2 && v1 === v2
        case let (.global(t1, v1), .global(t2, v2)):
            return t1 == t2 && v1 === v2
        case let (.literal(t1, l1), .literal(t2, l2)):
            return t1 == t2 && l1 == l2
        case let (.function(t1, f1), .function(t2, f2)):
            return t1 == t2 && f1 === f2
        default:
            return false
        }
    }
}

// MARK: - Value properties
public extension Use {

    var type: Type {
        switch self {
        case .argument(let t, _),
             .instruction(let t, _),
             .global(let t, _),
             .literal(let t, _),
             .function(let t, _),
             .constant(let t, _):
            return t
        }
    }

    var value: Value {
        switch self {
        case let .argument(_, val): return val
        case let .global(_, val): return val
        case let .instruction(_, val): return val
        case let .function(_, val): return val
        case let .literal(ty, lit): return LiteralValue(type: ty, literal: lit)
        case let .constant(_, instKind): return instKind
        }
    }

    var name: String? {
        switch self {
        case let .global(_, def): return def.name
        case let .instruction(_, def): return def.name
        case let .argument(_, def): return def.name
        case let .function(_, def): return def.name
        case .literal, .constant: return nil
        }
    }

}

infix operator ~

public func ~ (lhs: Literal, rhs: Type) -> Use {
    return .literal(rhs, lhs)
}
