//
//  GameScene.swift
//  EdukARt
//

import Foundation

protocol GameScene: AnyObject {
    var level: Level { get set }
    func update()
}
