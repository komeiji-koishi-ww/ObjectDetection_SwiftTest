//
//  ImagePickerVC.swift
//  ObjectDetection
//
//  Created by kijin_seija on 2022/10/26.
//  Copyright © 2022 Y Media Labs. All rights reserved.
//

import UIKit
import SnapKit

class ImagePickerVC: UIViewController {
    
    
    var backImg: UIImageView!
    var result: Result?
    
    var overlayView: OverlayView!
    private let displayFont = UIFont.systemFont(ofSize: 14.0, weight: .medium)
    private let edgeOffset: CGFloat = 2.0
    private let labelOffset: CGFloat = 10.0
    
    private var modelDataHandler: ModelDataHandler? =
      ModelDataHandler(modelFileInfo: Yolov5.modelInfo, labelsFileInfo: Yolov5.labelsInfo)
    
    lazy var picker : UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        return picker
    }()
     
    override func viewDidLoad() {
        super.viewDidLoad()
        
        best()
        setupUI()
        // Do any additional setup after loading the view.
    }
    
    
    
    
    func setupUI() {
        
        // Do any additional setup after loading the view.
        
        backImg = UIImageView(frame: .zero)
        self.view.addSubview(backImg)
//        self.backImg.contentMode = .f
        backImg.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.overlayView = OverlayView(frame: .zero)
        self.overlayView.backgroundColor = .init(white: 1, alpha: 0)
        self.view.addSubview(self.overlayView)
        self.overlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let button = UIButton(type: .custom)
        button.setTitle("SELECT", for: .normal)
        button.setTitleColor(.black, for: .normal)
        self.view.addSubview(button)
        
        button.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        button.addTarget(self, action: #selector(showPicker), for: .touchUpInside)
    }
    
    @objc
    func showPicker() {
        
        self.present(picker, animated: true)
        
        
    }
    
    func drawAfterPerformingCalculations(onInferences inferences: [Inference], withImageSize imageSize:CGSize) {

      self.overlayView.objectOverlays = []
      self.overlayView.setNeedsDisplay()

      guard !inferences.isEmpty else {
        return
      }

      var objectOverlays: [ObjectOverlay] = []

      for inference in inferences {

        // Translates bounding box rect to current view.
        var convertedRect = inference.rect.applying(CGAffineTransform(scaleX: self.overlayView.bounds.size.width / imageSize.width, y: self.overlayView.bounds.size.height / imageSize.height))

        if convertedRect.origin.x < 0 {
          convertedRect.origin.x = self.edgeOffset
        }

        if convertedRect.origin.y < 0 {
          convertedRect.origin.y = self.edgeOffset
        }

        if convertedRect.maxY > self.overlayView.bounds.maxY {
          convertedRect.size.height = self.overlayView.bounds.maxY - convertedRect.origin.y - self.edgeOffset
        }

        if convertedRect.maxX > self.overlayView.bounds.maxX {
          convertedRect.size.width = self.overlayView.bounds.maxX - convertedRect.origin.x - self.edgeOffset
        }

        let confidenceValue = Int(inference.confidence * 100.0)
        let string = "\(inference.className)  (\(confidenceValue)%)"

        let size = string.size(usingFont: self.displayFont)

        let objectOverlay = ObjectOverlay(name: string, borderRect: convertedRect, nameStringSize: size, color: inference.displayColor, font: self.displayFont)

        objectOverlays.append(objectOverlay)
      }

      // Hands off drawing to the OverlayView
      self.draw(objectOverlays: objectOverlays)

    }

    /** Calls methods to update overlay view with detected bounding boxes and class names.
     */
    func draw(objectOverlays: [ObjectOverlay]) {

      self.overlayView.objectOverlays = objectOverlays
      self.overlayView.setNeedsDisplay()
    }
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    
    func scaleImage(image: UIImage, size: CGFloat) -> UIImage? {
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), true, 1)
        
        let x,y,w,h : CGFloat
        
        let imageW = image.size.width
        let imageH = image.size.height
        
        if imageW > imageH {
            w = imageW / imageH * size
            h = size
            x = (size-w) / 2
            y = 0
        }else {
            h = imageH / imageW * size
            w = size
            y = (size - h) / 2
            x = 0
        }
        
        image.draw(in: CGRect(x: x, y: y, width: w, height: h))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
    
    func pixelBuffer(newImage: UIImage) -> CVPixelBuffer? {
        
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
                var pixelBuffer : CVPixelBuffer?
                let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(newImage.size.width), Int(newImage.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
                guard (status == kCVReturnSuccess) else {
                    return nil
                }
                
                CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
                let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
                
                let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                let context = CGContext(data: pixelData, width: Int(newImage.size.width), height: Int(newImage.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) //3
                
                context?.translateBy(x: 0, y: newImage.size.height)
                context?.scaleBy(x: 1.0, y: -1.0)
                
                UIGraphicsPushContext(context!)
                newImage.draw(in: CGRect(x: 0, y: 0, width: newImage.size.width, height: newImage.size.height))
                UIGraphicsPopContext()
                CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
    
}


extension ImagePickerVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        guard let image = info[.originalImage] as? UIImage else {return}
        picker.dismiss(animated: true)
        
//        guard let scaled = scaleImage(image: image, size: 640) else {return}
        guard let buffer = pixelBuffer(newImage: image) else {return}
        guard let result = self.modelDataHandler?.runModel(onFrame: buffer) else {return}
        
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        
        self.drawAfterPerformingCalculations(onInferences: result.inferences, withImageSize: CGSize(width: width, height: height))
        
        for item in result.inferences {
            print(item.className, item.rect)
        }
        
        self.backImg.image = image
        
    }
    
}
