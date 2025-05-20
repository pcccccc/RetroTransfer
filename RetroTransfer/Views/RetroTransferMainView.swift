//
//  RetroTransferMainView.swift
//  RetroTransfer
//
//  Created by pc on 2025/5/19.
//

import SwiftUI
import ColorfulX

struct RetroTransferMainView: View {
    @StateObject private var serverManager = HttpServerManager()
    @State private var isShowingFolderPicker = false
    @State private var showSettings = false
    @State var colors: ColorfulPreset = ColorfulPreset.winter
    @Environment(\.colorScheme) private var colorScheme

    
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
            let ipAddresses = Common.getWiFiIPAddress()
            if let mainIP = ipAddresses {
                return "http://\(mainIP):\(serverManager.settingViewModel.port)/"
            } else {
                return "http://localhost:\(serverManager.settingViewModel.port)/"
            }
        } else {
            return String(localized: "Not Started")
        }
    }
    
    var body: some View {
        ColorfulView(color: $colors)
        .onAppear {
            colors = colorScheme == .dark ? ColorfulPreset.ocean : ColorfulPreset.winter
        }
        .onChange(of: colorScheme) { scheme in
            if scheme == .dark {
                colors = .ocean
            } else {
                colors = .winter
            }
        }
        .overlay {
            VStack(spacing: 20) {
                GeometryReader { geometry in
                    VStack(alignment: .leading) {
                        Text("RetroTransfer")
                            .font(.largeTitle)
                            .bold()
                            .padding(.top, geometry.safeAreaInsets.top > 0 ? 20 : 40)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(String(format: String(localized: "Status: %@"), serverStatus))
                                    .font(.headline)
                                Text(serverInfo)
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    .padding()
                }
                   
                if serverManager.isRunning {
                    Text("Server logs will be displayed in the console")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .center, spacing: 15) {
                    GeometryReader { proxy in
                        let width = proxy.size.width / 2 - 20
                        let height = proxy.size.height - 20
                        HStack(spacing: 20) {
                            Button(action: {
                                isShowingFolderPicker = true
                            }) {
                                VStack(spacing: 15) {
                                    Image(systemName: "folder")
                                        .imageScale(.large)
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .center) {
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
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: width, height: height)
                            .background(.thinMaterial)
                            .cornerRadius(12)
                            
                            Button(action: {
                                showSettings = true
                            }) {
                                VStack(spacing: 15) {
                                    Image(systemName: "gear")
                                        .imageScale(.large)
                                        .foregroundColor(.gray)
                                    
                                    Text("Custom Options")
                                        .font(.headline)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: width, height: height)
                            .background(.thinMaterial)
                            .cornerRadius(12)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                    }
                    
                    GeometryReader { proxy in
                        HStack {
                            Spacer()
                            Button {
                                if serverManager.isRunning == false {
                                    if serverManager.selectedFolder != nil {
                                        serverManager.start()
                                    } else {
                                        isShowingFolderPicker = true
                                    }
                                }else {
                                    serverManager.stop()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: serverManager.isRunning ? "stop.fill" : "play.fill")
                                        .foregroundColor(.white)
                                    Text(serverManager.isRunning ? "Stop" : "Start")
                                        .foregroundStyle(.white)
                                        .font(.title3)
                                }
                            }
                            .frame(width: 180, height: 50)
                            .background(Color("startGreen"))
                            .buttonStyle(.plain)
                            .cornerRadius(25)
                            Spacer()
                        }
                        
                    }
                    .frame(height: 70)
                    
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(height: 300)
                .frame(maxWidth: .infinity)
            }
        }
        .ignoresSafeArea()
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
