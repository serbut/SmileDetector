//
//  AVCaptureVideoOrientation+DeviceOrientation.swift
//  SmileDetector
//
//  Created by Sergey Butorin on 21/02/2018.
//  Copyright © 2018 Sergey Butorin. All rights reserved.
//

import UIKit
import AVFoundation

extension AVCaptureVideoOrientation {
    init(deviceOrientantion: UIDeviceOrientation) {
        switch deviceOrientantion {
        case .landscapeRight:
            self = .landscapeLeft
        case .landscapeLeft:
            self = .landscapeRight
        case .portrait:
            self = .portrait
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        default:
            self = .portrait
        }
    }
}
