//
//  Item.swift
//  hamrahIOS
//
//  Created by Mike Hamrah on 8/10/25.
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
