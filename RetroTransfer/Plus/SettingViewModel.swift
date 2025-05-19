//
//  SettingViewModel.swift
//  RetroTransfer
//
//  Created by pc on 2025/5/19.
//

import Foundation
import SwiftUI

class SettingViewModel: ObservableObject {
    @AppStorage("RetroTransfer.Setting.Port") var port: String = "8080"
}
