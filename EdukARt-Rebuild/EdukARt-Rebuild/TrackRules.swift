//
//  TrackRules.swift
//  EdukARt-Rebuild
//
//  Shared physical gameplay values for the race track.
//

import Foundation


enum TrackRules {

    // ======================================================
    // MARK: - Road
    // ======================================================

    /// Complete physical road width.
    static let roadWidth:
        Float = 0.60

    static var roadHalfWidth:
        Float {

        roadWidth / 2
    }

}
