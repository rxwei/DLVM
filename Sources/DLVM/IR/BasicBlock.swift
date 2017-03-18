//
//  BasicBlock.swift
//  DLVM
//
//  Created by Richard Wei on 12/18/16.
//
//

public class Argument : Value, Named, Definition, HashableByReference {
    public var name: String
    public var type: Type
    public weak var parent: BasicBlock?

    public init(name: String, type: Type) {
        self.name = name
        self.type = type
    }
}

public final class BasicBlock : IRCollection, IRSubUnit, Named {

    public typealias Element = Instruction

    /// Name of the basic block
    open var name: String
    open var arguments: OrderedMapSet<Argument> = []
    open var elements: OrderedMapSet<Instruction> = []
    open unowned var parent: Function
    public internal(set) var analysisManager: AnalysisManager<BasicBlock> = AnalysisManager()
    public internal(set) var transformManager: TransformManager<BasicBlock> = TransformManager()

    internal init<C: Collection>(name: String, arguments: C, parent: Function)
        where C.Iterator.Element == Argument
    {
        self.name = name
        self.arguments.append(contentsOf: arguments)
        self.parent = parent
        /// Set parent of each arg to self
        for arg in arguments {
            arg.parent = self
        }
    }

    internal convenience init(asEntryOf parent: Function) {
        self.init(name: "entry", arguments: parent.arguments, parent: parent)
    }

    public convenience init(name: String, arguments: [(String, Type)], parent: Function) {
        self.init(name: name, arguments: arguments.map(Argument.init), parent: parent)
    }

}

// MARK: - Predicates and accessors
public extension BasicBlock {

    /// Whether there exists a terminator instruction
    /// - Note: a branching instruction in the middle of the basic block
    /// is not considered a terminator
    var hasTerminator: Bool {
        return elements.last?.kind.isTerminator ?? false
    }

    /// Terminator instruction
    var terminator: Instruction? {
        guard let last = elements.last, last.kind.isTerminator else {
            return nil
        }
        return last
    }

    var successorCount: Int {
        return terminator?.successorCount ?? 0
    }

    var hasSuccessors: Bool {
        return successorCount > 0
    }

    var isReturn: Bool {
        return terminator?.kind.isReturn ?? false
    }

    var module: Module {
        return parent.parent
    }

    var isEntry: Bool {
        return parent.entry === self
    }

}

// MARK: - Arguments
public extension BasicBlock {

    func acceptsArguments<C : Collection>(_ types: C) -> Bool where C.Iterator.Element == Type {
        return types.elementsEqual(arguments.map{$0.type})
    }

    func argument(named name: String) -> Argument? {
        return arguments.element(named: name)
    }

    func containsArgument(named name: String) -> Bool {
        return arguments.containsElement(named: name)
    }
    
}
