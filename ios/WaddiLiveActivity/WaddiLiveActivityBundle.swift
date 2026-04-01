//
//  WaddiLiveActivityBundle.swift
//  WaddiLiveActivity
//
//  Created by Hamdies Macbook on 22/03/2026.
//

import WidgetKit
import SwiftUI

@main
struct WaddiLiveActivityBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        if #available(iOS 16.2, *) {
            WaddiLiveActivityLiveActivity()
        }
    }
}
