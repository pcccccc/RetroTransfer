//
//  RetroTransferMainView.swift
//  RetroTransfer
//
//  Created by pc on 2025/5/19.
//

import SwiftUI
import ColorfulX

struct RetroTransferMainView: View {
    @StateObject private var serverViewModel = ServerViewModel()
    @State private var isShowingFolderPicker = false
    @State private var showSettings = false
    @State var colors: ColorfulPreset = ColorfulPreset.winter
    @Environment(\.colorScheme) private var colorScheme

    
    private var serverStatus: String {
        let statusText = serverViewModel.isRunning ? String(localized: "Running") : String(localized: "Stopped")
        if let folder = serverViewModel.manager.selectedFolder {
            return "\(statusText) - \(folder.lastPathComponent)"
        } else {
            return statusText
        }
    }
    
    private var serverInfo: String {
        if serverViewModel.isRunning {
            let ipAddresses = Common.getWiFiIPAddress()
            if let mainIP = ipAddresses {
                return "http://\(mainIP):\(serverViewModel.manager.settingViewModel.port)/"
            } else {
                return "http://localhost:\(serverViewModel.manager.settingViewModel.port)/"
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
                   
                if serverViewModel.isRunning {
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
                                        if let folder = serverViewModel.manager.selectedFolder {
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
                                if serverViewModel.isRunning == false {
                                    if serverViewModel.manager.selectedFolder != nil {
                                        serverViewModel.manager.start(for: serverViewModel.manager.selectedFolder!)
                                    } else {
                                        isShowingFolderPicker = true
                                    }
                                }else {
                                    serverViewModel.manager.stop()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: serverViewModel.isRunning ? "stop.fill" : "play.fill")
                                        .foregroundColor(.white)
                                    Text(serverViewModel.isRunning ? "Stop" : "Start")
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
                serverViewModel.manager.selectedFolder = url
                serverViewModel.manager.start(for: url)
                serverViewModel.isRunning = true
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
