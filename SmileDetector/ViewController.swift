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
    @IBOutlet weak var smilingTimeLabel: UILabel!
    
    // MARK: - Properties
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
                DispatchQueue.main.async {
                    self.smilingTimeLabel.text = "has smile: \(faceFeature.hasSmile)"
                }
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
