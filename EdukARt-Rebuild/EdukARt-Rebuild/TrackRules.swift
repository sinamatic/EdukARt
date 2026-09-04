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


    // ======================================================
    // MARK: - Offroad
    // ======================================================

    /// Eduard immediately drops to 50 % speed
    /// after leaving the road.
    static let offRoadInitialSpeedScale:
        Double = 0.50

    /// Additional speed loss per second offroad.
    static let offRoadSpeedLossPerSecond:
        Double = 0.05

    /// Eventually Eduard stops completely.
    static let minimumOffRoadSpeedScale:
        Double = 0.0
}
