//
//  UTType+Extension.swift
//  HuggingChat-Mac
//
//  Created by Cyril Zakka on 8/26/24.
//

import UniformTypeIdentifiers

extension UTType {
    static var mlpackage: UTType {
        UTType(filenameExtension: "mlpackage", conformingTo: .item) ?? .item
    }
    static var mlmodelc: UTType {
        UTType(filenameExtension: "mlmodelc", conformingTo: .item) ?? .item
    }
    static var gguf: UTType {
        UTType(filenameExtension: "gguf", conformingTo: .data) ?? .data
    }
}


