//
//  BRDigiID.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 6/17/16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import Security
import BRCore
import UIKit

public extension URLRequest {
    
    /// Returns a cURL command for a request
    /// - return A String object that contains cURL command or "" if an URL is not properly initalized.
    var cURL: String {
        
        guard
            let url = url,
            let httpMethod = httpMethod,
            url.absoluteString.utf8.count > 0
            else {
                return ""
        }
        
        var curlCommand = "curl --verbose \\\n"
        
        // URL
        curlCommand = curlCommand.appendingFormat(" '%@' \\\n", url.absoluteString)
        
        // Method if different from GET
        if "GET" != httpMethod {
            curlCommand = curlCommand.appendingFormat(" -X %@ \\\n", httpMethod)
        }
        
        // Headers
        let allHeadersFields = allHTTPHeaderFields!
        let allHeadersKeys = Array(allHeadersFields.keys)
        let sortedHeadersKeys  = allHeadersKeys.sorted(by: <)
        for key in sortedHeadersKeys {
            curlCommand = curlCommand.appendingFormat(" -H '%@: %@' \\\n", key, self.value(forHTTPHeaderField: key)!)
        }
        
        // HTTP body
        if let httpBody = httpBody, httpBody.count > 0 {
            let httpBodyString = String(data: httpBody, encoding: String.Encoding.utf8)!
            let escapedHttpBody = URLRequest.escapeAllSingleQuotes(httpBodyString)
            curlCommand = curlCommand.appendingFormat(" --data '%@' \\\n", escapedHttpBody)
        }
        
        return curlCommand
    }
    
    /// Escapes all single quotes for shell from a given string.
    static func escapeAllSingleQuotes(_ value: String) -> String {
        return value.replacingOccurrences(of: "'", with: "'\\''")
    }
}

protocol BRDigiIDProtocol {
    func runCallback(store: BRStore, _ completionHandler: @escaping (Data?, URLResponse?, NSError?) -> Void);
    var url: URL { get }
}

open class BRDigiID : NSObject, BRDigiIDProtocol {
    static let SCHEME = "digiid"
    static let PARAM_NONCE = "x"
    static let PARAM_UNSECURE = "u"
    static let PARAM_ASSETS = "assetId"
    static let USER_DEFAULTS_NONCE_KEY = "BRDigiID_nonces"
    static let DEFAULT_INDEX: UInt32 = 0
    
    class func isBitIDURL(_ url: URL!) -> Bool {
        return url.scheme == SCHEME
    }
    
    static let BITCOIN_SIGNED_MESSAGE_HEADER = "DigiByte Signed Message:\n".data(using: String.Encoding.utf8)!
    
    class func formatMessageForBitcoinSigning(_ message: String) -> Data {
        let data = NSMutableData()
        var messageHeaderCount = UInt8(BITCOIN_SIGNED_MESSAGE_HEADER.count)
        data.append(NSData(bytes: &messageHeaderCount, length: MemoryLayout<UInt8>.size) as Data)
        data.append(BITCOIN_SIGNED_MESSAGE_HEADER)
        let msgBytes = message.data(using: String.Encoding.utf8)!
        data.appendVarInt(i: UInt64(msgBytes.count))
        data.append(msgBytes)
        return data as Data
    }
    
    // sign a message with a key and return a base64 representation
    class func signMessage(_ message: String, usingKey key: BRKey) -> String {
        let signingData = formatMessageForBitcoinSigning(message)
        let signature = signingData.sha256_2.compactSign(key: key)
        return String(bytes: signature.base64EncodedData(options: []), encoding: String.Encoding.utf8) ?? ""
    }
    
    let url: URL
    let portStr: String
    let walletManager: WalletManager
    
    open var siteName: String {
        return "\(url.host!)\(portStr)"
    }
    
    init(url u: URL, walletManager wm: WalletManager) {
        walletManager = wm
        url = u
        
        if let p = u.port {
            portStr = ":\(p)"
        } else {
            portStr = ""
        }
    }
    
    func newNonce() -> String {
        let defs = UserDefaults.standard
        let nonceKey = "\(url.host!)\(portStr)/\(url.path)"
        var allNonces = [String: [String]]()
        var specificNonces = [String]()
        
        // load previous nonces. we save all nonces generated for each service
        // so they are not used twice from the same device
        if let existingNonces = defs.object(forKey: BRDigiID.USER_DEFAULTS_NONCE_KEY) {
            allNonces = existingNonces as! [String: [String]]
        }
        if let existingSpecificNonces = allNonces[nonceKey] {
            specificNonces = existingSpecificNonces
        }
        
        // generate a completely new nonce
        var nonce: String
        repeat {
            nonce = "\(Int(Date().timeIntervalSince1970))"
        } while (specificNonces.contains(nonce))
        
        // save out the nonce list
        specificNonces.append(nonce)
        allNonces[nonceKey] = specificNonces
        defs.set(allNonces, forKey: BRDigiID.USER_DEFAULTS_NONCE_KEY)
        
        return nonce
    }
    
    func runCallback(store: BRStore, _ completionHandler: @escaping (Data?, URLResponse?, NSError?) -> Void) {
        print("Digi-ID (non-legacy)")
        guard !walletManager.noWallet else {
            DispatchQueue.main.async {
                completionHandler(nil, nil, NSError(domain: "", code: -1001, userInfo:
                    [NSLocalizedDescriptionKey: NSLocalizedString("No wallet", comment: "")]))
            }
            return
        }
        
        if url.host == nil {
            DispatchQueue.main.async {
                completionHandler(nil, nil, NSError(domain: "", code: -1001, userInfo:
                    [NSLocalizedDescriptionKey: NSLocalizedString("Invalid url", comment: "")]))
            }
            return
        }
        
        let prompt = siteName
        store.trigger(name: .authenticateForBitId(prompt, { (s) -> Void in
            if case .success = s {
                self.run(completionHandler)
            }
        }))
    }

    private func run(_ completionHandler: @escaping (Data?, URLResponse?, NSError?) -> Void) {
        autoreleasepool {
            // Default scheme is https;
            // http will only be used, if the digi-id request specifies 1 as the value for the argument u.
            var scheme = "https"
            
            // Request id / ad-hoc token
            var nonce: String
            
            var assetId: String? = nil
            var dualAsset: Bool? = nil
            
            // First we check, if a valid URL was passed
            guard url.query != nil else {
                DispatchQueue.main.async {
                    completionHandler(nil, nil, NSError(domain: "", code: -1001, userInfo:
                        [NSLocalizedDescriptionKey: NSLocalizedString("Malformed URI", comment: "")]))
                }
                return
            }
            
            // Convert query parameters to dictionary for easy access
            let query = url.query!.parseQueryString()
            
            // Check if unsecure parameter was specified.
            // That is, the service wants to use http instead of https.
            // ToDo: Since we want to provide a secure authentication algorithm, we
            //       should actually force users to use HTTPS. Or at least the wallet user
            //       must enable a switch in the wallet settings. We need to discuss that in the
            //       future.
            if let u = query[BRDigiID.PARAM_UNSECURE], u.count == 1 && u[0] == "1" {
                print("Digi-ID: HTTP SUPPORT REMOVED")
            }
            
            // Check if service is providing a nonce, or if we should generate one.
            if let x = query[BRDigiID.PARAM_NONCE], x.count == 1 {
                nonce = x[0] // service is providing a nonce
            } else {
                nonce = newNonce() // we are generating our own nonce
            // Asset Signing
            }
            
            if let aids = query[BRDigiID.PARAM_ASSETS], aids.count == 1 {
                assetId = aids[0]
                dualAsset = query["dual"] != nil
            }
            
            // ToDo: Use nonce
            nonce = nonce + "" // silent warning
            
            // Build a payload consisting of the signature, address and uri.
            // First we need to remove the args from the uri, because the changing nonce would
            // create a different key for each auth.
            var derivationURI = URLComponents(string: url.absoluteString)!
            derivationURI.query = nil
            derivationURI.scheme = scheme
            guard var priv = walletManager.buildBitIdKey(url: derivationURI.string!, index: Int(BRDigiID.DEFAULT_INDEX)) else {
                return
            }

            // Sign the input url with wallet's private key.
            // According to the Digi-ID protocol, we will have to provide
            // the public address of the private key and the signature itself.
            // Also the input URI will be provided.
            // Cryptographic proof: signature will be decrypted with provided address,
            //                      which should result in the value of the field uri
            let uriWithNonce = url.absoluteString
            let signature = BRDigiID.signMessage(uriWithNonce, usingKey: priv)
            var payload: [String: String] = [
                "address": priv.address()!,
                "signature": signature,
                "uri": uriWithNonce
            ]
            
            if let assetId = assetId {
                let utxos = AssetHelper.getAssetUtxos(for: assetId)
                var walletAddress: String? = nil
                
                utxos.forEach { (outputModel) in
                    guard AssetHelper.assetWasNotSpentCallback(outputModel.txid, outputModel.index) else { return }
                    guard let addresses = outputModel.base.scriptPubKey.addresses else { return }
                    guard addresses.count > 0 else { return }
                    walletAddress = addresses[0]
                }
                
                guard let address = walletAddress else {
                    DispatchQueue.main.async {
                        completionHandler(nil, nil, NSError(domain: "", code: -1001, userInfo:
                        [NSLocalizedDescriptionKey: NSLocalizedString("Asset not available", comment: "")]))
                    }
                    return
                }
                
                // Build asset holder address signature
                
                guard let privKey = walletManager.getAddressPrivateKey(address: address) else {
                    DispatchQueue.main.async {
                        completionHandler(nil, nil, NSError(domain: "", code: -1001, userInfo:
                        [NSLocalizedDescriptionKey: NSLocalizedString("No private key for this address", comment: "")]))
                    }
                    return
                }
                
                let signature = BRDigiID.signMessage(uriWithNonce, usingKey: privKey)
                
                if dualAsset == true {
                    payload["assetaddress"] = walletAddress
                    payload["assetsignature"] = signature
                } else {
                    payload["address"] = walletAddress
                    payload["signature"] = signature
                }
            }
            
            // Encode the payload to JSON
            let json = try! JSONSerialization.data(withJSONObject: payload, options: [])
            
            // The Digi-ID protocol foresees the digi-id uri to start with digiid://.
            // In order to call the callback, we need to replace that pattern with http(s)://
            let digiidURIString = url.absoluteString
            let httpURLString = try! NSRegularExpression(pattern: "^digiid://", options: NSRegularExpression.Options.caseInsensitive).stringByReplacingMatches(in: digiidURIString, options: [], range: NSMakeRange(0, digiidURIString.count), withTemplate: "\(scheme)://")
            guard let httpURL = URL(string: httpURLString) else {
                DispatchQueue.main.async {
                    completionHandler(nil, nil, NSError(domain: "", code: -1001, userInfo:
                    [NSLocalizedDescriptionKey: NSLocalizedString("Malformed http URI", comment: "")]))
                }
                return
            }
            
            // Prepare the request
            var req = URLRequest(url: httpURL)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpMethod = "POST"
            req.httpBody = json
            let session = URLSession.shared
        
            // debug (print as CURL)
            print(req.cURL)
            UIPasteboard.general.string = req.cURL
            
            // Fire the digi-id callback request
            session.dataTask(with: req, completionHandler: { (dat: Data?, resp: URLResponse?, err: Error?) in
                var rerr: NSError?
                if err != nil {
                    rerr = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "\(err!.localizedDescription)"])
                }
                
                // Call the completion handler with the return data.
                // rerr: return error is optional.
                DispatchQueue.main.async {
                    completionHandler(dat, resp, rerr)
                }
            }).resume()
        }
    }
}

extension URL {
    
    @discardableResult
    func append(_ queryItem: String, value: String?) -> URL {
        
        guard var urlComponents = URLComponents(string:  absoluteString) else { return absoluteURL }
        
        // create array of existing query items
        var queryItems: [URLQueryItem] = urlComponents.queryItems ??  []
        
        // create query item if value is not nil
        guard let value = value else { return absoluteURL }
        let queryItem = URLQueryItem(name: queryItem, value: value)
        
        // append the new query item in the existing query items array
        queryItems.append(queryItem)
        
        // append updated query items array in the url component object
        urlComponents.queryItems = queryItems// queryItems?.append(item)
        
        // returns the url from new url components
        return urlComponents.url!
    }
}
