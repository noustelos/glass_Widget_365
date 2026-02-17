//
//  OrthodoxyWidgetBundle.swift
//  OrthodoxyWidget
//
//  Created by nikos Karadimas on 15/2/26.
//

import WidgetKit
import SwiftUI

@main
struct OrthodoxyWidgetBundle: WidgetBundle {
    var body: some Widget {
        OrthodoxyWidget()
        OrthodoxyWidgetLiveActivity()
    }
}
