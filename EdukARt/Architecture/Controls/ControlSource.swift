//
//  ControlSource.swift
//  EdukARt
//

import Foundation

protocol ControlSource: AnyObject {
    func readInput() -> ControlInput
}
