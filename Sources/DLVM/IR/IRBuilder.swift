//
//  IRBuilder.swift
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

import CoreTensor

open class IRBuilder {

    open let module: Module

    open fileprivate(set) weak var currentBlock: BasicBlock? {
        didSet {
            currentFunction = currentBlock?.parent
        }
    }

    open weak var currentFunction: Function? {
        didSet {
            if oldValue !== currentFunction {
                variableNameId = 0
            }
        }
    }

    fileprivate var variableNameId = 0

    public init(module: Module) {
        self.module = module
    }

}

public extension IRBuilder {

    convenience init(moduleName: String) {
        self.init(module: Module(name: moduleName))
    }

    convenience init(function: Function) {
        self.init(module: function.parent)
    }

    convenience init(basicBlock: BasicBlock) {
        self.init(module: basicBlock.module)
        move(to: basicBlock)
    }

}

// MARK: - Helpers
extension IRBuilder {

    func makeVariableName(in function: Function) -> String {
        defer { variableNameId += 1 }
        return disambiguatedName(for: "v\(variableNameId)", in: function)
    }

    func disambiguatedName(for name: String, in function: Function, id: Int = 0) -> String {
        let newName = id == 0 ? name : name + ".\(id)"
        return function.containsName(newName)
             ? disambiguatedName(for: name, in: function, id: id + 1)
             : newName
    }

}

// MARK: - Main builder API
extension IRBuilder {

    @discardableResult
    open func buildStruct(named name: String, fields: DictionaryLiteral<String, Type>,
                          attributes: Set<StructType.Attribute> = []) -> StructType {
        let structTy = StructType(name: name, fields: fields.map{$0}, attributes: attributes)
        module.structs.append(structTy)
        return structTy
    }

    @discardableResult
    open func buildAlias(named name: String, for type: Type? = nil) -> Type {
        let alias = TypeAlias(name: name, type: type)
        module.typeAliases.append(alias)
        return .alias(alias)
    }

    @discardableResult
    open func buildGlobalValue(named name: String,
                               kind: GlobalValue.Kind,
                               type: Type,
                               initializer: Use) -> GlobalValue {
        let value = GlobalValue(name: name, kind: kind, type: type, initializer: initializer)
        module.globalValues.append(value)
        return value
    }

    @discardableResult
    open func buildFunction(named name: String,
                            arguments: DictionaryLiteral<String, Type>,
                            result: Type = .void,
                            attributes: Set<Function.Attribute> = []) -> Function {
        let fun = Function(name: name,
                           arguments: Array(arguments),
                           result: result,
                           attributes: attributes,
                           parent: module)
        module.append(fun)
        return fun
    }

    @discardableResult
    open func buildBasicBlock(named name: String,
                              arguments: DictionaryLiteral<String, Type>,
                              in function: Function) -> BasicBlock {
        if name == "entry" { return function.entry }
        let newName = disambiguatedName(for: name, in: function)
        let block = BasicBlock(name: newName, arguments: Array(arguments), parent: function)
        function.append(block)
        return block
    }

    @discardableResult
    open func buildInstruction(_ kind: InstructionKind, name: String? = nil) -> Instruction {
        guard let block = currentBlock else {
            preconditionFailure("Builder isn't positioned at a basic block")
        }
        let function = block.parent
        let inst = Instruction(name: kind.type.isVoid ? nil : (name ?? makeVariableName(in: function)),
                               kind: kind, parent: block)
        block.append(inst)
        return inst
    }
}

// MARK: - Positioning
extension IRBuilder {
    open func move(to basicBlock: BasicBlock?) {
        currentBlock = basicBlock
    }
}

// MARK: - Op sugar
/// - Note: This extension is only providing limited sugar functions 
/// for common instructions. For full power, please use `buildInstruction`
/// with the algebraic data type `InstructionKind`
public extension IRBuilder {
    func add(_ lhs: Use, _ rhs: Use, broadcasting bc: BroadcastingConfig? = nil) -> Instruction {
        return buildInstruction(.binary(.associative(.arithmetic(.add)), lhs, rhs, bc))
    }

    func subtract(_ lhs: Use, _ rhs: Use, broadcasting bc: BroadcastingConfig? = nil) -> Instruction {
        return buildInstruction(.binary(.associative(.arithmetic(.subtract)), lhs, rhs, bc))
    }

    func multiply(_ lhs: Use, _ rhs: Use, broadcasting bc: BroadcastingConfig? = nil) -> Instruction {
        return buildInstruction(.binary(.associative(.arithmetic(.multiply)), lhs, rhs, bc))
    }

    func divide(_ lhs: Use, _ rhs: Use, broadcasting bc: BroadcastingConfig? = nil) -> Instruction {
        return buildInstruction(.binary(.associative(.arithmetic(.divide)), lhs, rhs, bc))
    }

    func power(_ lhs: Use, _ rhs: Use, broadcasting bc: BroadcastingConfig? = nil) -> Instruction {
        return buildInstruction(.binary(.associative(.arithmetic(.power)), lhs, rhs, bc))
    }

    func compare(_ operator: ComparisonOp, _ lhs: Use, _ rhs: Use, broadcasting bc: BroadcastingConfig? = nil) -> Instruction {
        return buildInstruction(.binary(.comparison(`operator`), lhs, rhs, bc))
    }

    func apply(_ function: Use, _ arguments: [Use]) -> Instruction {
        return buildInstruction(.apply(function, arguments))
    }

    func gradient(_ function: Function, from output: Int,
                  withRespectTo variables: [Int],
                  keepingOutputs outputIndices: [Int]) -> Instruction {
        return buildInstruction(.gradient(%function,
                                          from: output,
                                          wrt: variables,
                                          keeping: outputIndices))
    }

    func matrixMultiply(_ lhs: Use, _ rhs: Use) -> Instruction {
        return buildInstruction(.matrixMultiply(lhs, rhs))
    }

    func transpose(_ use: Use) -> Instruction {
        return buildInstruction(.transpose(use))
    }

    func transform(_ operation: ElementwiseOp, _ use: Use) -> Instruction {
        return buildInstruction(.unary(.elementwise(operation), use))
    }

    func `return`(_ use: Use? = nil) {
        buildInstruction(.return(use))
    }

    func branch(_ destination: BasicBlock, _ arguments: [Use]) {
        buildInstruction(.branch(destination, arguments))
    }

    func conditional(_ condition: Use,
                     then thenBB: BasicBlock, arguments thenArguments: [Use],
                     else elseBB: BasicBlock, arguments elseArguments: [Use]) {
        buildInstruction(.conditional(condition,
                                      thenBB, thenArguments,
                                      elseBB, elseArguments))
    }

    func extract(from source: Use, at indices: [ElementKey]) -> Instruction {
        return buildInstruction(.extract(from: source, at: indices))
    }

    func insert(_ source: Use, to destination: Use, at indices: [ElementKey]) -> Instruction {
        return buildInstruction(.insert(source, to: destination, at: indices))
    }

    func elementPointer(from source: Use, at indices: [ElementKey]) -> Instruction {
        return buildInstruction(.elementPointer(source, indices))
    }

    func load(from source: Use) -> Instruction {
        return buildInstruction(.load(source))
    }

    func store(_ source: Use, to destination: Use) {
        buildInstruction(.store(source, to: destination))
    }

    func bitCast(_ source: Use, to targetType: Type) -> Instruction {
        return buildInstruction(.bitCast(source, targetType))
    }

    func shapeCast(_ source: Use, to targetShape: TensorShape) -> Instruction {
        return buildInstruction(.shapeCast(source, targetShape))
    }

    func dataTypeCast(_ source: Use, to targetDataType: DataType) -> Instruction {
        return buildInstruction(.dataTypeCast(source, targetDataType))
    }

    func allocateHeap(for type: Type, count: Use) -> Instruction {
        return buildInstruction(.allocateHeap(type, count: count))
    }

    func allocateBox(for type: Type) -> Instruction {
        return buildInstruction(.allocateBox(type))
    }

    func projectBox(_ box: Use) -> Instruction {
        return buildInstruction(.projectBox(box))
    }

    func deallocate(_ use: Use) {
        buildInstruction(.deallocate(use))
    }

}
