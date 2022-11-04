//
//  MainCommand.swift
//  RIBsTreeMaker
//
//  Created by 今入　庸介 on 2020/02/05.
//

import Foundation
import SourceKittenFramework
import Rainbow

struct MainCommand {
    private let structures: [Structure]?
    private let rootRIBName: String
    
    init(paths: [String], rootRIBName: String) {
        print("")
        print("Analyze \(paths.count) swift files.".applyingStyle(.bold))
        print("")
        print("Make RIBs tree under \(rootRIBName) RIB.".applyingStyle(.underline))
        print("")
        self.rootRIBName = rootRIBName
        do {
            structures = try paths.map({ File(path: $0) }).compactMap({ $0 }).map({ try Structure(file: $0) })
        }
        catch {
            print("Cannot create structure. Check the target path.")
            structures = nil
        }
    }
}

// MARK: - Command
extension MainCommand: Command {
    func run() -> Result {
        guard let structures = structures else {
            return .failure(error: .notFoundStructure)
        }
        
        let edges = makeEdges(from: structures).sorted()
        showHeader()
        showMindmapStyle()
        showRIBsTree(edges: edges, targetName: rootRIBName, count: 1)
        showFooter()
        showPreviewWeb()
        
        return .success(message: "\nSuccessfully completed.".green.applyingStyle(.bold))
    }
}

// MARK: - Private Methods
private extension MainCommand {
    func makeEdges(from structures: [Structure]) -> Set<Edge> {
        var edges = Set<Edge>()
        var leftNodes = Set<Node>()
        
        for structure in structures {
            guard let substructures = structure.dictionary["key.substructure"] as? [[String: SourceKitRepresentable]] else {
                continue
            }
            
            for substructure in substructures {
                guard let kindValue = substructure["key.kind"] as? String else {
                    continue
                }
                
                guard let kind = SwiftDeclarationKind(rawValue: kindValue) else {
                    continue
                }
                
                guard [.class, .protocol].contains(kind) else {
                    continue
                }
                
                guard let nameValue = substructure["key.name"] as? String else {
                    continue
                }
                
                let leftNode = Node(name: nameValue)
                leftNodes.insert(leftNode)
                
                if let inheritedTypes = substructure["key.inheritedtypes"] as? [[String: SourceKitRepresentable]] {
                    for inheritedType in inheritedTypes {
                        guard let inheritedTypeName = inheritedType["key.name"] as? String else {
                            continue
                        }
                        
                        let rightNode = Node(name: inheritedTypeName)
                        
                        if leftNode == rightNode {
                            continue
                        }
                        
                        
                        let edge = Edge(left: leftNode, right: rightNode)
                        edges.insert(edge)
                    }
                }
            }
        }
        return edges
    }
    
    func showRIBsTree(edges: [Edge], targetName: String, count: Int) {
        var indent = ""
        for _ in 0..<count {
            indent += "*"
        }
        let viewControllablers = extractViewController(from: edges)
        let hasViewController = viewControllablers.contains(targetName)
        let suffix = hasViewController ? "<<Viewful>>" : "<<Viewless>>"
        print(indent + " " + targetName + suffix)
        
        for edge in edges {
            if let interactable = extractInteractable(from: edge.leftName) {
                if interactable == targetName {
                    if let listener = extractListener(from: edge.rightName) {
                        showRIBsTree(edges: edges, targetName: listener, count: count + 1)
                    }
                }
            }
        }
    }
    
    func showMindmapStyle() {
        let style = """
        <style>
        mindmapDiagram {
          .Viewful {
            BackGroundColor #00c88b
          }
          .Viewless {
            BackGroundColor #d3d3d3
          }
        }
        </style>
        """
        
        print(style)
    }
    
    func showHeader() {
        print("@startmindmap")
    }
    
    func showFooter() {
        print("@endmindmap")
    }
    
    func showPreviewWeb() {
        print("\n")
        print("https://sujoyu.github.io/plantuml-previewer/")
    }
    
    func extractInteractable(from name: String) -> String? {
        if name.contains("Interactable") {
            return name.replacingOccurrences(of: "Interactable", with: "")
        } else {
            return nil
        }
    }
    
    func extractListener(from name: String) -> String? {
        if name.contains("Listener") {
            return name.replacingOccurrences(of: "Listener", with: "")
        } else {
            return nil
        }
    }
    
    func extractViewController(from edges: [Edge]) -> Set<String> {
        let results = edges.compactMap { edge -> String? in
            if edge.leftName.contains("ViewController") {
                return edge.leftName.replacingOccurrences(of: "ViewController", with: "")
            } else {
                return nil
            }
        }
        return Set<String>(results)
    }
}
