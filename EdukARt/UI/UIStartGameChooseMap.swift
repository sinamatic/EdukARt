//
//  UIStartGameChooseMap.swift
//  EdukARt
//

import SwiftUI

struct UIStartGameChooseMap: View {
    
    @ObservedObject var mapStore: MapStore
    
    let onCreateMap: () -> Void
    let onSelectMap: (GameMap) -> Void
    
    var body: some View {
        ZStack {
            
            Image("EdukARtKeyvisual")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            Color.black.opacity(0.80)
                .ignoresSafeArea()
            
            
            VStack(spacing: 20) {
                
                
                Text("Choose Game Map")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                
                
                Group {
                    if mapStore.maps.isEmpty {
                        Text("No maps saved yet.")
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity
                            )
                    } else {
                        List {
                            ForEach(mapStore.maps) { map in
                                
                                Button {
                                    onSelectMap(map)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        
                                        Text(map.name)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        
                                        Text(
                                            map.createdAt.formatted(
                                                date: .abbreviated,
                                                time: .shortened
                                            )
                                        )
                                        .font(.footnote)
                                        .foregroundStyle(.white.opacity(0.7))
                                    }
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )
                                    .padding(16)
                                    .background(.white.opacity(0.1))
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 8)
                                    )
                                }
                                .buttonStyle(.plain)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions {
                                    Button(
                                        "Delete",
                                        role: .destructive
                                    ) {
                                        delete(map)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
                .frame(maxHeight: .infinity)
                
                
                Button("Create Map") {
                    onCreateMap()
                }
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(UIGlobals.brandGreen)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 120)
        }
    }
    
    
    private func delete(_ map: GameMap) {
        try? mapStore.delete(map)
    }
}
