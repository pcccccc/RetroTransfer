
//
//  ContentView.swift
//  HttpServer
//
//  Created by pc on 2025/5/14.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @StateObject private var serverManager = HttpServerManager()
    @State private var isShowingFolderPicker = false
    @State private var showSettings = false
    
    private var serverStatus: String {
        let statusText = serverManager.isRunning ? String(localized: "Running") : String(localized: "Stopped")
        if let folder = serverManager.selectedFolder {
            return "\(statusText) - \(folder.lastPathComponent)"
        } else {
            return statusText
        }
    }
    
    private var serverInfo: String {
        if serverManager.isRunning {
            let ipAddresses = getWiFiIPAddress()
            if let mainIP = ipAddresses {
                return "http://\(mainIP):8080/"
            } else {
                return "http://localhost:8080/"
            }
        } else {
            return String(localized: "Not Started")
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("RetroTransfer")
                    .font(.largeTitle)
                    .bold()
                
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(String(format: String(localized: "Status: %@"), serverStatus))
                            .font(.headline)
                        Text(serverInfo)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { serverManager.isRunning },
                        set: { newValue in
                            if newValue {
                                if serverManager.selectedFolder != nil {
                                    serverManager.start()
                                } else {
                                    isShowingFolderPicker = true
                                }
                            } else {
                                serverManager.stop()
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                }
                .padding(.vertical, 10)
                
                Divider()
            }
            
            VStack(alignment: .leading, spacing: 15) {
                Button(action: {
                    isShowingFolderPicker = true
                }) {
                    HStack {
                        Image(systemName: "folder")
                            .imageScale(.large)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Shared Folder")
                                .font(.headline)
                            if let folder = serverManager.selectedFolder {
                                Text(folder.path)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            } else {
                                Text("None")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                
                HStack {
                    HStack {
                        Image(systemName: "list.bullet")
                            .imageScale(.large)
                            .foregroundColor(.green)
                        
                        Text("Directory Listing")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $serverManager.showDirectoryListing)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                }
                
                Divider()
                
                Button(action: {
                    showSettings = true
                }) {
                    HStack {
                        Image(systemName: "gear")
                            .imageScale(.large)
                            .foregroundColor(.gray)
                        
                        Text("Custom Options")
                            .font(.headline)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Spacer()
            
            if serverManager.isRunning {
                Text("Server logs will be displayed in the console")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .sheet(isPresented: $isShowingFolderPicker) {
            FolderPickerView { url in
                serverManager.selectedFolder = url
                if serverManager.isRunning {
                    serverManager.stop()
                    serverManager.start()
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
    
    private func getWiFiIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee

            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {

                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)

        return address
    }
}

struct FolderPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    let onSelect: (URL) -> Void
    
    var body: some View {
        DocumentPicker(onSelect: onSelect, onDismiss: {
            presentationMode.wrappedValue.dismiss()
        })
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onSelect: (URL) -> Void
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {

    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                let success = url.startAccessingSecurityScopedResource()
                if success {
                    parent.onSelect(url)
                }
            }
            parent.onDismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onDismiss()
        }
    }
}

#Preview {
    ContentView()
}
