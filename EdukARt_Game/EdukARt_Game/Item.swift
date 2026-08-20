//
//  Item.swift
//  EdukARt_Game
//
//  Created by Sina Steinmüller on 20.08.26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
