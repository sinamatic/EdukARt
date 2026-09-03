//
//  RuntimeEgg.swift
//  EdukARt-Rebuild
//
//  Describes the runtime state of one collected egg.
//

import Foundation


struct RuntimeEgg:
    Identifiable,
    Equatable {

    enum State:
        Equatable {

        /// Egg currently lies on Eduard.
        case carried(
            slot: Int
        )

        /// Egg has successfully been delivered to Egg Cup.
        case delivered(
            slot: Int
        )
    }


    /// Uses the UUID of the original PlacedMapObject.
    let id:
        UUID


    var state:
        State
}
