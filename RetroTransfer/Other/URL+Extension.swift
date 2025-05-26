//
//  URL+Extension.swift
//  RetroTransfer
//
//  Created by pc on 2025/5/23.
//

import Foundation

// URL扩展，用于获取相对路径
extension URL {
    func relativePath(from base: URL) -> String {
        let basePath = base.path
        let path = self.path
        
        if path.hasPrefix(basePath) {
            let relativePath = String(path.dropFirst(basePath.count))
            return relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
        }
        
        return path
    }
}
