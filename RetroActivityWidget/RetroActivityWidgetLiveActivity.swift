//
//  RetroActivityWidgetLiveActivity.swift
//  RetroActivityWidget
//
//  Created by pc on 2025/5/20.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct RetroActivityWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ServerAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(.black.opacity(0.9))
                .activitySystemActionForegroundColor(.blue)
        } dynamicIsland: { context in
            DynamicIsland {
                
                DynamicIslandExpandedRegion(.center) {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.blue)
                        
                        Text("RetroTransfer \(String(localized: "Running")):")
                            .bold()
                        
                        Spacer()
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Label("\(context.state.ipAddress):\(context.state.port)", systemImage: "network")
                                .font(.callout)
                            Spacer()
                        }
                        
                        HStack {
                            Label(context.state.folderName, systemImage: "folder")
                                .font(.callout)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                    .padding()
                }
            } compactLeading: {
                Image(systemName: "network")
                    .foregroundColor(.blue)
            } compactTrailing: {
                Text(String(localized: "Running"))
                    .font(.caption2)
                    .foregroundColor(.green)
            } minimal: {
                Image(systemName: "network")
                    .foregroundColor(.blue)
            }
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
struct LockScreenLiveActivityView: View {
    var context: ActivityViewContext<ServerAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.blue)
                
                Text("RetroTransfer \(String(localized: "Running")):")
                    .bold()
                
                Spacer()
            }
            
            HStack {
                Label("\(context.state.ipAddress):\(context.state.port)", systemImage: "network")
                    .font(.callout)
                Spacer()
            }
            
            HStack {
                Label(context.state.folderName, systemImage: "folder")
                    .font(.callout)
                    .lineLimit(1)
                Spacer()
            }
        }
        .padding()
    }
}

extension ServerAttributes {
    fileprivate static var preview: ServerAttributes {
        ServerAttributes(serverName: "RetroTransfer")
    }
}

extension ServerAttributes.ContentState {
    fileprivate static var smiley: ServerAttributes.ContentState {
        ServerAttributes.ContentState(ipAddress: "192.168.0.1", port: "8080", folderName: "Documents")
     }
}

#Preview("Notification", as: .content, using: ServerAttributes.preview) {
   RetroActivityWidgetLiveActivity()
} contentStates: {
    ServerAttributes.ContentState.smiley
}
