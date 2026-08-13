//
//  UICreateMap.swift
//  EdukARt
//

import SwiftUI

struct UICreateMap: View {
    
    @StateObject private var detectionSession =
        AprilTagDetectionSession()
    
    var body: some View {
        ZStack {
            
            UIAprilTagCamera(
                detectionSession: detectionSession
            )
            .ignoresSafeArea()
            
            
            VStack {
                
                Spacer()
                
                VStack(spacing: 10) {
                    
                    Text("Scan AprilTags")
                        .font(.headline)
                    
                    
                    if detectionSession.detectedTags.isEmpty {
                        
                        Text("No AprilTags detected")
                        
                    } else {
                        
                        ForEach(detectionSession.detectedTags) { tag in
                            
                            HStack {
                                
                                Text("Tag #\(tag.id)")
                                
                                Spacer()
                                
                                if let distance = tag.distance {
                                    Text(
                                        String(
                                            format: "%.2f m",
                                            distance
                                        )
                                    )
                                }
                            }
                        }
                    }
                }
                .foregroundStyle(.white)
                .padding(20)
                .background(.black.opacity(0.7))
                .clipShape(
                    RoundedRectangle(cornerRadius: 12)
                )
                .padding()
            }
        }
    }
}
