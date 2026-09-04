//
//  BlockingLine.swift
//  EdukARt-Rebuild
//

import Foundation


struct BlockingLine:
    Codable,
    Identifiable,
    Equatable {

    let id:
        UUID

    var points:
        [BlockingLinePoint]


    init(
        id: UUID = UUID(),
        points: [BlockingLinePoint]
    ) {

        self.id =
            id

        self.points =
            points
    }
}


struct BlockingLinePoint:
    Codable,
    Equatable {

    var x:
        Float

    var z:
        Float
}
