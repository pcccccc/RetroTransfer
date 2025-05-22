//
//  HttpServerManager.swift
//  HttpServer
//
//  Created by pc on 2025/5/14.
//

import Foundation
import Network
import Combine
import ActivityKit


class HttpServerManager: ObservableObject {
    @Published var isRunning = false
    @Published var selectedFolder: URL?
    @Published var settingViewModel = SettingViewModel()
    
    private var listener: NWListener?
    private let connectionQueue = DispatchQueue(label: "com.httpserver.connection", qos: .userInitiated, attributes: .concurrent)
    private let fileQueue = DispatchQueue(label: "com.httpserver.file", qos: .utility, attributes: .concurrent)
    // CHANGE: 使用NSMapTable替代Set，因为NWConnection不符合Hashable协议
    private var activeConnections = NSMapTable<NSString, AnyObject>.strongToWeakObjects()
    private let activeConnectionsQueue = DispatchQueue(label: "com.httpserver.connections.sync")
    var receiveData = Data()
    
    
    func start() {
        guard !isRunning else { return }
        
        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: UInt16(settingViewModel.port) ?? 0)!)
            
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    DispatchQueue.main.async {
                        self?.isRunning = true
                        self?.startLiveActivity()
                    }
                    print("HTTP服务器运行在端口 \(self?.settingViewModel.port ?? "8080")")
                case .failed(let error):
                    print("HTTP服务器错误: \(error)")
                    self?.stop()
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: connectionQueue)
        } catch {
            print("创建HTTP服务器失败: \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        
        // 关闭所有活动连接
        activeConnectionsQueue.sync {
            for key in activeConnections.keyEnumerator() {
                if let connectionKey = key as? NSString,
                   let connection = activeConnections.object(forKey: connectionKey) as? NWConnection {
                    connection.cancel()
                }
            }
            activeConnections = NSMapTable<NSString, AnyObject>.strongToWeakObjects()
        }
        
        DispatchQueue.main.async {
            self.isRunning = false
        }
        Task {
            await self.stopLiveActivity()
        }
        print("HTTP服务器已停止")
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
                    print("启动活动失败: \(error.localizedDescription)")
                }
            }
        } else {
            // Fallback on earlier versions
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

    
    private func handleConnection(_ connection: NWConnection) {
        // 添加到活动连接集合
        let connectionId = UUID().uuidString
        if let existingConnection = activeConnections.object(forKey: connectionId as NSString) as? NWConnection {
            print("重复的连接ID: \(connectionId)")
        }else {
            activeConnectionsQueue.sync {
                activeConnections.setObject(connection, forKey: connectionId as NSString)
            }
        }
        
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            
            switch state {
            case .ready:
                self.receiveRequest(connection, connectionId: connectionId)
                print("连接就绪: \(connectionId)")
            case .failed(let error):
                print("连接失败: \(error)")
                self.removeConnection(connectionId)
            case .waiting(let error):
                print("连接等待: \(error)")
            case .cancelled:
                print("连接已取消")
                self.removeConnection(connectionId)
            default:
                break
            }
        }
        
        connection.start(queue: connectionQueue)
    }
    
    private func removeConnection(_ connectionId: String) {
        activeConnectionsQueue.sync {
            activeConnections.removeObject(forKey: connectionId as NSString)
        }
    }
    
    private func receiveRequest(_ connection: NWConnection, connectionId: String) {
        
        connection.receiveDiscontiguous(minimumIncompleteLength: 0, maximumLength: 100000000) { [weak self] data, contentContext, isComplete, error in
            print("收到data")
            print(contentContext?.identifier)
            print(contentContext?.isFinal)
            print(data?.count)
            print(isComplete)
            if let error = error {
                print("接收数据错误: \(error)")
                // 处理错误情况，例如重新连接或清理资源
                self?.handleConnectionError(connection: connection, connectionId: connectionId, error: error)
                return
            }
            
            guard let self = self,
                  let dispatchData = data else {
                if error == nil {
                    self?.receiveRequest(connection, connectionId: connectionId)
                }
                return
            }
            
            // 将DispatchData转换为Data
            let dataObj = Data(dispatchData)
            
            // 检查是否为POST请求，不依赖于整个请求能否被解码为UTF-8
            // 只尝试解析请求头部，而不是整个请求
            let headerEndData = "\r\n\r\n".data(using: .utf8)!
            
            if let headerEndRange = dataObj.range(of: headerEndData) {
                let headerData = dataObj.subdata(in: 0..<headerEndRange.upperBound)
                
                if let headerString = String(data: headerData, encoding: .utf8) {
                    let firstLine = headerString.components(separatedBy: "\r\n").first ?? ""
                    
                    if firstLine.hasPrefix("POST") {
                        // 文件上传请求
                        self.handleFileUpload(connection, requestData: dataObj, connectionId: connectionId)
                        return
                    } else if firstLine.hasPrefix("GET") {
                        // 解析GET请求的路径
                        let components = firstLine.components(separatedBy: " ")
                        if components.count >= 2 {
                            let path = components[1]
                            self.fileQueue.async {
                                self.sendResponse(for: path, to: connection, connectionId: connectionId)
                            }
                            return
                        }
                    }
                }
            }
            
            // 默认发送首页
            self.fileQueue.async {
                self.sendResponse(for: "/", to: connection, connectionId: connectionId)
            }
        }
    }
    
    private func sendResponse(for path: String, to connection: NWConnection, connectionId: String) {
        guard let selectedFolder = selectedFolder else {
            sendErrorResponse(to: connection, statusCode: 500, message: String(localized: "No shared folder selected"))
            return
        }
        
        var relativePath = path
        if relativePath.hasPrefix("/") {
            relativePath.removeFirst()
        }
        
        if relativePath.isEmpty || relativePath == "/" {
            sendDirectoryListing(for: selectedFolder, to: connection)
            return
        }
        
        // 解码URL编码的路径
        let decodedPath = relativePath.removingPercentEncoding ?? relativePath
        let fileURL = selectedFolder.appendingPathComponent(decodedPath)
        
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                sendDirectoryListing(for: fileURL, to: connection)
            } else {
                sendFile(at: fileURL, to: connection, connectionId: connectionId)
            }
        } else {
            sendErrorResponse(to: connection, statusCode: 404, message: String(localized: "File not found"))
        }
    }
    
    private func sendDirectoryListing(for directoryURL: URL, to connection: NWConnection) {
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            
            var html = "<html><head><meta charset=\"utf-8\"><title>Directory Listing</title></head><body>"
            html += "<h1>\(String(format: String(localized: "Directory: %@"), directoryURL.lastPathComponent))</h1><ul>"
            
            // 添加上传表单
            html += "<form enctype=\"multipart/form-data\" method=\"post\" action=\"/upload\">"
            html += "<input type=\"file\" name=\"file\">"
            html += "<button type=\"submit\">\("Upload")</button>"
            html += "</form>"
            
            // 添加上级目录链接（如果不是根目录）
            if directoryURL.path != selectedFolder?.path {
                let parentPath = directoryURL.deletingLastPathComponent().relativePath(from: selectedFolder!)
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
                
                let relativePath = url.relativePath(from: selectedFolder!)
                let displayName = url.lastPathComponent + (isDir.boolValue ? "/" : "")
                
                html += "<li><a href=\"/\(relativePath)\">\(displayName)</a></li>"
            }
            
            html += "</ul></body></html>"
            
            let contentBytes = html.data(using: .utf8)!
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(contentBytes.count)\r\nCache-Control:no-cache\r\n\r\n\(html)"
            
            // 一次性发送完整响应
            connection.send(content: response.data(using: .utf8)!, completion: .idempotent)
        } catch {
            sendErrorResponse(to: connection, statusCode: 500, message: String(localized: "Reading directory failed"))
        }
    }
    
    private func sendFile(at fileURL: URL, to connection: NWConnection, connectionId: String) {
        do {
            // 检查文件大小
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard let fileSize = fileAttributes[.size] as? NSNumber else {
                throw NSError(domain: "HttpServerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法获取文件大小"])
            }
            
            let mimeType = getMimeType(for: fileURL)
            
            // 发送头部
            var header = "HTTP/1.0 200 OK\r\n"
            header += "Content-Type: \(mimeType)\r\n"
            header += "Content-Length: \(fileSize.intValue)\r\n"
            header += "Accept-Ranges: bytes\r\n"
            header += "Connection: close\r\n"
            header += "\r\n"
            
            let headerData = header.data(using: .utf8)!
            connection.send(content: headerData, completion: .contentProcessed { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    print("发送文件头部失败: \(error)")
                    connection.cancel()
                    self.removeConnection(connectionId)
                    return
                }
                
                if fileSize.int64Value < 1024 * 1024 {
                    do {
                        let fileData = try Data(contentsOf: fileURL)
                        connection.send(content: fileData, completion: .idempotent)
                    } catch {
                        connection.cancel()
                        self.removeConnection(connectionId)
                    }
                    return
                }
                
                // 打开文件进行读取
                if let fileHandle = try? FileHandle(forReadingFrom: fileURL) {
                    // 分块读取并发送文件
                    self.sendFileChunked(fileHandle: fileHandle, connection: connection, connectionId: connectionId, offset: 0, totalSize: fileSize.int64Value)
                } else {
                    connection.cancel()
                    self.removeConnection(connectionId)
                }
            })
            
        } catch {
            sendErrorResponse(to: connection, statusCode: 500, message: "文件处理失败")
        }
    }
    
    // 分块发送文件
    private func sendFileChunked(fileHandle: FileHandle, connection: NWConnection, connectionId: String, offset: Int64, totalSize: Int64) {
        let chunkSize = 65536 // 64KB块大小，增加传输效率
        
        // 设置文件偏移
        fileHandle.seek(toFileOffset: UInt64(offset))
        
        // 读取一块数据
        let data = fileHandle.readData(ofLength: chunkSize)
        
        // 检查是否读取到数据
        if data.count > 0 {
            // 发送数据块
            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                guard let self = self else {
                    fileHandle.closeFile()
                    return
                }
                
                if let error = error {
                    fileHandle.closeFile()
                    connection.cancel()
                    self.removeConnection(connectionId)
                    return
                }
                
                let newOffset = offset + Int64(data.count)
                
                // 检查是否还有更多数据要发送
                if newOffset < totalSize {
                    // 递归发送下一块，但在后台队列中执行，避免堆栈溢出
                    self.fileQueue.async {
                        self.sendFileChunked(fileHandle: fileHandle, connection: connection, connectionId: connectionId, offset: newOffset, totalSize: totalSize)
                    }
                } else {
                    // 完成发送
                    fileHandle.closeFile()
                }
            })
        } else {
            // 结束发送
            fileHandle.closeFile()
        }
    }
    
    
    // 处理上传的文件
    private func handleFileUpload(_ connection: NWConnection, requestData: Data, connectionId: String) {
        fileQueue.async {
            do {
                let headerEndData = "\r\n\r\n".data(using: .utf8)!
                        
                if let headerEndRange = requestData.range(of: headerEndData) {
                    let headerData = requestData.subdata(in: 0..<headerEndRange.upperBound)
                    let requestString = String(data: headerData, encoding: .utf8) ?? ""
                    
                    // 获取Content-Length
                    var contentLength: Int = 0
                    if let contentLengthLine = requestString.components(separatedBy: "\r\n").first(where: { $0.lowercased().hasPrefix("content-length:") }) {
                        let lengthString = contentLengthLine.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                        contentLength = Int(lengthString) ?? 0
                        print("上传文件大小: \(contentLength) 字节")
                    }
                                
                    
                    // 解析请求中的路径参数
                    let uploadPath = ""
                    guard let selectedFolder = self.selectedFolder else {
                        self.sendErrorResponse(to: connection, statusCode: 500, message: String(localized: "No shared folder selected"))
                        return
                    }
                    
                    // 确定上传目标目录
                    var targetDirectory = selectedFolder
                    if !uploadPath.isEmpty {
                        targetDirectory = selectedFolder.appendingPathComponent(uploadPath)
                    }
                    
                    // 解析multipart表单数据
                    if let boundaryLine = requestString.components(separatedBy: "\r\n").first(where: { $0.hasPrefix("Content-Type: multipart/form-data; boundary=") }) {
                        let boundaryStart = boundaryLine.firstIndex(of: "=")!
                        let boundaryString = "--" + String(boundaryLine[boundaryLine.index(after: boundaryStart)...])
                        
                        // 分割multipart数据
                        let parts = requestData.split(separator: boundaryString.data(using: .utf8)!)
                        
                        for part in parts where part.count > 0 {
                            // 尝试查找Content-Disposition头，它包含filename
                            let cdPattern = "Content-Disposition:".data(using: .ascii)!
                            if let cdRange = part.range(of: cdPattern) {
                                let filenamePattern = "filename=\"".data(using: .ascii)!
                                let quotePattern = "\"".data(using: .ascii)!
                                let headerPart = part.subdata(in: cdRange.lowerBound..<min(cdRange.lowerBound+200, part.count))
                                if let filenameRange = headerPart.range(of: filenamePattern),
                                   let endQuoteRange = headerPart.range(of: quotePattern, options: [], in: filenameRange.upperBound..<headerPart.endIndex) {
                                    
                                    // 提取文件名
                                    let filenameData = headerPart.subdata(in: filenameRange.upperBound..<endQuoteRange.lowerBound)
                                    // 尝试将文件名部分解码为UTF-8
                                    let filename = String(data: filenameData, encoding: .utf8) ?? "unknownfile"
                                    
                                    // 查找头部结束标记
                                    if let headerEnd = part.range(of: headerEndData) {
                                        let fileDataStart = headerEnd.upperBound
                                        // 文件数据结束于part的末尾减去结束符
                                        var fileData = part.suffix(from: fileDataStart)
                                        // 移除末尾的CR+LF（如果存在）
                                        if fileData.count > 2 && fileData.suffix(2) == "\r\n".data(using: .utf8)! {
                                            fileData = fileData.dropLast(2)
                                        }
                                        self.receiveData.append(fileData)
                                        if contentLength == requestData.count {
                                            // 将文件保存到目标目录
                                            let fileURL = targetDirectory.appendingPathComponent(filename)
                                            try self.receiveData.write(to: fileURL)
                                            print("File uploaded successfully at \(fileURL.path)")
                                            self.receiveData = Data()
                                            // 发送上传成功响应
                                            let redirectPath = uploadPath.isEmpty ? "/" : "/\(uploadPath)"
                                            let html = "<html><head><meta http-equiv=\"refresh\" content=\"1;url=\(redirectPath)\"></head><body><h1>\(String(localized: "Upload Successful"))</h1><p>\(String(localized: "Redirecting..."))</p></body></html>"
                                            let response = "HTTP/1.0 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\n\r\n\(html)"
                                            connection.send(content: response.data(using: .utf8)!, completion: .idempotent)
                                        }else {
                                            // 发送一个 100 Continue 响应，告诉客户端继续发送
                                            
                                            var response = "HTTP/1.1 100 Continue\r\n"
                                            response += "Content-Type: text\r\n"
                                            response += "\r\n" // 头部结束
                                            let headerBytes = response.data(using: .utf8)!
                                            var completeResponse = Data()
                                            completeResponse.append(headerBytes)
                                            
                                            connection.send(content: completeResponse, completion: .idempotent)
                                        }
                                        return
                                    }
                                }
                            } else if let partString = String(data: part, encoding: .utf8) {
                                print("处理multipart表单数据: \(partString)")
                            }
                        }
                    }
                }
                
                // 如果处理失败，发送错误响应
                self.sendErrorResponse(to: connection, statusCode: 400, message: String(localized: "Upload failed"))
            } catch {
                self.sendErrorResponse(to: connection, statusCode: 500, message: String(localized: "File processing failed"))
            }
        }
    }
    
    // 处理连接错误
    private func handleConnectionError(connection: NWConnection, connectionId: String, error: Error) {
        print("连接 \(connectionId) 发生错误: \(error)")
    }
    
    private func sendErrorResponse(to connection: NWConnection, statusCode: Int, message: String) {
        // 极简HTML，确保兼容性
        let html = "<html><head><meta charset=\"UTF-8\"><title>\(String(format: String(localized: "Error %d"), statusCode))</title></head><body><h1>\(String(format: String(localized: "Error %d"), statusCode))</h1><p>\(message)</p></body></html>"
        
        let contentBytes = html.data(using: .utf8)!
        
        var response = "HTTP/1.0 \(statusCode) Error\r\n"
        response += "Content-Type: text/html; charset=utf-8\r\n"
        response += "Content-Length: \(contentBytes.count)\r\n"
        response += "\r\n" // 头部结束
        
        let headerBytes = response.data(using: .utf8)!
        var completeResponse = Data()
        completeResponse.append(headerBytes)
        completeResponse.append(contentBytes)
        
        connection.send(content: completeResponse, completion: .idempotent)
    }
    
    private func getMimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "html", "htm": return "text/html"
        case "css": return "text/css"
        case "js": return "text/javascript"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "pdf": return "application/pdf"
        case "mp3": return "audio/mpeg"
        case "mp4": return "video/mp4"
        case "json": return "application/json"
        case "xml": return "application/xml"
        case "txt": return "text/plain"
        case "jar": return "application/java-archive"
        case "sisx", "sis": return "application/vnd.symbian.install"
        case "zip": return "application/zip"
        case "rar": return "application/x-rar-compressed"
        case "exe": return "application/octet-stream"
        default: return "application/octet-stream"
        }
    }
}

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
