//
//  ScanViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-12.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import AVFoundation

typealias ScanCompletion = (PaymentRequest?) -> Void
typealias DigiIDScanCompletion = (DigiIdRequest?) -> Void
typealias KeyScanCompletion = (String) -> Void

enum ScanViewType {
    case payment
    case digiid
}

class ScanViewController : UIViewController, Trackable {

    static func presentCameraUnavailableAlert(fromRoot: UIViewController) {
        let alertController = AlertController(title: S.Send.cameraUnavailableTitle, message: S.Send.cameraUnavailableMessage, preferredStyle: .alert)
        alertController.addAction(AlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        alertController.addAction(AlertAction(title: S.Button.settings, style: .`default`, handler: { _ in
            if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
            }
        }))
        fromRoot.present(alertController, animated: true, completion: nil)
    }
 
    static var isCameraAllowed: Bool {
        return AVCaptureDevice.authorizationStatus(for: AVMediaType.video) != .denied
    }

    let completion: ScanCompletion?
    let digiIdCompletion: DigiIDScanCompletion?
    let scanKeyCompletion: KeyScanCompletion?
    let isValidURI: (String) -> Bool

    fileprivate let guide = CameraGuideView()
    fileprivate let session = AVCaptureSession()
    private var previewLayer: CALayer?
    private let toolbar = UIView()
    private let close = UIButton.close
    private let flash = UIButton.icon(image: UIImage(named: "flash-off")!.withRenderingMode(.alwaysTemplate), accessibilityLabel: S.Scanner.flashButtonLabel)
    fileprivate var currentUri = ""
    private let scanViewType: ScanViewType

    // this constructor was added to support DigiId. It switches the scan mode to .digiid, and does basically the same
    // as the other constructors. It does not create a Payment class instance, to check whether the scanned url is valid.
    // Instead of using PaymentRequest, it does it with DigiIdRequest.
    init(digiIdCompletion: @escaping DigiIDScanCompletion, isValidURI: @escaping (String) -> Bool) {
        self.scanViewType = .digiid
        self.digiIdCompletion = digiIdCompletion
        self.scanKeyCompletion = nil
        self.isValidURI = isValidURI
        self.completion = nil
        
        super.init(nibName: nil, bundle: nil)
    }
    
    init(completion: @escaping ScanCompletion, isValidURI: @escaping (String) -> Bool) {
        scanViewType = .payment
        self.completion = completion
        self.digiIdCompletion = nil
        self.scanKeyCompletion = nil
        self.isValidURI = isValidURI
        super.init(nibName: nil, bundle: nil)
    }

    init(scanKeyCompletion: @escaping KeyScanCompletion, isValidURI: @escaping (String) -> Bool) {
        scanViewType = .payment
        self.scanKeyCompletion = scanKeyCompletion
        self.digiIdCompletion = nil
        self.completion = nil
        self.isValidURI = isValidURI
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        previewLayer?.frame = self.view.superview?.bounds ?? self.view.bounds
    }

    override func viewDidLoad() {
        view.backgroundColor = UIColor.black
        flash.tintColor = C.Colors.text
        toolbar.backgroundColor = C.Colors.background

        view.addSubview(toolbar)
        toolbar.addSubview(close)
        toolbar.addSubview(flash)
        view.addSubview(guide)

        toolbar.constrainBottomCorners(sidePadding: 0, bottomPadding: 0)
        if E.isIPhoneXOrGreater {
            toolbar.constrain([ toolbar.constraint(.height, constant: 60.0) ])
            
            close.constrain([
                close.constraint(.leading, toView: toolbar),
                close.constraint(.top, toView: toolbar, constant: 2.0),
                close.constraint(.width, constant: 44.0),
                close.constraint(.height, constant: 44.0) ])
            
            flash.constrain([
                flash.constraint(.trailing, toView: toolbar),
                flash.constraint(.top, toView: toolbar, constant: 2.0),
                flash.constraint(.width, constant: 44.0),
                flash.constraint(.height, constant: 44.0) ])
            
        } else {
            toolbar.constrain([ toolbar.constraint(.height, constant: 48.0) ])
            
            close.constrain([
                close.constraint(.leading, toView: toolbar),
                close.constraint(.top, toView: toolbar, constant: 2.0),
                close.constraint(.bottom, toView: toolbar, constant: -2.0),
                close.constraint(.width, constant: 44.0) ])
            
            flash.constrain([
                flash.constraint(.trailing, toView: toolbar),
                flash.constraint(.top, toView: toolbar, constant: 2.0),
                flash.constraint(.bottom, toView: toolbar, constant: -2.0),
                flash.constraint(.width, constant: 44.0) ])
        }

        guide.constrain([
            guide.constraint(.leading, toView: view, constant: C.padding[6]),
            guide.constraint(.trailing, toView: view, constant: -C.padding[6]),
            guide.constraint(.centerY, toView: view),
            NSLayoutConstraint(item: guide, attribute: .width, relatedBy: .equal, toItem: guide, attribute: .height, multiplier: 1.0, constant: 0.0) ])
        guide.transform = CGAffineTransform(scaleX: 0.0, y: 0.0)

        close.tap = { [weak self] in
            //self?.saveEvent("scan.dismiss")
            self?.dismiss(animated: true, completion: {
                self?.completion?(nil)
            })
        }
        
        if scanViewType == .digiid {
            if let image = UIImage(named: "Digi-id-icon") {
                let logo = UIImageView(image: image.withRenderingMode(.alwaysTemplate))
                logo.contentMode = .scaleAspectFit
                logo.tintColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.3)
                view.addSubview(logo)
                
                logo.constrain([
                    logo.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
                    logo.bottomAnchor.constraint(equalTo: guide.topAnchor, constant: -20),
                    logo.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
                    logo.widthAnchor.constraint(equalToConstant: 80)
                ])
            }
        }

        addCameraPreview()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.spring(0.8, animations: {
            self.guide.transform = .identity
        }, completion: { _ in })
    }

    private func addCameraPreview() {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        if let previewLayer = previewLayer {
            previewLayer.frame = self.view.superview?.bounds ?? self.view.bounds
            view.layer.insertSublayer(previewLayer, at: 0)
        }

        let output = AVCaptureMetadataOutput()
        output.setMetadataObjectsDelegate(self, queue: .main)
        session.addOutput(output)

        if output.availableMetadataObjectTypes.contains(where: { objectType in
            return objectType == AVMetadataObject.ObjectType.qr
        }) {
            output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        } else {
            print("no qr code support")
        }

        DispatchQueue(label: "qrscanner").async {
            self.session.startRunning()
        }

        if device.hasTorch {
            flash.tap = { [weak self] in
                do {
                    try device.lockForConfiguration()
                    device.torchMode = device.torchMode == .on ? .off : .on
                    device.unlockForConfiguration()
                    if device.torchMode == .on {
                        //self?.saveEvent("scan.torchOn")
                        self?.flash.tintColor = C.Colors.weirdRed
                        self?.flash.setImage(UIImage(named: "flash-on")?.withRenderingMode(.alwaysTemplate), for: .normal)
                    } else {
                        //self?.saveEvent("scan.torchOn")
                        self?.flash.tintColor = C.Colors.text
                        self?.flash.setImage(UIImage(named: "flash-off")?.withRenderingMode(.alwaysTemplate), for: .normal)
                    }
                } catch let error {
                    print("Camera Torch error: \(error)")
                }
            }
        } else {
            flash.isHidden = true
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ScanViewController : AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ captureOutput: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let data = metadataObjects as? [AVMetadataMachineReadableCodeObject] {
            if data.count == 0 {
                guide.state = .normal
            } else {
                data.forEach {
                    guard let uri = $0.stringValue else { return }
                    if completion != nil || digiIdCompletion != nil {
                        handleURI(uri)
                    } else if scanKeyCompletion != nil {
                        handleKey(uri)
                    }
                }
            }
        }
    }

    func handleURI(_ uri: String) {
        if self.currentUri != uri {
            switch scanViewType {
                case .payment:
                    if let paymentRequest = PaymentRequest(string: uri) {
                        //saveEvent("scan.digibyteUri")
                        guide.state = .positive
                        //Add a small delay so the green guide will be seen
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                            self.dismiss(animated: true, completion: {
                                self.completion?(paymentRequest)
                            })
                        })
                    } else {
                        guide.state = .negative
                    }

                case .digiid:
                    if let digiIdRequest = DigiIdRequest(string: uri) {
                        guide.state = .positive
                        //Add a small delay so the green guide will be seen
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                            self.dismiss(animated: true, completion: {
                                self.digiIdCompletion?(digiIdRequest)
                            })
                        })
                    } else {
                        guide.state = .negative
                    }
            }
            
            self.currentUri = uri
        }
    }

    func handleKey(_ address: String) {
        if isValidURI(address) {
            //saveEvent("scan.privateKey")
            guide.state = .positive
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                self.dismiss(animated: true, completion: {
                    self.scanKeyCompletion?(address)
                })
            })
        } else {
            guide.state = .negative
        }
    }
}
