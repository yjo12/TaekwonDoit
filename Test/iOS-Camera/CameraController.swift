//
//  CameraController.swift
//  test-camera-function
//
//  Created by Yoonjo Kim on 2019/11/11.
//  Copyright © 2019 Yoonjo Kim. All rights reserved.
//

import Foundation
import AVFoundation

import UIKit // displayPreview 함수를 위해

class CameraController {
    // createCaptureSession함수를 위해
    var captureSession: AVCaptureSession? // AVCaptureSession을 상속받은 captureSession을 선언
    
    // configureCaptureDevices함수를 위해
    var frontCamera: AVCaptureDevice? // AVCaptureDevice를 상속받은 frontCamera를 선언
    var rearCamera: AVCaptureDevice? // AVCaptureDevice를 상속받은 rearCamera를 선언
    
    // configureDeviceInputs 함수를 위해
    var currentCameraPosition: CameraPosition?
    var frontCameraInput: AVCaptureDeviceInput?
    var rearCameraInput: AVCaptureDeviceInput?
    
    // configurePhotoOutput 함수를 위해
    var photoOutput: AVCapturePhotoOutput?
    
    //func prepare(completionHandler: @escaping (Error?)) -> Void {
    func prepare(completionHandler: @escaping (Error?) -> Void) {
        func createCaptureSession() {
            // 1. 캡처 세션을 생성하고
            self.captureSession = AVCaptureSession() // AVCaptureSession 생성, captureSession에 저장
        }
        func configureCaptureDevices() throws {
            // 2. 필요한 캡처 기기를 얻고, 구성하고
            // 가능한 카메라 기기 찾기-1
            // 가능한 모든 wide angle camera를 찾고, non-optional AVCaptureDevice 인스턴스인 cameras로 변환한다.
            let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
            //guard let cameras = (session.devices.compactMap {$0}), !cameras.isEmpty else {throw CameraControllerError.noCameraAvailable}
            let cameras = session.devices.compactMap { $0 }
            guard !cameras.isEmpty else {throw CameraControllerError.noCameraAvailable}
            
            // 가능한 카메라 기기 찾기-2
            // 가능한 카메라들 중 어떤 카메라를 사용할지 정한다.
            for camera in cameras {
                if camera.position == .front {
                    self.frontCamera = camera
                }
                if camera.position == .back {
                    self.rearCamera = camera
                    
                    // 오토포커스
                    try camera.lockForConfiguration()
                    camera.focusMode = .continuousAutoFocus
                    camera.unlockForConfiguration()
                }
            }
        }
        func configureDeviceInputs() throws {
            // 3. 캡처 기기를 통해 input을 생성하고
            // storing and managing our capture deivce inputs
            guard let captureSession = self.captureSession else {
                throw CameraControllerError.captureSessionIsMissing
            } // captureSession이 존재하니?
            
            // creating capture device input to support photo capture
            if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                if captureSession.canAddInput(self.rearCameraInput!) {
                    captureSession.addInput(self.rearCameraInput!)
                }
                self.currentCameraPosition = .rear
            }
            
            else if let frontCamera = self.frontCamera {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                
                if captureSession.canAddInput(self.frontCameraInput!) {
                    captureSession.addInput(self.frontCameraInput!)
                }
                else {
                    throw CameraControllerError.inputsAreInvalid
                }
                self.currentCameraPosition = .front
            }
            else {
                throw CameraControllerError.noCameraAvailable
            }
        }
        func configurePhotoOutput() throws {
            // 4. photo output object를 구성하는 함수
            // AVCapturePhotoOutput을 사용해 캡처 세션에서 output을 만듬
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            // photoOutput은 ~ 객체이고, JPEG 형식을 사용할 것이다.
            self.photoOutput = AVCapturePhotoOutput()
            self.photoOutput!.setPreparedPhotoSettingsArray(
                [AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecJPEG])],
                completionHandler: nil)
            
            // if captureSession.canAddOutput(self.photoOutput) { captureSession.addOutput(self.photoOutput) }
            // captureSession에 photoOutput을 추가하고
            if captureSession.canAddOutput(self.photoOutput!) { captureSession.addOutput(self.photoOutput!) }
            
            // captureSession을 시작한다.
            captureSession.startRunning()
        }
        
        // 상용 코드 for performing the 4 key steps in preparing an AVCaptureSession
        DispatchQueue(label: "prepare").async {
            do{
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configurePhotoOutput()
            }
            
            catch{
                DispatchQueue.main.async {
                    completionHandler(error)
                }
                return
            }
            
            DispatchQueue.main.async {
                completionHandler(nil)
            }
        }
    }
    
    //
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    // 위의 prepare함수는 카메라 디바이스를 준비시키는 함수,
    // displayPreview함수는 capture preview를 생성하고 view에 display하는 함수이다.
    func displayPreview(on view: UIView) throws {
        // captureSession이 러닝중인 종안
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        // captureSession을 사용해 AVCaptureVideoPreview 객체를 생성하고
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        // portrait으로 설정하며,
        self.previewLayer?.connection?.videoOrientation = .portrait
        
        // 제공된 뷰에 추가한다.
        view.layer.insertSublayer(self.previewLayer!, at: 0)
        self.previewLayer?.frame = view.frame
    }
}

extension CameraController {
    // configureCaptureDevices함수에서 capture session을 생성할 때 생길 수 있는 다양한 에러 핸들링을 위한 embedded type
    enum CameraControllerError: Swift.Error{
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCameraAvailable
        case unknown
    }
    
    //configureDeviceInputs함수에 필요한 currentCameraPosition 변수가 상속받기 위해
    public enum CameraPosition {
        case front
        case rear
    }
}
