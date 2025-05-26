//
//  SyncSocketManager.swift
//  RetroTransfer
//
//  Created by pc on 2025/5/21.
//

import MacroExpress // @Macro-swift
import Foundation
import ActivityKit


class ServerManager: ObservableObject {
    
    let app = Express()
    @Published var selectedFolder: URL?
    @Published var settingViewModel = SettingViewModel()

    func start(for directoryURL: URL) {
        
        guard let selectedFolder = selectedFolder else { return }
        
        app.get { req, res in
            
            var relativePath = req.url
            if relativePath.hasPrefix("/") {
                relativePath.removeFirst()
            }
            
            if relativePath.isEmpty || relativePath == "/" {
                res.setHeader("Content-Type", "text/html")
                res.send(self.sendDiretory(directoryURL: self.selectedFolder!))
                return
            }
            
            // 解码URL编码的路径
            let decodedPath = relativePath.removingPercentEncoding ?? relativePath
            let fileURL = selectedFolder.appendingPathComponent(decodedPath)
            
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    res.setHeader("Content-Type", "text/html")
                    res.send(self.sendDiretory(directoryURL: fileURL))
                } else {
                    let fileData = try Data(contentsOf: fileURL)
                    res.setHeader("Content-Type", Common.getMimeType(for: fileURL))
                    res.setHeader("Content-Length", fileData.count)
                    res.write(fileData)
                }
            } else {
                
            }
            res.setHeader("Content-Type", "text/html")
            res.send(self.sendDiretory(directoryURL: directoryURL))
        }
        
        app.post("/upload", multer().array("file", 10)) { req, res, _ in
            req.log.info("Got files:", req.files["file"])
            let dir = req.url.replacingOccurrences(of: "/upload?path=", with: "")
            var uploadSuccessFileNames: [String] = []
            if let files = req.files["file"] {
                for file in files {
                    var destinationURL = selectedFolder
                    if dir != "" {
                        destinationURL = selectedFolder.appendingPathComponent(dir)
                    }
                    destinationURL = destinationURL.appendingPathComponent(file.originalName)
                    
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        let fileExtension = file.originalName.contains(".") ? ".\(file.originalName.components(separatedBy: ".").last!)" : ""
                        let fileNameWithoutExtension = fileExtension.isEmpty ? file.originalName : file.originalName.replacingOccurrences(of: fileExtension, with: "")
                        
                        var counter = 1
                        var newName = "\(fileNameWithoutExtension)-\(counter)\(fileExtension)"
                        var newDestinationURL = destinationURL.deletingLastPathComponent().appendingPathComponent(newName)
                        
                        while FileManager.default.fileExists(atPath: newDestinationURL.path) {
                            counter += 1
                            newName = "\(fileNameWithoutExtension)-\(counter)\(fileExtension)"
                            newDestinationURL = destinationURL.deletingLastPathComponent().appendingPathComponent(newName)
                        }
                        
                        destinationURL = newDestinationURL
                    }
                    
                    if let buffer = file.buffer {
                        let data = Data(buffer: buffer.byteBuffer)
                        do {
                            try data.write(to: destinationURL)
                            uploadSuccessFileNames.append(file.originalName)
                        } catch {
                            
                        }
                    }
                }
            }
            let fileNames = uploadSuccessFileNames.joined(separator: "<br>")
            let html = """
            <html>
                <head>
                <meta http-equiv="refresh" content="1;url=\(dir == "" ? "/" : "\(dir)")">
                <meta charset="utf-8">
                </head>
                <body>
                    <h1>\(String(localized: "Upload Successful"))</h1>
                    <br>
                    <p>\("\(fileNames)")</p>
                    <p>\(String(localized: "Redirecting..."))</p>
                </body>
            </html>
            """
            res.setHeader("Content-Type", "text/html")
            res.send(html)
        }
        
        app.listen(Int(settingViewModel.port) ?? 8080, Common.getWiFiIPAddress() ?? "0.0.0.0") { [weak self] in
            self?.startLiveActivity()
        }
    }
    
    func stop() {
        //TODO
//        app.close()
    }
    
    func sendDiretory(directoryURL: URL) -> String {
        
        guard let selectedFolder = selectedFolder else {
            return ""
        }
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            let path = directoryURL.path.replacingOccurrences(of: selectedFolder.path, with: "")
            var html = """
                        <html><head><meta charset=\"utf-8\"><title>Directory Listing</title></head><body>
                        <h1>\(String(format: String(localized: "Directory: %@"), path))</h1><ul>
                        <form enctype="multipart/form-data" method="post" action="/upload?path=\(path)">
                        <input type="file" name="file">
                        <input type="submit" value="Upload" />
                        </form>
                """
            
            // 添加上级目录链接（如果不是根目录）
            if directoryURL.path != selectedFolder.path {
                let parentPath = directoryURL.deletingLastPathComponent().relativePath(from: selectedFolder)
                html += "<li><a href=\"/\(parentPath)\">../</a></li>"
            }
            
            // 按名称排序并先显示目录
            let sortedContents = contents.sorted { (url1, url2) -> Bool in
                var isDir1: ObjCBool = false
                var isDir2: ObjCBool = false
                FileManager.default.fileExists(atPath: url1.path, isDirectory: &isDir1)
                FileManager.default.fileExists(atPath: url2.path, isDirectory: &isDir2)
                
                if isDir1.boolValue != isDir2.boolValue {
                    return isDir1.boolValue
                }
                return url1.lastPathComponent < url2.lastPathComponent
            }
            
            for url in sortedContents {
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                
                let relativePath = url.relativePath(from: selectedFolder)
                let displayName = url.lastPathComponent + (isDir.boolValue ? "/" : "")
                
                html += "<li><a href=\"/\(relativePath)\">\(displayName)</a></li>"
            }
            
            html += "</ul></body></html>"
            
            return html
        }catch {
            print(error)
            return ""
        }
    }
    
    private func startLiveActivity() {
        if #available(iOS 16.1, *) {
            if ActivityAuthorizationInfo().areActivitiesEnabled {
                let ipAddress = Common.getWiFiIPAddress() ?? "localhost"
                let port = settingViewModel.port
                let folderName = selectedFolder?.lastPathComponent ?? "未知文件夹"
                
                let attributes = ServerAttributes(serverName: "RetroTransfer")
                let contentState = ServerAttributes.ContentState(
                    ipAddress: ipAddress,
                    port: port,
                    folderName: folderName
                )
                
                do {
                     let activity = try Activity.request(
                        attributes: attributes,
                        contentState: contentState,
                        pushType: nil
                    )
                    print("Requested a Live Activity \(activity.id)")
                } catch {
                    print("Error requesting Live Activity: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func stopLiveActivity() async {
        if #available(iOS 16.1, *) {
            for activity in Activity<ServerAttributes>.activities{
                await activity.end(dismissalPolicy: .immediate)
            }
        } else {
            // Fallback on earlier versions
        }
    }

}
