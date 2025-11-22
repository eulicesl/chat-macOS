//
//  DeviceType.swift
//  HuggingChat-iOS
//
//  Utility for detecting device type
//

import SwiftUI

enum DeviceType {
    case iPhone
    case iPad

    static var current: DeviceType {
        UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
    }
}

extension View {
    @ViewBuilder
    func adaptiveLayout<iPhone: View, iPad: View>(
        @ViewBuilder iPhone: () -> iPhone,
        @ViewBuilder iPad: () -> iPad
    ) -> some View {
        if DeviceType.current == .iPad {
            iPad()
        } else {
            iPhone()
        }
    }
}
