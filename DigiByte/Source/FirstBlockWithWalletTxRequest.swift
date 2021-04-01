//
//  OldestBlockRequest.swift
//  breadwallet
//
//  Created by YoshiCarlsberg on 15.04.18.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation

struct AddressInfoJSON: Decodable {
    let addrStr: String
    let balance: Double
    let balanceSat: Int64
    let totalReceived: Double
    let totalReceivedSat: Int64
    let totalSent: Double
    let totalSentSat: Int64
    let unconfirmedBalance: Double
    let unconfirmedTxApperances: Int
    let transactions: [String]
}

struct TransactionJSON: Decodable {
    var txid: String
    var hash: String
    var version: Int
    var size: Int
    var blocktime: Int
    var blockhash: String
}

struct BlockJSON: Decodable {
    var hash: String
    var confirmations: Int
    var size: Int
    var height: Int
    var time: Int
    var previousblockhash: String
    var nextblockhash: String
}

// Safe wrapper for URLSession requests, that tries different hosts (in case of host issues)
private class DigiExplorerEndpoint {
    private static let hosts = [
//        "https://digiexplorer2.info", /* debug purposes (invalid host) */
        "https://digiexplorer.info",
        "https://dgb1.trezor.io",
        "https://digibyteblockexplorer.com"
    ]
    
    // Index of hosts array.
    // Will be increased if we encounter a failure
    private var host_id: Int = 0
    
    // Just return the current host (according to the host_id)
    private func getCurrentHost() -> String {
        return DigiExplorerEndpoint.hosts[host_id]
    }
    
    // REST endpoint, e.g. /api/status?q=getInfo
    private let value: String
    
    // Additional args that will be appended.
    // Can be altered from outside.
    var args: String = ""
    
    init(_ endpoint: String, args: String = "") {
        self.value = endpoint
        self.args = args
    }
    
    // Returns a URLSessionDataTask, trying a certain host.
    // On success the host_id (array idx) will be reset to 0.
    // Calls a handler on success / failure that specifies the return data and
    // whether to try a different URL in case of host issues.
    func task(handler: @escaping (Data?, Bool) -> Void) -> URLSessionDataTask? {
        // Out of bounds => no other host left
        if host_id == DigiExplorerEndpoint.hosts.count {
            host_id = 0
            return nil
        }
        
        // Next host
        let host = DigiExplorerEndpoint.hosts[host_id]
        host_id = host_id + 1
        
        // Construct full URL
        let urlStr = host + value + args
        guard let url = URL(string: urlStr) else {
            host_id = 0
            return nil
        }
        
        print(url)
        
        // Create the session task
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 10.0
        
        let session = URLSession(configuration: sessionConfig)
        let task = session.dataTask(with: url, completionHandler: { (data, url, err) in
            var shouldTryOtherURL: Bool = false
            
            guard err == nil else {
                switch err {
                    // the error is most likely happening due to DNS issues?
                    case is URLError:
                        shouldTryOtherURL = true
                    default:
                        shouldTryOtherURL = false
                        self.host_id = 0
                }
                
                // Call the result handler (which is defined in the calling function as a lambda)
                handler(nil, shouldTryOtherURL)
                return
            }
            
            // Request was successful, call the handler
            handler(data, shouldTryOtherURL)
        })
        
        return task
    }
}

// Retrieves the best block from digiexplorer.info
class BestBlockRequest {
    private struct InfoWrapperStruct: Codable {
        let info: InfoStruct
    }
    private struct InfoStruct: Codable {
        let bestblockhash: String
        let blocks: Int
    }
    
    private static let infoURL = DigiExplorerEndpoint("/api/status?q=getInfo")
    
    let onCompletion: (Bool, String, Int, Int) -> Void // success, hash, blockHeight, blockTime
    
    private func nextTrial() -> Void {
        guard let task = BestBlockRequest.infoURL.task( handler: { (data, shouldRetry) in
            guard let data = data else {
                // Retry with another URL if an error occurred
                if shouldRetry {
                    // Same call as in initialization, but with another offset
                    self.nextTrial()
                } else {
                    // Just halt (e.g. in case of bad internet or no data)
                    self.onCompletion(false, "", 0, 0)
                }
                return
            }
            
            do {
                // Decode INSIGHT response
                let decoder = JSONDecoder()
                let json = try decoder.decode(InfoWrapperStruct.self, from: data)
            
                // Extract the best block's data
                // Use the current date as an approximation for the blockDate.
                // This should be ok as we only have 15 seconds block times.
                let blockDate = Date().timeIntervalSince1970
                self.onCompletion(true, json.info.bestblockhash, json.info.blocks, Int(blockDate))
                return
            } catch {
                // JSON Decoding issues, we can't handle this issue, so we just return
            }
            
            self.onCompletion(false, "", 0, 0)
        }) else {
            self.onCompletion(false, "", 0, 0)
            return
        }
        
        task.resume()
    }
    
    @discardableResult
    init(completion: @escaping (Bool, String, Int, Int) -> Void) {
        self.onCompletion = completion
        nextTrial()
    }
}

/*
 Determines the first block of interest, that is, at which block we start sync.
 The block with the first ever wallet's transaction is the block of interest.
 */
class FirstBlockWithWalletTxRequest {
    private struct Block {
        var hash: String
        var blockHeight: Int
        var blockTime: Int
    }
//
//    static let multiAddressBaseURL = "https://digiexplorer.info/api/addrs" /*  /<addr1,addr2,...>/txs */
//    static let txBaseURL = "https://digiexplorer.info/api/tx"
//    static let blockBaseURL = "https://digiexplorer.info/api/block"
    
    private static let mutliAddressBaseURL = DigiExplorerEndpoint("/api/addrs/")
    private static let txBaseURL = DigiExplorerEndpoint("/api/tx/")
    private static let blockBaseURL = DigiExplorerEndpoint("/api/block/")
    
    private var oldestBlock: Block?
    let onCompletion: (Bool, String, Int, Int) -> Void // success, hash, blockHeight, blockTime
    let addresses: [String]
    let useBestBlockAlternatively: Bool
    
    var completed = false
    var callbackCalled = false
    var bestBlockRequest: BestBlockRequest? = nil
    // var lock = DispatchSemaphore(value: 1)
    
    private func next(_ callback: @escaping () -> Void) {
        // lock.wait()
//        self.session.getAllTasks(completionHandler: { (tasks) in
            if !self.callbackCalled {
                self.callbackCalled = true
                // self.lock.signal()
                callback()
            }
//        })
    }
    
    private func fetchTransactions(_ callback: @escaping ([TransactionJSON]) -> Void) {
        callbackCalled = false
        var transactions: [TransactionJSON] = []
        
        if self.addresses.count == 0 {
            return finish()
        }
        
        let addressStr = self.addresses.joined(separator: ",")
        FirstBlockWithWalletTxRequest.mutliAddressBaseURL.args = "\(addressStr)/txs/"
        let task = FirstBlockWithWalletTxRequest.mutliAddressBaseURL.task { (data, shouldRetry) in
            guard let data = data else {
                // Retry with another URL if an error occurred
                if shouldRetry {
                    // Same call as in initialization, but with another offset
                    self.fetchTransactions(callback)
                } else {
                    // Just halt (e.g. in case of bad internet or no data)
                    self.onCompletion(false, "", 0, 0)
                }
                return
            }
            
            do {
                // Decode the transactions
                let parsedJSON = try JSONDecoder().decode([TransactionJSON].self, from: data)

                for transaction in parsedJSON {
                    transactions.append(transaction)
                }
            } catch {
                // JSON Decoding issues, we can't handle this issue, so we just return
            }
            
            self.next { callback(transactions) }
        }
        
        if let task = task {
            task.resume()
        } else {
            self.onCompletion(false, "", 0, 0)
        }
    }
    
    private func finish() {
        if self.completed { return }
        completed = true
        
        if let b = oldestBlock {
            self.onCompletion(true, b.hash, b.blockHeight, b.blockTime)
        } else {
            if self.useBestBlockAlternatively {
                self.bestBlockRequest = BestBlockRequest { (success, blockHash, blockHeight, blockTimestamp) in
                    self.onCompletion(success, blockHash, blockHeight, blockTimestamp)
                }
            } else {
                self.onCompletion(true, "", 0, 0)
            }
        }
    }
    
    private func getBlock(_ blockHash: String, callback: @escaping (BlockJSON?) -> Void) {
        FirstBlockWithWalletTxRequest.blockBaseURL.args = blockHash
        let task = FirstBlockWithWalletTxRequest.blockBaseURL.task { (data, shouldRetry) in
            guard let data = data else {
                // Retry with another URL if an error occurred
                if shouldRetry {
                    // Same call as in initialization, but with another offset
                    self.getBlock(blockHash, callback: callback)
                } else {
                    // Just halt (e.g. in case of bad internet or no data)
                    self.onCompletion(false, "", 0, 0)
                }
                return
            }
            
            // Decode result
            do {
                let json = try JSONDecoder().decode(BlockJSON.self, from: data)
                callback(json)
            } catch {
                print("Error deserializing JSON \(error):", String.init(bytes: data, encoding: .utf8) ?? "<<null>>")
                callback(nil)
            }
        }
       
        if let task = task {
            task.resume()
        } else {
            self.onCompletion(false, "", 0, 0)
        }
    }
    
    func start() {
        // get the transactions for the public wallet addresses
        self.fetchTransactions { (transactions) in
            // If there was no transaction in the past, return
            if transactions.count == 0 { return self.finish() }
            
            // Get the oldest transaction
            guard let oldestTx = transactions.max(by: { (a, b) -> Bool in
                return a.blocktime > b.blocktime
            }) else { return self.finish() }
        
            // Get the block data from the oldest transaction
            self.getBlock(oldestTx.blockhash, callback: { (block) in
                if let b = block {
                    // Use the block before the relevant block,
                    // to ensure the sync is including the first tx
                    self.getBlock(b.previousblockhash, callback: { (prevBlock) in
                        if let p = prevBlock {
                            self.oldestBlock = Block(hash: p.hash, blockHeight: p.height, blockTime: p.time)
                        }
                        self.finish()
                    })
                } else {
                    self.finish()
                }
            })
        }
    }
    
    init(_ addr: [String], useBestBlockAlternatively: Bool = false, completion: @escaping (Bool, String, Int, Int) -> Void) {
        onCompletion = completion
        
        // create session
        self.addresses = addr
        self.useBestBlockAlternatively = useBestBlockAlternatively
    }
    
    deinit {
        bestBlockRequest = nil
    }
}
