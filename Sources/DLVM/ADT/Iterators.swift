//
//  Iterators.swift
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

import class Foundation.NSMutableSet

public enum TraversalOrder {
    case preorder, postorder, breadthFirst
}

public struct GraphNodeIterator<Node : ForwardGraphNode> : IteratorProtocol {

    private var pre: [Node] = []
    private var post: [Node] = []
    private var visited = NSMutableSet()
    public let order: TraversalOrder

    public init(root: Node?, order: TraversalOrder) {
        if let root = root {
            pre.append(root)
        }
        self.order = order
    }

    public mutating func next() -> Node? {
        switch order {
        case .breadthFirst:
            if pre.isEmpty { return nil }
            let node = pre.removeFirst()
            for child in node.successors where !visited.contains(child) {
                pre.append(child)
            }
            visited.add(node)
            return node

        case .preorder:
            if pre.isEmpty { return nil }
            let node = pre.removeLast()
            for child in node.successors.reversed() where !visited.contains(child) {
                pre.append(child)
            }
            visited.add(node)
            return node

        case .postorder:
            if pre.isEmpty { return post.popLast() }
            let node = pre.removeLast()
            for child in node.successors where !visited.contains(child) {
                pre.append(child)
            }
            post.append(node)
            visited.add(node)
            return next()
        }
    }
}

public struct TransposeGraphNodeIterator<Node : BackwardGraphNode> : IteratorProtocol {

    private var pre: [Node] = []
    private var post: [Node] = []
    private var visited = NSMutableSet()
    public let order: TraversalOrder

    public init(root: Node?, order: TraversalOrder) {
        if let root = root {
            pre.append(root)
        }
        self.order = order
    }

    public mutating func next() -> Node? {
        switch order {
        case .breadthFirst:
            if pre.isEmpty { return nil }
            let node = pre.removeFirst()
            for child in node.predecessors where !visited.contains(child) {
                pre.append(child)
            }
            visited.add(node)
            return node

        case .preorder:
            if pre.isEmpty { return nil }
            let node = pre.removeLast()
            for child in node.predecessors.reversed() where !visited.contains(child) {
                pre.append(child)
            }
            visited.add(node)
            return node

        case .postorder:
            if pre.isEmpty { return post.popLast() }
            let node = pre.removeLast()
            for child in node.predecessors where !visited.contains(child) {
                pre.append(child)
            }
            post.append(node)
            visited.add(node)
            return next()
        }
    }
    
}

public extension ForwardGraphNode {
    func traversed(in order: TraversalOrder) -> IteratorSequence<GraphNodeIterator<Self>> {
        return IteratorSequence(GraphNodeIterator(root: self, order: order))
    }

    var preorder: IteratorSequence<GraphNodeIterator<Self>> {
        return traversed(in: .preorder)
    }

    var postorder: IteratorSequence<GraphNodeIterator<Self>> {
        return traversed(in: .postorder)
    }

    var breadthFirst: IteratorSequence<GraphNodeIterator<Self>> {
        return traversed(in: .breadthFirst)
    }
}

public extension BackwardGraphNode {
    func transposeTraversed(in order: TraversalOrder) -> IteratorSequence<TransposeGraphNodeIterator<Self>> {
        return IteratorSequence(TransposeGraphNodeIterator(root: self, order: order))
    }
}

public struct DirectedGraphIterator<Base : BidirectionalEdgeSet> : IteratorProtocol {
    public typealias Element = Base.Node

    private var pre: [Base.Node] = []
    private var post: [Base.Node] = []
    private var visited: ObjectSet<Base.Node> = []
    public let order: TraversalOrder
    public let base: Base

    public init(base: Base, source: Base.Node?, order: TraversalOrder) {
        self.base = base
        if let source = source {
            pre.append(source)
        }
        self.order = order
    }
    
    public mutating func next() -> Base.Node? {
        switch order {
        case .breadthFirst:
            if pre.isEmpty { return nil }
            let node = pre.removeFirst()
            for child in base.successors(of: node) where !visited.contains(child) {
                pre.append(child)
            }
            visited.insert(node)
            return node
            
        case .preorder:
            if pre.isEmpty { return nil }
            let node = pre.removeLast()
            for child in base.successors(of: node).reversed() where !visited.contains(child) {
                pre.append(child)
            }
            visited.insert(node)
            return node
            
        case .postorder:
            if pre.isEmpty { return post.popLast() }
            let node = pre.removeLast()
            for child in base.successors(of: node) where !visited.contains(child) {
                pre.append(child)
            }
            post.append(node)
            visited.insert(node)
            return next()
        }
        
    }
}

// MARK: - Iterators
public extension BidirectionalEdgeSet {
    public func traversed(from source: Node, in order: TraversalOrder) -> IteratorSequence<DirectedGraphIterator<Self>> {
        return IteratorSequence(DirectedGraphIterator(base: self, source: source, order: order))
    }
}
