//
//  ViewController.swift
//  SmileDetector
//
//  Created by Sergey Butorin on 21/02/2018.
//  Copyright © 2018 Sergey Butorin. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var permissionNotGrantedView: UIView!
    @IBOutlet weak var smileTopLabel: UILabel!
    @IBOutlet weak var smilingTimeLabel: UILabel!
    
    // MARK: - Properties
    
    let TIMER_STEP: TimeInterval = 0.01
    var timer = Timer()
    var secondsCounter: TimeInterval = 0
    
    var isSmiling = false {
        didSet {
            switch isSmiling {
            case true:
                if timer.isValid { break }
                DispatchQueue.main.async {
                    self.smileTopLabel.isHidden = true
                    self.timer = Timer.scheduledTimer(timeInterval: self.TIMER_STEP,
                                             target: self,
                                             selector: #selector(self.updateTimer),
                                             userInfo: nil,
                                             repeats: true)
                }
            case false:
                DispatchQueue.main.async {
                    self.smileTopLabel.isHidden = false
                    self.timer.invalidate()
                }
            }
        }
    }
    
    var session = AVCaptureSession()

    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        var layer = AVCaptureVideoPreviewLayer(session: self.session)
        layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        return layer
    }()
    
    let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                    for: AVMediaType.video,
                                                    position: .front)
    
    let faceDetector = CIDetector(ofType: CIDetectorTypeFace,
                                  context: nil,
                                  options: [CIDetectorAccuracy : CIDetectorAccuracyLow])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sessionPrepare()
        session.startRunning()
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: Notification.Name.UIApplicationDidEnterBackground, object: nil)
    }
    
    @objc func appMovedToBackground() {
        timer.invalidate()
        secondsCounter = 0
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        previewLayer?.frame = view.frame
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard let previewLayer = previewLayer else { return }
        view.layer.addSublayer(previewLayer)
        
        view.bringSubview(toFront: smilingTimeLabel) // FIX
        view.bringSubview(toFront: smileTopLabel)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // correct rotation of video layer
        guard let previewLayer = previewLayer else { return }
        let deviceOrientation = UIDevice.current.orientation
        previewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.init(deviceOrientantion: deviceOrientation)
    }
    
    @IBAction func settingsButtonPushed(_ sender: UIButton) {
        // TODO: Go to settings
    }
}

// MARK: - AVCaptureSession setup
extension ViewController {
    
    func sessionPrepare() {
        
        guard let camera = frontCamera else { return }
        
        session.sessionPreset = AVCaptureSession.Preset.photo
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: camera)
            session.beginConfiguration()
            
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            
            output.alwaysDiscardsLateVideoFrames = true
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
            
            let queue = DispatchQueue(label: "output.queue")
            output.setSampleBufferDelegate(self, queue: queue)
            
        } catch {
            print("error with creating AVCaptureDeviceInput")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as! [String : Any]?)
        let options: [String : Any] = [CIDetectorImageOrientation: exifOrientation(orientation: UIDevice.current.orientation),
                       CIDetectorSmile: true]
        let allFeatures = faceDetector?.features(in: ciImage, options: options)
        
        guard let features = allFeatures else { return }
        
        for feature in features {
            if let faceFeature = feature as? CIFaceFeature {
                isSmiling = faceFeature.hasSmile
            }
        }
    }
    
    func exifOrientation(orientation: UIDeviceOrientation) -> Int {
        switch orientation {
        case .portraitUpsideDown:
            return 8
        case .landscapeLeft:
            return 3
        case .landscapeRight:
            return 1
        default:
            return 6
        }
    }
}

// MARK: - Timer
extension ViewController {
    @objc func updateTimer() {
        secondsCounter += TIMER_STEP
        DispatchQueue.main.async {
            self.smilingTimeLabel.text = "Smiling Time: \(self.timeString())"
        }
    }
    
    func timeString() -> String {
        let minutes = Int(secondsCounter) / 60 % 60
        let seconds = Int(secondsCounter) % 60
        let milliseconds = Int(secondsCounter.truncatingRemainder(dividingBy: 1) * 100)
        
        return String(format: "%02i:%02i.%02i", arguments: [minutes, seconds, milliseconds])
    }
}
