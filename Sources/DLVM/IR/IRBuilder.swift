//
//  IRBuilder.swift
//  DLVM
//
//  Created by Richard Wei on 12/18/16.
//
//

open class IRBuilder {
    fileprivate let _module: Module

    open var module: Module {
        _module.updateAnalysisInformation()
        return _module
    }

    var currentBlock: BasicBlock?

    fileprivate var variableNameId: Int = 0
    fileprivate var blockNameId: Int = 0
    fileprivate var nameIdTable: [String : Int] = [:]
    
    public init(moduleName: String) {
        _module = Module(name: moduleName)
    }
}

// MARK: - Helpers
extension IRBuilder {
    
    func makeVariableName() -> String {
        defer { variableNameId += 1 }
        return disambiguatedName(for: "v\(variableNameId)")
    }

    func makeBlockName() -> String {
        defer { blockNameId += 1 }
        return disambiguatedName(for: "BB\(blockNameId)")
    }
    
    func disambiguatedName(for name: String) -> String {
        if let id = nameIdTable[name] {
            nameIdTable[name] = id + 1
            return name + ".\(id)"
        }
        nameIdTable[name] = 1
        return name
    }

}

// MARK: - Main builder API
extension IRBuilder {
    
    private func build<Inst : Instruction>(_ instruction: Inst) -> Inst {
        guard let block = currentBlock else {
            preconditionFailure("Current block doesn't exist")
        }
        block.append(instruction)
        instruction.updateUsers()
        return instruction
    }

    @discardableResult
    open func declare(_ input: Input) -> Input {
        _module.insert(input)
        return input
    }

    @discardableResult
    open func declare(_ parameter: Parameter) -> Parameter {
        _module.insert(parameter)
        return parameter
    }

    @discardableResult
    open func declare(_ output: Output) -> Output {
        _module.insert(output)
        return output
    }
    
    @discardableResult
    open func declareInput(name: String, type: DataType, shape: TensorShape) -> Input {
        let input = Input(name: name, type: type, shape: shape)
        _module.insert(input)
        return input
    }
    
    @discardableResult
    open func declareOutput(name: String, type: DataType, shape: TensorShape) -> Output {
        let output = Output(name: name, type: type, shape: shape)
        _module.insert(output)
        return output
    }
    
    @discardableResult
    open func declareParameter(name: String, type: DataType, shape: TensorShape,
                               initializer: Initializer) -> Parameter {
        let parameter = Parameter(name: name, type: type, shape: shape,
                                  initializer: initializer)
        _module.insert(parameter)
        return parameter
    }

    @discardableResult
    open func declareConstant(name: String, type: DataType, shape: TensorShape,
                              defaultInitializer: Initializer) -> Constant {
        let constant = Constant(name: name, type: type, shape: shape,
                                defaultInitializer: defaultInitializer)
        _module.insert(constant)
        return constant
    }

    @discardableResult
    open func makeGlobalBasicBlock(named name: String) -> BasicBlock {
        let block = BasicBlock(name: disambiguatedName(for: name))
        _module.insert(block)
        return block
    }

    @discardableResult
    open func makeExtension(ofType type: BasicBlock.ExtensionType, for basicBlock: BasicBlock) -> BasicBlock {
        return basicBlock.makeExtension(ofType: type)
    }
    
    @discardableResult
    open func makeArithmeticOperation(_ `operator`: ArithmeticOperator,
                                      _ lhs: Value, _ rhs: Value,
                                      name: String? = nil) -> ArithmeticInstruction {
        let inst = ArithmeticInstruction(name: name ?? makeVariableName(),
                                         function: `operator`,
                                         firstOperand: lhs, secondOperand: rhs)
        return build(inst)
    }

    @discardableResult
    open func makeLogicOperation(_ `operator`: LogicOperator,
                                 _ lhs: Value, _ rhs: Value,
                                 name: String? = nil) -> LogicInstruction {
        let inst = LogicInstruction(name: name ?? makeVariableName(),
                                    function: `operator`,
                                    firstOperand: lhs, secondOperand: rhs)
        return build(inst)
    }
    
    @discardableResult
    open func makeComparison(_ `operator`: ComparisonPredicate,
                             _ lhs: Value, _ rhs: Value,
                             name: String? = nil) -> ComparisonInstruction {
        let inst = ComparisonInstruction(name: name ?? makeVariableName(),
                                         function: `operator`,
                                         firstOperand: lhs, secondOperand: rhs)
        return build(inst)
    }
    
    @discardableResult
    open func makeTensorMultiplication(_ lhs: Value, _ rhs: Value,
                                       name: String? = nil) -> TensorMultiplicationInstruction {
        let inst = TensorMultiplicationInstruction(name: name ?? makeVariableName(),
                                                   firstOperand: lhs, secondOperand: rhs)
        return build(inst)
    }
    
    @discardableResult
    open func makeMatrixMultiplication(_ lhs: Value, _ rhs: Value,
                                       name: String? = nil) -> MatrixMultiplicationInstruction {
        let inst = MatrixMultiplicationInstruction(name: name ?? makeVariableName(),
                                                   firstOperand: lhs, secondOperand: rhs)
        return build(inst)
    }
    
    @discardableResult
    open func makeElementwiseTransformation(_ function: ElementwiseFunction,
                                            _ operand: Value,
                                            name: String? = nil) -> ElementwiseInstruction {
        let inst = ElementwiseInstruction(name: name ?? makeVariableName(),
                                          function: function, operand: operand)
        return build(inst)
    }
    
    @discardableResult
    open func makeAggregation(_ function: AggregationFunction,
                              _ operand: Value,
                              name: String? = nil) -> AggregationInstruction {
        let inst = AggregationInstruction(name: name ?? makeVariableName(),
                                          function: function, operand: operand)
        return build(inst)
    }

    @discardableResult
    open func makeReduction(_ function: ReductionFunction, _ operand: Value, axis: Int? = nil,
                            name: String? = nil) -> ReductionInstruction {
        let inst = ReductionInstruction(name: name ?? makeVariableName(), function: function,
                                        operand: operand, axis: axis)
        return build(inst)
    }
    
    @discardableResult
    open func makeConcatenation(_ operands: [Value], axis: Int,
                                name: String? = nil) -> ConcatenationInstruction {
        let inst = ConcatenationInstruction(name: name ?? makeVariableName(),
                                            operands: operands, axis: axis)
        return build(inst)
    }
    
    @discardableResult
    open func makeShapeCast(_ operand: Value, targetShape: TensorShape,
                            name: String? = nil) -> ShapeCastInstruction {
        let inst = ShapeCastInstruction(name: name ?? makeVariableName(),
                                        operand: operand, target: targetShape)
        return build(inst)
    }
    
    @discardableResult
    open func makeTypeCast(_ operand: Value, targetType: DataType,
                           name: String? = nil) -> TypeCastInstruction {
        let inst = TypeCastInstruction(name: name ?? makeVariableName(), operand: operand,
                                       target: targetType)
        return build(inst)
    }
    
    @discardableResult
    open func makeLoad(_ source: Input, name: String? = nil) -> LoadInstruction {
        let inst = LoadInstruction(name: name ?? makeVariableName(), source: source)
        return build(inst)
    }

    @discardableResult
    open func makeExport(_ source: Value, to destination: Output) -> ExportInstruction {
        let inst = ExportInstruction(source: source, destination: destination)
        return build(inst)
    }
    
    @discardableResult
    open func makeStore(_ source: Value, to destination: Parameter) -> StoreInstruction {
        let inst = StoreInstruction(source: source, destination: destination)
        return build(inst)
    }

    @discardableResult
    open func makeLoop(onCondition condition: LoopInstruction.Condition,
                       name: String? = nil,
                       inLoopBody executeInLoopBody: ((BasicBlock) -> Void)? = nil) -> LoopInstruction {
        guard let block = currentBlock else {
            preconditionFailure("Current block doesn't exist")
        }
        let body = BasicBlock(name: name ?? makeBlockName(), parent: block)
        let inst = LoopInstruction(condition: condition,
                                   body: body)
        if let executeInLoopBody = executeInLoopBody {
            move(to: body)
            executeInLoopBody(body)
            moveToParentBlock()
        }
        return build(inst)
    }

}

// MARK: - Positioning
extension IRBuilder {

    open func move(to basicBlock: BasicBlock) {
        currentBlock = basicBlock
    }

    open func moveToParentBlock() {
        currentBlock = currentBlock?.parent
    }

}