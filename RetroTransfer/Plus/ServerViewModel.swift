//
//  ServerViewModel.swift
//  RetroTransfer
//
//  Created by pc on 2025/5/21.
//

import Foundation

class ServerViewModel: ObservableObject {
    @Published var manager = ServerManager()
    @Published var isRunning = false
}
