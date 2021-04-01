//
//  AssetSender.swift
//  DigiByte
//
//  Created by Yoshi Jaeger on 09.12.19.
//  Copyright © 2019 DigiByte Foundation NZ Limited. All rights reserved.
//

import Foundation
import UIKit

struct EncodingInfo {
    let flag: Int
    let exponent: Double
    let byteSize: Int
    let mantis: Int
}
fileprivate let encodingSchemeTable: [EncodingInfo] = [
    EncodingInfo(flag: 0x20, exponent: 4, byteSize: 2, mantis: 9),
    EncodingInfo(flag: 0x40, exponent: 4, byteSize: 3, mantis: 17),
    EncodingInfo(flag: 0x60, exponent: 4, byteSize: 4, mantis: 25),
    EncodingInfo(flag: 0x80, exponent: 3, byteSize: 5, mantis: 34),
    EncodingInfo(flag: 0xa0, exponent: 3, byteSize: 6, mantis: 42),
    EncodingInfo(flag: 0xc0, exponent: 0, byteSize: 7, mantis: 54),
]

fileprivate var encodingSchemeMantisMap: [Int : EncodingInfo] = {
    var res = [Int : EncodingInfo]()
    var idx: Int = 0
    var current = encodingSchemeTable[idx]
    
    for i in 1..<54 {
        if i > current.mantis {
            current = encodingSchemeTable[idx]
            idx += 1
        }
        res[i] = current
    }
    
    return res
}()

fileprivate class sffcEncoder {
    private struct FL {
        var m: Int
        var e: Int
    }
    
    static private func padded(_ hex: String, bytes: Int) -> String {
        hex.count == bytes * 2 ? hex : padded("0" + hex, bytes: bytes)
    }
    
    static private func intToFloatArray(number: Int, n: Int = 0) -> FL {
        return number % 10 != 0 ? FL(m: number, e: n) : intToFloatArray(number: number / 10, n: n + 1)
    }
    
    static private func lookupFlag(flag: Int) -> EncodingInfo? {
        return encodingSchemeTable.first { $0.flag == flag }
    }
    
    static private func lookupMantis(mantis: Int) -> EncodingInfo {
        if let ret = encodingSchemeMantisMap[mantis] {
            return ret
        } else {
            return encodingSchemeTable[0]
        }
    }
    
    static private func binaryDigits(_ number: Int) -> Int {
        let res = Int(floor(log2(Double(number)) + 1))
        return res
    }
    
    static func format(amount: Int) -> [UInt8] {
        if amount < 32 {
            return [UInt8(amount)]
        }
        
        var floatingArray = intToFloatArray(number: amount)
        var info: EncodingInfo!
        while true {
            info = lookupMantis(mantis: binaryDigits(floatingArray.m))
            if (Int(pow(2.0, info.exponent)) - 1 >= floatingArray.e) { break }
            floatingArray.m *= 10
            floatingArray.e -= 1
        }
        
        let shifted = floatingArray.m * Int(pow(2.0, info.exponent))
        
        // Due to the stupid developers of ColouredCoins, we need to create a string to append zeros
        // to the beginning of the hexadecimal representation. They could have made their lifes much easier,
        // and mine too, if they used the LSB semantics
        var str = String(format: "%llX", shifted)
        str = padded(str, bytes: info.byteSize)
        
        var ret = str.hexToData!
        
        ret[0] |= UInt8(info.flag)
        ret[info.byteSize - 1] |= UInt8(floatingArray.e)
        
        return [UInt8](ret)
    }
}

class AssetSender {
    init(walletManager: WalletManager, store: BRStore) {
        self.walletManager = walletManager
        self.store = store
    }

    private let walletManager: WalletManager
    private let store: BRStore
    var transaction: BRTxRef?
    var rate: Rate?
    var feePerKb: UInt64?
    var errorCode: Int? = nil
    
    private var usedUtxos = [AssetUtxoModel]()
    
    deinit {
        invalidate()
    }
    
    func createBurnTransaction(assetModel: AssetModel, amount: Int, extra: UInt64 = 0) -> Bool {
        // Use internal address just temporarely for asset tx builder
        guard let internalAddress = walletManager.wallet?.internalChangeAddress() else { return false }
        
        // Call default
        return createTransaction(assetModel: assetModel, amount: amount, to: internalAddress, burn: true, extra: extra)
    }

    func createTransaction(assetModel: AssetModel, amount: Int, to address: String, burn: Bool = false, extra: UInt64 = 0) -> Bool {
        errorCode = nil
        guard let wallet = walletManager.wallet else { errorCode = 1; return false }
        
        addDebug("\ncreateTransaction extra=\(extra) amount=\(amount) address=\(address) burn=\(burn)")
        
        // Clear used utxos array
        usedUtxos = []
        
        // Get all asset utxos that were registered by the wallet
        let utxos = AssetHelper.getAssetUtxos(for: assetModel.assetId)
        
        // Collect all utxos that sum up to our required amount
        var selectedUtxos = [AssetUtxoModel]()
        
        // Sum of all collected Utxos' amount
        var selectedAmountSum: Int = 0
        
        for utxo in utxos {
            var singleSum: Int = 0
            
            // Check if input was registered by wallet
            guard wallet.hasUtxo(txid: utxo.txid, n: utxo.index) else {
                addDebug("Utxo \(utxo.txid):\(utxo.index) not available")
                wallet.printUtxos()
                continue
            }
            
            guard wallet.utxoIsSpendable(txid: utxo.txid, n: utxo.index) else {
                addDebug("Utxo \(utxo.txid):\(utxo.index) already spent")
                continue
            }
            
            utxo.assets.forEach { (infoModel) in
                // Only add amount if it's the amount of the specific asset
                if infoModel.assetId == assetModel.assetId {
                    singleSum += infoModel.amount
                    addDebug("Select Asset Utxo with amount=\(infoModel.amount), TOTAL_FROM_THIS_UTXO=\(singleSum) TOTAL=\(selectedAmountSum)")
                    
                }
            }
            
            // Convert hash to uint256
            selectedUtxos.append(utxo)
            selectedAmountSum += singleSum
            
            // If we reached our amount, stop!
            if selectedAmountSum >= amount { break }
        }
        
        // Remember selected utxos
        usedUtxos = [AssetUtxoModel](selectedUtxos)
        
        // Exit if we don't have the amount
        guard selectedAmountSum >= amount else {
            errorCode = 2
            return false
        }
        
        let TRANSFER_SATOSHIS: UInt64 = 600
        
        // Create a transaction
        // Use two times TRANSFER_SAT amount, one for asset target, one for internal asset change.
        // BRCore will collect the inputs that are necessary to send this amount of satoshis, incl. its fees.
        transaction = walletManager.wallet?.createTransaction(forAmount: 2 * TRANSFER_SATOSHIS + extra, toAddress: address)
        guard let transaction = transaction else {
            errorCode = 3
            return false
        }
        
        if let index = transaction.outputs.firstIndex(where: { $0.amount == 600 }) {
            errorCode = 10
            return false;
        }
        
        // Remember input count
        var transactionInputAmountSum: UInt64 = 0
        for input in transaction.inputs {
            transactionInputAmountSum += input.amount
        }
        
        // Add each utxo as an input to the transaction (in reverse order as we are adding each
        // input to index zero)
        for utxo in selectedUtxos.reversed() {
            guard let hash = utxo.txid.hexToData?.reverse.uInt256 else { errorCode = 4; return false }
            transaction.addInputBefore(txHash: hash, index: UInt32(utxo.index), amount: UInt64(utxo.value), script: utxo.hexAsBuffer())
            addDebug("Adding input before hash=\(hash) index=\(utxo.index) amount=\(utxo.value)")
            transactionInputAmountSum += utxo.value
        }
        
        // Determine (shuffled) output indexes for target and change
        let TARGET_OUTPUT: Int = transaction.outputs.firstIndex { $0.swiftAddress == address }!
        let CHANGE_OUTPUT: Int = TARGET_OUTPUT == 0 ? 1 : 0
        let ASSET_CHANGE_OUTPUT: Int = transaction.outputs.count
        addDebug("TARGET_OUTPUT=\(TARGET_OUTPUT), CHANGE_OUTPUT=\(CHANGE_OUTPUT), ASSET_CHANGE_OUTPUT=\(ASSET_CHANGE_OUTPUT)")
        
        // Create transfer instructions
        var transferInstructions = [UInt8]()
        var amountNeeded = amount
        var needsAssetChange = false
        
        // Loop through all utxos that contain the asset to be sent.
        for i in 0..<selectedUtxos.count {
            let selectedUtxo = selectedUtxos[i]
            
            for a in 0..<selectedUtxo.assets.count {
                let asset = selectedUtxo.assets[a]
                let isLastAssetInUtxo = (a == selectedUtxo.assets.count-1)
                var instruction = [UInt8]()
                
                if burn {
                    // Burn asset(s)
                    if asset.assetId == assetModel.assetId {
                        // This is the asset we want to burn
                        
                        if amountNeeded >= asset.amount, asset.amount != 0 {
                            // burn all assets of this utxo
                            instruction = burnInstruction(skip: isLastAssetInUtxo, amount: asset.amount)
                            amountNeeded -= asset.amount
                        } else {
                            // burn some of these assets
                            instruction = burnInstruction(skip: false, amount: amountNeeded)

                            // and send the rest to the internal wallet address
                            needsAssetChange = true
                            instruction.append(contentsOf: transferInstruction(skip: isLastAssetInUtxo, outputIndex: ASSET_CHANGE_OUTPUT, amount: asset.amount - amountNeeded))
                            
                            amountNeeded = 0
                        }
                    
                    } else {
                        // Skip this asset, somehow
                        needsAssetChange = true
                        instruction = transferInstruction(skip: isLastAssetInUtxo, outputIndex: ASSET_CHANGE_OUTPUT, amount: asset.amount)
                    }
                    
                } else {
                    // Send asset(s)
                    if asset.assetId == assetModel.assetId {
                        // This is the asset we want to send to target address
                        
                        if amountNeeded >= asset.amount, asset.amount != 0 {
                            // Send all asset from input to desired output
                            instruction = transferInstruction(skip: isLastAssetInUtxo, outputIndex: TARGET_OUTPUT, amount: asset.amount)
                            
                            amountNeeded -= asset.amount
                        } else {
                            // Send some of the assets from input to desired output
                            instruction = transferInstruction(skip: false, outputIndex: TARGET_OUTPUT, amount: amountNeeded)

                            // and send the rest to the internal wallet address
                            needsAssetChange = true
                            instruction.append(contentsOf: transferInstruction(skip: isLastAssetInUtxo, outputIndex: ASSET_CHANGE_OUTPUT, amount: asset.amount - amountNeeded))
                            
                            amountNeeded = 0
                        }

                    } else {
                        // Skip this asset, send it to internal wallet address
                        needsAssetChange = true
                        instruction = transferInstruction(skip: isLastAssetInUtxo, outputIndex: ASSET_CHANGE_OUTPUT, amount: asset.amount)
                    }
                }
                
                transferInstructions.append(contentsOf: instruction)
            }
        }
        
        // Exit if we don't have the amount of assets
        guard amountNeeded == 0 else { errorCode = 5; return false }
        
        // Reduce the satoshi amount of the target output.
        // Fees will be recalculated down below.
        transaction.setOutputAmount(index: TARGET_OUTPUT, amount: TRANSFER_SATOSHIS)
        
        // If some assets went to the ASSET_CHANGE_OUTPUT,
        // we need to add this non-existing output now.
        if needsAssetChange {
            // Add another output. We do this by cloning the change_output.
            // The asset change output will have the same destination, but it will
            // just carry the assets and 600 dsats
            let existingOutput = transaction.outputs[CHANGE_OUTPUT]
            let data = Data(bytes: existingOutput.script!, count: existingOutput.scriptLen)
            
            transaction.addOutput(amount: TRANSFER_SATOSHIS, script: Array(data))
        }
        
        // Create OP_RETURN data
        var script = [UInt8]()
        script.append(0x6a) // OP_RETURN
        script.append(0x00) // LEN
        script.append(0x44) // D
        script.append(0x41) // A
        script.append(0x02) // Version
        
        if burn {
            script.append(0x25) // burn (no metadata)
        } else {
            script.append(0x15) // transfer (no metadata)
        }
        
        // Instructions
        script.append(contentsOf: transferInstructions)
        
        // Update LEN
        script[1] = UInt8(script.count - 2)
        
        // Add the new output
        transaction.addOutput(amount: 0, script: script)
        
        // Recalc transaction fee with updated inputs / outputs.
        // Due to the added data the transaction size has grown, so the fee should have updated.
        let costs = 2 * TRANSFER_SATOSHIS + transaction.standardFee
        
        if transactionInputAmountSum >= costs {
            // Enough input balance to readjust the fee
            transaction.setOutputAmount(index: CHANGE_OUTPUT, amount: transactionInputAmountSum - costs)
        } else {
            // Recall this method, and ask for more inputs
            guard extra == 0 else {
                errorCode = 6
                return false
            }
            
            errorCode = 0
            let success = createTransaction(assetModel: assetModel, amount: amount, to: address, extra: costs - transactionInputAmountSum)
            return success
        }
        
        return true
    }
    
    private func invalidate() {
        usedUtxos.forEach { utxo in
            AssetHelper.invalidateUtxos(with: utxo.txid, index: utxo.index)
        }
        
        usedUtxos = []
    }
    
    private func addDebug(_ str: String) {
        GlobalDebug.default.add(str)
        print(str)
    }
    
    // Only supports v2
    private func transferInstruction(skip: Bool, range: Bool = false, percent: Bool = false, outputIndex: Int, amount: Int) -> [UInt8] {
        
        if amount == 0 {
            addDebug("tx-instruction skip instruction outputIndex=\(outputIndex)")
            return []
        }
        
        addDebug("tx-instruction skip=\(skip) range=\(range) percent=\(percent) outputIndex=\(outputIndex) amount=\(amount)")
        
        var ret = [UInt8]()
        ret.append(UInt8(outputIndex))
        
        // These are correct as long as ret.length == 1.
        if skip { ret[0] |= 0x80 }
        // if range { ret[0] |= 0x40 }
        // if percent { ret[0] |= 0x20 }
        
        ret.append(contentsOf: sffcEncoder.format(amount: amount))
        
        return ret
    }
    
    private func burnInstruction(skip: Bool, percent: Bool = false, amount: Int) -> [UInt8] {
        let outputIndex = 0x1F // burn output
        return transferInstruction(skip: skip, range: false, outputIndex: outputIndex, amount: amount)
    }

    var fee: UInt64 {
        guard let tx = transaction else { return 0 }
        return walletManager.wallet?.feeForTx(tx) ?? 0
    }

    var canUseBiometrics: Bool {
        guard let tx = transaction else  { return false }
        return walletManager.canUseBiometrics(forTx: tx)
    }

    func feeForTx(amount: UInt64) -> UInt64 {
        return walletManager.wallet?.feeForTx(amount:amount) ?? 0
    }
    
    func feeForTx(amount: UInt64, force: Bool = false) -> UInt64 {
        return walletManager.wallet?.feeForTx(amount:amount) ?? 0
    }

    //Amount in bits
    func send(biometricsMessage: String, rate: Rate?, feePerKb: UInt64, verifyPinFunction: @escaping (@escaping(String) -> Bool) -> Void, completion:@escaping (SendResult) -> Void) {
        guard let tx = transaction else { return completion(.creationError(S.Send.createTransactionError, errorCode)) }

        self.rate = rate
        self.feePerKb = feePerKb

        if UserDefaults.isBiometricsEnabled && walletManager.canUseBiometrics(forTx: tx) {
            DispatchQueue.walletQueue.async { [weak self] in
                guard let myself = self else { return }
                myself.walletManager.signTransaction(tx, biometricsPrompt: biometricsMessage, completion: { result in
                    
                    myself.addDebug(tx.debugDescription)
                    
                    if result == .success {
                        myself.publish(completion: completion)
                    } else {
                        if result == .failure || result == .fallback {
                            myself.verifyPin(tx: tx, withFunction: verifyPinFunction, completion: completion)
                        }
                    }
                })
            }
        } else {
            self.verifyPin(tx: tx, withFunction: verifyPinFunction, completion: completion)
        }
    }

    private func verifyPin(tx: BRTxRef, withFunction: (@escaping(String) -> Bool) -> Void, completion:@escaping (SendResult) -> Void) {
        withFunction({ pin in
            var success = false
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.walletQueue.async {
                if self.walletManager.signTransaction(tx, pin: pin) {
                    self.addDebug(tx.debugDescription)
                    self.publish(completion: completion)
                    success = true
                }
                group.leave()
            }
            let result = group.wait(timeout: .now() + 30.0)
            if result == .timedOut {
                let alert = AlertController(title: S.Alert.error, message: S.Transaction.signTimeout, preferredStyle: .alert)
                alert.addAction(AlertAction(title: S.Alerts.defaultConfirmOkCaption, style: .default, handler: nil))
                self.topViewController?.present(alert, animated: true, completion: nil)
                return false
            }
            return success
        })
    }

    //TODO - remove this -- only temporary for testing
    private var topViewController: UIViewController? {
        var viewController = UIApplication.shared.keyWindow?.rootViewController
        while viewController?.presentedViewController != nil {
            viewController = viewController?.presentedViewController
        }
        return viewController
    }

    private func publish(completion: @escaping (SendResult) -> Void) {
        guard let tx = transaction else { assert(false, "publish failure"); return }
        DispatchQueue.walletQueue.async { [weak self] in
            guard let myself = self else { assert(false, "myelf didn't exist"); return }
            myself.walletManager.peerManager?.publishTx(tx, completion: { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(.publishFailure(error))
                    } else {
                        completion(.success)
                    }
                }
            })
        }
    }
}
