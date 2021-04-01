//
//  PaymentRequest.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-26.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

enum DigiIdRequestType {
    case local
    case remote
}

struct DigiIdRequest {
    
    init?(string: String) {
        callbackID = "none"
        signString = string
        
        if let trimmedUrl = NSURL(string: string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).replacingOccurrences(of: "://", with: ":").replacingOccurrences(of: " ", with: "%20")) {
            
            if let scheme = trimmedUrl.scheme, let resourceSpecifier = trimmedUrl.resourceSpecifier, trimmedUrl.host == nil,
                let url = NSURL(string: "\(scheme)://\(resourceSpecifier)") {
                
                if url.scheme == "digiid", let host = url.host {
                    toAddress = host
                    port = url.port
                    
                    guard let components = url.query?.components(separatedBy: "&") else { type = .local; return }
                    for component in components {
                        let pair = component.components(separatedBy: "=")
                        if pair.count < 2 { continue }
                        let key = pair[0]
                        var value = String(component[component.index(key.endIndex, offsetBy: 1)...])
                        value = (value.replacingOccurrences(of: "+", with: " ") as NSString).removingPercentEncoding!
                        
                        switch key {
                        case "x":
                            self.callbackID = value
                        case "origin":
                            // callback url
                            self.originURL = value
                        case "u":
                            // unsecure
                            self.https = (value == "0")
                        case "tos":
                            // contract
                            if let decodedData = Data(base64Encoded: value)  {
                                self.contract = String(data: decodedData, encoding: .utf8)
                            } else {
                                self.error = "Invalid Contract"
                            }
                        case "assetId":
                            // Asset signer
                            self.assetId = value
                            if string.contains("&dual") { self.dualAsset = true }
                            
                        default:
                            print("Keys in DigiId url scheme not found: \(key)")
                        }
                    }
                    type = r == nil ? .local : .remote
                    return
                }
            } else if trimmedUrl.scheme == "http" || trimmedUrl.scheme == "https" {
                type = .remote
                remoteRequest = trimmedUrl
                return
            }
        }
        
        if string.isValidAddress {
            toAddress = string
            type = .local
            return
        }
        
        return nil
    }
    
    init?(data: Data) {
        self.paymentProtoclRequest = PaymentProtocolRequest(data: data)
        type = .local
        callbackID = "none"
        signString = ""
    }
    
    func getHTTPUrl() -> NSURL? {
        let newUri = signString.replacingOccurrences(of: "digiid://", with: https! ? "https://" : "http://")
        return NSURL(fileURLWithPath: newUri);
    }
    
    func fetchRemoteRequest(completion: @escaping (PaymentRequest?) -> Void) {
        
        let request: NSMutableURLRequest
        if let url = r {
            request = NSMutableURLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5.0)
        } else {
            request = NSMutableURLRequest(url: remoteRequest! as URL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5.0) //TODO - fix !
        }
        
        request.setValue("application/digibyte-paymentrequest", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
            guard error == nil else { return completion(nil) }
            guard let data = data else { return completion(nil) }
            guard let response = response else { return completion(nil) }
            
            if response.mimeType?.lowercased() == "application/digibyte-paymentrequest" {
                completion(PaymentRequest(data: data))
            } else if response.mimeType?.lowercased() == "text/uri-list" {
                for line in (String(data: data, encoding: .utf8)?.components(separatedBy: "\n"))! {
                    if line.hasPrefix("#") { continue }
                    completion(PaymentRequest(string: line))
                    break
                }
                completion(nil)
            } else {
                completion(nil)
            }
            }.resume()
    }
    
    static func requestString(withHost: String, withCallbackID: String) -> String {
        return "digiid://\(withHost)/callback?x=\(withCallbackID)"
    }
    
    var toAddress: String?
    let type: DigiIdRequestType
    var callbackID: String
    var originURL: String?
    var remoteRequest: NSURL?
    var paymentProtoclRequest: PaymentProtocolRequest?
    var r: URL?
    var https: Bool? = true
    var signString: String
    var port: NSNumber?
    var contract: String? = nil
    var assetId: String? = nil // DigiAsset ID
    var dualAsset: Bool = false
    
    var error: String? = nil
}
