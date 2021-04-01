//
//  Sequence+Unique.swift
//  DigiByte
//
//  Created by Julian Jäger on 16.05.20.
//  Copyright © 2020 DigiByte Foundation NZ Limited. All rights reserved.
//

import Foundation

extension Sequence where Iterator.Element: Hashable {
    func unique() -> [Iterator.Element] {
        var seen: Set<Iterator.Element> = []
        return filter { seen.insert($0).inserted }
    }
}
