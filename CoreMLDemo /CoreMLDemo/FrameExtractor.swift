//
//  FrameExtractor.swift
//  CoreMLDemo
//
//  Created by Wesley St. John on 12/1/17.
//  Copyright © 2017 mobileforming. All rights reserved.
//  Modified from https://medium.com/ios-os-x-development/ios-camera-frames-extraction-d2c0f80ed05a
//

import UIKit
import AVFoundation

protocol FrameExtractorDelegate: class {
    func captured(image: UIImage)
}

class FrameExtractor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private let position: AVCaptureDevice.Position
    private let quality: AVCaptureSession.Preset
    
    private var permissionGranted = false
    private let sessionQueue = DispatchQueue(label: "cameraSessionQueue")
    private let captureSession = AVCaptureSession()
    private let context = CIContext()
    
    weak var delegate: FrameExtractorDelegate?
    
    init(position: AVCaptureDevice.Position, quality: AVCaptureSession.Preset) {
        self.position = position
        self.quality = quality
        super.init()
        checkPermission()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureSessionRuntimeError, object: nil, queue: nil) { (notification) in
            print(notification.debugDescription)
        }
        
        sessionQueue.async { [weak self] in
            guard let sself = self else { return }
            sself.configureSession()
            sself.captureSession.startRunning()
        }
    }
    
    // MARK: AVSession configuration
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
        }
    }
    
    private func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [weak self] granted in
            guard let sself = self else { return }
            sself.permissionGranted = granted
            sself.sessionQueue.resume()
        }
    }
    
    private func configureSession() {
        guard permissionGranted == true,
            let captureDevice = selectCaptureDevice(),
            let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice),
            captureSession.canAddInput(captureDeviceInput) else {
                return
        }
        
        captureSession.sessionPreset = quality
        captureSession.addInput(captureDeviceInput)
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        guard captureSession.canAddOutput(videoOutput) else { return }
        
        captureSession.addOutput(videoOutput)
        
        guard let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video),
            connection.isVideoOrientationSupported,
            connection.isVideoMirroringSupported else {
                return
        }
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = position == .front
    }
    
    private func selectCaptureDevice() -> AVCaptureDevice? {
        return AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: position).devices.first
    }
    
    // MARK: Sample buffer to UIImage conversion
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let uiImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let sself = self else { return }
            sself.delegate?.captured(image: uiImage)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
    }
}
