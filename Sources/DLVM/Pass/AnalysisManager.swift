//
//  AnalysisManager.swift
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

internal struct PreservedAnalyses {
    private typealias ID = ObjectIdentifier

    private var analysisMap: [ID : Any] = [:]

    func result<Pass : AnalysisPass>(from _: Pass.Type) -> Pass.Result? {
        /// If result is cached, return it
        return analysisMap[ID(Pass.self)] as? Pass.Result
    }

    func containsResult<Pass : AnalysisPass>(from type: Pass.Type) -> Bool {
        return result(from: type) != nil
    }

    mutating func insert<Pass : AnalysisPass>(_ result: Pass.Result,
                                              for type: Pass.Type) {
        analysisMap[ID(type)] = result
    }

    mutating func removeResult<Pass : AnalysisPass>(from type: Pass.Type) -> Pass.Result? {
        return analysisMap.removeValue(forKey: ID(type)) as? Pass.Result
    }

    mutating func removeAll() {
        analysisMap.removeAll()
    }
}

public class AnalysisManager<Body : IRCollection> {
    fileprivate var analyses: PreservedAnalyses = PreservedAnalyses()
    internal init() {}
}


public extension AnalysisManager {
    func invalidateAll() {
        analyses.removeAll()
    }

    @discardableResult
    func invalidateAnalysis<Pass : AnalysisPass>(from pass: Pass.Type) -> Pass.Result? {
        return analyses.removeResult(from: pass)
    }

    func updateAnalysis<Pass : AnalysisPass>(_ result: Pass.Result, from pass: Pass.Type) {
        analyses.insert(result, for: pass)
    }

    func analysis<Pass : AnalysisPass>(from pass: Pass.Type) -> Pass.Result? {
        return analyses.result(from: pass)
    }
}

public extension IRCollection {
    func analysis<Pass : AnalysisPass>(from pass: Pass.Type) throws -> Pass.Result
        where Pass.Body == Self
    {
        if let result = analysisManager.analysis(from: pass) {
            return result
        }
        let result = try Pass.run(on: self)
        analysisManager.updateAnalysis(result, from: pass)
        return result
    }
}

internal extension IRCollection {
    func invalidateLocalAnalyses() {
        analysisManager.invalidateAll()
    }
}

public extension IRCollection where Self : IRUnit {
    func invalidateAnalyses() {
        invalidateLocalAnalyses()
        parent.invalidateAnalyses()
    }
}

public extension Module {
    func invalidateAnalyses() {
        invalidateLocalAnalyses()
    }
}
