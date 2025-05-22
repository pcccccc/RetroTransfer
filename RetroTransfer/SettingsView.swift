//
//  SettingsView.swift
//  RetroTransfer
//
//  Created by pc on 2025/5/19.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var settingViewModel = SettingViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Server Settings")) {
                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("8080", text: $settingViewModel.port)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // 这里可以保存设置
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
