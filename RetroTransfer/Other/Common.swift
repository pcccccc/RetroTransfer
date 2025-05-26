//
//  Common.swift
//  RetroTransfer
//
//  Created by pc on 2025/5/20.
//

import Foundation

struct Common {
    static func getWiFiIPAddress() -> String? {
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
    
    static func getMimeType(for url: URL) -> String {
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
