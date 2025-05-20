//
//  ServerLiveActivity.swift
//  RetroTransfer
//
//  Created by pc on 2025/5/20.
//

import Foundation
import ActivityKit
import SwiftUI

public struct ServerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var ipAddress: String
        var port: String
        var folderName: String
    }
    
    var serverName: String
}
