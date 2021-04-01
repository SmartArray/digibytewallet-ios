//
//  AssetHelper.swift
//  DigiByte
//
//  Created by Yoshi Jaeger on 01.12.19.
//  Copyright © 2019 DigiByte Foundation NZ Limited. All rights reserved.
//

import Foundation
import Storez

// http://api.digiassets.net/assetmetadata/Ua4MneDXdFP8eNEiN1fzJE8AjfuJ5RU3bBuRvq/00419a512d02265013d127baba6749798603b33604a53c878ed90692637be1a0:0

// https://forums.swift.org/t/using-unsafe-pointers-to-manipulate-a-json-encoder/11013/6
public enum JSON : Codable {
    case null
    case number(NSNumber)
    case string(String)
    case array([JSON])
    case dictionary([String : JSON])
    
    public var value: Any? {
        switch self {
        case .null: return nil
        case .number(let number): return number
        case .string(let string): return string
        case .array(let array): return array.map { $0.value }
        case .dictionary(let dictionary): return dictionary.mapValues { $0.value }
        }
    }
    
    public init?(_ value: Any?) {
        guard let value = value else {
            self = .null
            return
        }
        
        if let int = value as? Int {
            self = .number(NSNumber(value: int))
        } else if let double = value as? Double {
            self = .number(NSNumber(value: double))
        } else if let string = value as? String {
            self = .string(string)
        } else if let array = value as? [Any] {
            var mapped = [JSON]()
            for inner in array {
                guard let inner = JSON(inner) else {
                    return nil
                }
                
                mapped.append(inner)
            }
            
            self = .array(mapped)
        } else if let dictionary = value as? [String : Any] {
            var mapped = [String : JSON]()
            for (key, inner) in dictionary {
                guard let inner = JSON(inner) else {
                    return nil
                }
                
                mapped[key] = inner
            }
            
            self = .dictionary(mapped)
        } else {
            return nil
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard !container.decodeNil() else {
            self = .null
            return
        }
        
        if let int = try container.decodeIfMatched(Int.self) {
            self = .number(NSNumber(value: int))
        } else if let double = try container.decodeIfMatched(Double.self) {
            self = .number(NSNumber(value: double))
        } else if let string = try container.decodeIfMatched(String.self) {
            self = .string(string)
        } else if let array = try container.decodeIfMatched([JSON].self) {
            self = .array(array)
        } else if let dictionary = try container.decodeIfMatched([String : JSON].self) {
            self = .dictionary(dictionary)
        } else {
            throw DecodingError.typeMismatch(JSON.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode JSON as any of the possible types."))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
            case .null: try container.encodeNil()
            case .number(let number):
                if number.objCType.pointee == 0x64 /* 'd' */ {
                    try container.encode(number.doubleValue)
                } else {
                    try container.encode(number.intValue)
                }
            case .string(let string): try container.encode(string)
            case .array(let array): try container.encode(array)
            case .dictionary(let dictionary): try container.encode(dictionary)
        }
    }
}

fileprivate extension SingleValueDecodingContainer {
    func decodeIfMatched<T : Decodable>(_ type: T.Type) throws -> T? {
        do {
            return try self.decode(T.self)
        } catch DecodingError.typeMismatch {
            return nil
        }
    }
}

struct ScriptSigModel: Codable {
//    let asm: String
    let hex: String
    let addresses: [String]?
}

struct AssetProperties: Codable {
    let assetName: String?
    let issuer: String?
    let description: String?
    let urls: [UrlModel]?
    let userData: JSON?
}

struct UrlModel: Codable {
    let name: String?
    let url: String?
    let mimeType: String?
    let dataHash: String?
}

struct AssetIssuanceMetadataModel: Codable {
    let data: AssetProperties?
}

struct AssetModel: Codable {
    let assetId: String
    let firstBlock: Int
//    let someUtxo: String
    
    let divisibility: Int
    let aggregationPolicy: String
    let lockStatus: Bool
    let numOfIssuance: Int
    let numOfTransfers: Int
    let totalSupply: Int?
    let numOfHolders: Int?
    
    let issuanceTxid: String?
    let issueAddress: String?
    let metadataOfIssuence: AssetIssuanceMetadataModel?
    
    let sha2Issue: String?
    
    func getAssetInfo(separator: String = ", ") -> String {
        var res = [String]()
        
        res.append("\(S.Assets.totalSupply): \(totalSupply ?? 0)")
        res.append("\(S.Assets.numberOfHolders): \(numOfHolders ?? 0)")
        res.append("\(S.Assets.lockStatus): \(lockStatus ? S.Assets.locked : S.Assets.unlocked)")
        
        return res.joined(separator: separator)
    }
    
    func getIssuer() -> String {
        guard let meta = metadataOfIssuence else { return S.Assets.unknown }
        guard let data = meta.data else { return S.Assets.unknown }
        return data.issuer ?? S.Assets.unknown
    }
    
    func getAssetName() -> String {
        guard let meta = metadataOfIssuence else { return S.Assets.unknown }
        guard let data = meta.data else { return S.Assets.unknown }
        return data.assetName ?? S.Assets.unknown
    }
    
    func getImage() -> UrlModel? {
        guard let urls = getURLs() else { return nil }
        if let index = urls.firstIndex(where: { $0.name == "icon" }) {
            return urls[index]
        } else if let index = urls.firstIndex(where: { $0.name == "large_icon" }) {
            return urls[index]
        } else {
            return nil
        }
    }
    
    func getVideoUrl() -> UrlModel? {
        guard let urls = getURLs() else { return nil }
        if let index = urls.firstIndex(where: { $0.name == "video" }) {
            return urls[index]
        }
        
        return nil
    }
    
    func getBigImage() -> UrlModel? {
        guard let urls = getURLs() else { return nil }
        if let index = urls.firstIndex(where: { $0.name == "large_icon" }) {
            return urls[index]
        } else if let index = urls.firstIndex(where: { $0.name == "icon" }) {
            return urls[index]
        } else {
            return nil
        }
    }
    
    func getDescription() -> String? {
        guard let meta = metadataOfIssuence else { return nil }
        guard let data = meta.data else { return nil }
        return data.description
    }
    
    private func getURLs() -> [UrlModel]? {
        guard let meta = metadataOfIssuence else { return nil }
        guard let data = meta.data else { return nil }
        guard let urls = data.urls else { return nil }
        return urls
    }
    
    static func dummy() -> AssetModel {
        return AssetModel(assetId: "?", firstBlock: 0, divisibility: 0, aggregationPolicy: "?", lockStatus: false, numOfIssuance: 0, numOfTransfers: 0, totalSupply: 0, numOfHolders: 0, issuanceTxid: nil, issueAddress: nil, metadataOfIssuence: nil, sha2Issue: nil)
    }
}

struct AssetHeaderModel: Codable {
    let assetId: String
    let amount: Int
    let issueTxid: String
    let divisibility: Int
    let lockStatus: Bool
    let aggregationPolicy: String
}

struct PreviousOutputModel: Codable {
    let hex: String
    let type: String
    let reqSigs: Int
    let addresses: [String]
}

struct TransactionInputModel: Codable {
    let txid: String
    let vout: Int
    let scriptSig: ScriptSigModel
    let value: UInt64? // Satoshis
    let sequence: Int
    
    let previousOutput: PreviousOutputModel?
    
    let assets: [AssetHeaderModel]
}

struct TransactionOutputModel: Codable {
    let n: Int
    let used: Bool
    let usedTxid: String?
    let usedBlockheight: Int?
    
    let value: UInt64 // Satoshis
    
    let scriptPubKey: ScriptSigModel
    let assets: [AssetHeaderModel]
    
    func wasUsed() -> TransactionOutputModel {
        return TransactionOutputModel(n: n, used: true, usedTxid: usedTxid, usedBlockheight: usedBlockheight, value: value, scriptPubKey: scriptPubKey, assets: assets)
    }
}

// Same as the above but with an additional txid field
struct ExtendedTransactionOutputModel: Codable {
    let base: TransactionOutputModel
    let txid: String
    
    init(_ o: TransactionOutputModel, txid: String) {
        self.base = o
        self.txid = txid
    }
    
    // Helper functions
    func hexAsBuffer() -> [UInt8] {
        return [UInt8](Data(hex: base.scriptPubKey.hex))
    }
    
    // Computed properties (access layer)
    var assets: [AssetHeaderModel] { return base.assets }
    var index: Int { return base.n }
    var value: UInt64 { return base.value }
    
    func getAssetIds() -> [String] {
        return base.assets.map { $0.assetId }
    }
}

typealias AssetUtxoModel = ExtendedTransactionOutputModel

struct Payment: Codable {
    let burn: Bool?
    let amount: Int
    let input: Int
}

struct DaData: Codable {
    let type: String
    let payments: [Payment]?
}

struct TransactionInfoModel: Codable {
    let blockheight: Int
    let blockhash: String?
    let txid: String
    let dadata: [DaData]?
    
    let colored: Bool
    
    let vin: [TransactionInputModel]
    var vout: [TransactionOutputModel]
    
    var temporary: Bool? = false
    
    func getAssetIds() -> [String] {
        var res = Set<String>()
        
        vin.forEach { inputModel in
            inputModel.assets.forEach { (assetModel) in res.insert(assetModel.assetId) }
        }
        
        vout.forEach { outputModel in
            outputModel.assets.forEach { (assetModel) in res.insert(assetModel.assetId) }
        }
        
        return Array(res)
    }
    
    // Returns input for a specific
    func getBurnAmount(input: Int) -> Int? {
        guard let dadata = dadata else { return nil }
        // ToDo: Loop through all indexes
        guard let index = dadata.firstIndex(where: { $0.type == "burn" }) else { return nil }
        guard let payments = dadata[index].payments else { return nil }
        
        guard
            let burnIndex = payments.firstIndex(where: { $0.input == input && $0.burn == true })
        else {
            return nil
        }
        
        let payment = payments[burnIndex]
        return payment.amount
    }
    
    func getAssets() -> [AssetHeaderModel] {
        var assets = [AssetHeaderModel]()
        vout.forEach { v in
            assets.append(contentsOf: v.assets)
        }
        return assets
    }
}

class DigiAssetsUrlWrapper {
    private static let DA_EXPLORER_HOST1: String = "https://explorerapi.digiassets.net/api"
    private static let DA_API_HOST1: String = "https://api.digiassets.net/v3"
    
    private var explorer_urls: [String] = [
        DigiAssetsUrlWrapper.DA_EXPLORER_HOST1,
    ]
    
    private var api_urls: [String] = [
        DigiAssetsUrlWrapper.DA_API_HOST1
    ]
    
    var currentExplorerURL: String = ""
    var currentApiURL: String = ""
    
    init() {
        assert(explorer_urls.count > 0)
        assert(api_urls.count > 0)
        self.currentExplorerURL = explorer_urls[0]
        self.currentApiURL = api_urls[0]
    }
    
    func nextExplorerUrl(oldURL: String) {
        // Change will be seen by all operations.
        // Change will be dependant on the old URL
        guard oldURL == currentExplorerURL else { return }
        guard let index = explorer_urls.firstIndex(of: oldURL) else { return }
        let newIndex = index + 1
        currentExplorerURL = explorer_urls[newIndex % explorer_urls.count]
    }
    
    func nextApiUrl(oldURL: String) {
        // Change will be seen by all operations.
        // Change will be dependant on the old URL
        guard oldURL == currentApiURL else { return }
        guard let index = api_urls.firstIndex(of: oldURL) else { return }
        let newIndex = index + 1
        currentApiURL = api_urls[newIndex % api_urls.count]
    }
}

class FetchAssetTransactionOperation: Operation {
    private let state: AssetResolver.AssetResolveState
    private let urlWrapper: DigiAssetsUrlWrapper
    
    init(url: DigiAssetsUrlWrapper, state: AssetResolver.AssetResolveState) {
        self.urlWrapper = url
        self.state = state
    }
    
    override var isAsynchronous: Bool {
        return true
    }
    
    var _isFinished: Bool = false
    var _isExecuting: Bool = false
    
    override var isFinished: Bool {
        set {
            if newValue {
                self.finished()
            }
            willChangeValue(forKey: "isFinished")
            _isFinished = newValue
            didChangeValue(forKey: "isFinished")
        }
        
        get {
            return _isFinished
        }
    }
    
    override var isExecuting: Bool {
        set {
            willChangeValue(forKey: "isExecuting")
            _isExecuting = newValue
            didChangeValue(forKey: "isExecuting")
        }
        
        get {
            return _isExecuting
        }
    }
    
    func finished() {
        DispatchQueue.main.async {
            self.state.progress.current = self.state.progress.current + 1
            AssetNotificationCenter.instance.post(name: AssetNotificationCenter.notifications.updateProgress, object: nil, userInfo: self.state.progress.getUserInfo())
        }
    }
    
    func execute() {
        let session = URLSession.shared
        let urlStr = urlWrapper.currentExplorerURL
        
        let composedURLStr = "\(urlStr)/gettransaction?txid=\(state.txID)"
        let url = URL(string: composedURLStr)!
        
        GlobalDebug.default.add(url.absoluteString)
        
        let dataTask = session.dataTask(with: url) { (data, resp, err) in
            if err != nil {
                self.urlWrapper.nextExplorerUrl(oldURL: urlStr)
                self.isExecuting = false
                self.isFinished = true
                self.state.failed = true
                return
            }
            
            guard let data = data else {
                self.isExecuting = false
                self.isFinished = true
                self.state.failed = true
                return
            }
            
            var infoModel: TransactionInfoModel!
            do {
                infoModel = try JSONDecoder().decode(TransactionInfoModel.self, from: data)
            } catch let error {
                GlobalDebug.default.add("\(error)")
                self.isExecuting = false
                self.isFinished = true
                return
            }
            
            self.state.transactionInfoModel = infoModel
            
            // Create new sub operation queue
            let subqueue = OperationQueue()
            subqueue.maxConcurrentOperationCount = 3
            
            // Process assets of each output
            var assetDict = [String:Int]()
            infoModel.vout.forEach { o in
                o.assets.forEach { assetModel in
                    let assetId = assetModel.assetId
                    
                    // Only resolve each assetModel once
                    let key = "\(assetId)-\(infoModel.txid)"
                    if assetDict.index(forKey: key) == nil {
                        GlobalDebug.default.add("AssetResolver: Adding MetadataOperation for \(assetId) (txID = \(infoModel.txid):\(o.n))")
                        assetDict[key] = 1
                        
                        let subOperation = FetchMetadataOperation(url: self.urlWrapper, state: self.state, assetID: assetId, txID: infoModel.txid, index: o.n)
                        subqueue.addOperation(subOperation)
                    }
                }
            }
            
            infoModel.vin.forEach { i in
                i.assets.forEach { assetModel in
                    let assetId = assetModel.assetId
                    
                    // Only resolve each assetModel once
                    let key = "\(assetId)-\(infoModel.txid)"
                    if assetDict.index(forKey: key) == nil {
                        GlobalDebug.default.add("AssetResolver: Adding MetadataOperation for \(assetId) (txID = \(i.txid):\(i.vout))")
                        assetDict[key] = 1
                        
                        let subOperation = FetchMetadataOperation(url: self.urlWrapper, state: self.state, assetID: assetId, txID: i.txid, index: i.vout)
                        subqueue.addOperation(subOperation)
                    }
                }
            }
            
            if subqueue.operationCount == 0 { self.state.resolved = true }
            subqueue.waitUntilAllOperationsAreFinished()
            GlobalDebug.default.add("AssetResolver: Finished FetchAssetTransactionOperation for txID=\(self.state.txID)")
            self.isExecuting = false
            self.isFinished = true
        }
        
        dataTask.resume()
    }
    
    override func start() {
        isExecuting = true
        execute()
    }
}

class FetchMetadataOperation: Operation {
    private let state: AssetResolver.AssetResolveState
    private let urlWrapper: DigiAssetsUrlWrapper
    
    private let assetID: String
    private let txID: String
    private let index: Int
    
    init(url: DigiAssetsUrlWrapper, state: AssetResolver.AssetResolveState, assetID: String, txID: String, index: Int) {
        self.urlWrapper = url
        self.state = state
        
        self.assetID = assetID
        self.txID = txID
        self.index = index
    }
    
    override var isAsynchronous: Bool { return true }
    var _isFinished: Bool = false
    var _isExecuting: Bool = false
    
    override var isFinished: Bool {
        set {
            willChangeValue(forKey: "isFinished")
            _isFinished = newValue
            didChangeValue(forKey: "isFinished")
        }
        
        get { return _isFinished }
    }
    
    override var isExecuting: Bool {
        set {
            willChangeValue(forKey: "isExecuting")
            _isExecuting = newValue
            didChangeValue(forKey: "isExecuting")
        }
        
        get { return _isExecuting }
    }
    
    func execute() {
        let session = URLSession(configuration: .default)
        let urlStr = urlWrapper.currentApiURL
        
        let url = URL(string: "\(urlStr)/assetmetadata/\(self.assetID)/\(self.txID):\(self.index)")!
        GlobalDebug.default.add(url.absoluteString)
        
        let dataTask = session.dataTask(with: url) { (data, resp, err) in
            if err != nil {
                GlobalDebug.default.add("AssetResolver: error in response for asset: \(self.assetID): \(err!)")
                self.urlWrapper.nextApiUrl(oldURL: urlStr)
                self.isExecuting = false
                self.isFinished = true
                self.state.failed = true
                return
            }
            
            guard let data = data else {
                GlobalDebug.default.add("AssetResolver: No data in response for asset: \(self.assetID)")
                self.isExecuting = false
                self.isFinished = true
                self.state.failed = true
                return
            }
                
            do {
                let decodedAssetModel = try JSONDecoder().decode(AssetModel.self, from: data)
                self.state.resolvedModels.append(decodedAssetModel)
                GlobalDebug.default.add("AssetResolver: resolved assetModel: \(decodedAssetModel.assetId)")
                
                self.state.failed = false
                self.state.resolved = true
            } catch {
                GlobalDebug.default.add("AssetResolver: could not resolve asset: \(self.assetID)/\(self.txID):\(self.index). Error message = \(error)")
                self.state.failed = true
            }
            
            self.isExecuting = false
            self.isFinished = true
        }
        
        dataTask.resume()
    }
    
    override func start() {
        guard !state.failed, state.transactionInfoModel != nil else {
            GlobalDebug.default.add("AssetResolver: FetchMetadataOperation for assetID=\(assetID), txID=\(txID):\(index) can not be launched")
            isFinished = true
            return
        }
        
        isExecuting = true
        execute()
    }
}

class AssetResolver {
    private var txIDSet = Set<String>()
    private let txIDs: [String]
    private let callback: ([AssetResolveState]) -> Void
    private let queue = OperationQueue()
    
    class ProgressState {
        var current: Int = 0
        var total: Int = 0
        
        func getUserInfo() -> [String: Int] {
            var ret = [String: Int]()
            ret["current"] = current
            ret["total"] = total
            return ret
        }
    }
    
    class AssetResolveState {
        var txID: String
        var resolved: Bool = false
        var failed: Bool = false
        
        let progress: ProgressState
        
        var transactionInfoModel: TransactionInfoModel? = nil
        var resolvedModels: [AssetModel] = []
        
        init(txid: String, progressState: ProgressState) {
            self.txID = txid
            self.progress = progressState
        }
    }
    
    var states = [AssetResolveState]()
    var stateMap = [String: AssetResolveState]()
    var progress = ProgressState()
    
    init(txids: [String], callback: @escaping ([AssetResolveState]) -> Void) {
        self.callback = callback
        self.txIDs = txids
        
        txids.filter({ $0 != "" }).forEach({
            self.txIDSet.insert($0)
        })

        states.reserveCapacity(self.txIDSet.count)
        self.txIDSet.forEach { (txid) in
            let state = AssetResolveState(txid: txid, progressState: progress)
            states.append(state)
            stateMap[txid] = state
        }
        
        configureQueue()
        launchFetchers()
    }
    
    func cancel() {
        queue.cancelAllOperations()
    }
    
    private func configureQueue() {
        queue.maxConcurrentOperationCount = 5
    }
    
    private func launchFetchers() {
        let urlWrapper = DigiAssetsUrlWrapper()
            
        let completionOperation = BlockOperation {
            GlobalDebug.default.add("AssetResolver: All operations completed")
            self.callback(self.states)
        }
        
        progress.total = self.txIDSet.count
        AssetNotificationCenter.instance.post(name: AssetNotificationCenter.notifications.updateProgress, object: nil, userInfo: progress.getUserInfo())
        
        for txid in self.txIDSet {
            let state = self.stateMap[txid]!
            GlobalDebug.default.add("AssetResolver: Launching FetchAssetTransactionOperation for txid = \(txid)")
            let fetchAssetTransactionOperation = FetchAssetTransactionOperation(url: urlWrapper, state: state)
            completionOperation.addDependency(fetchAssetTransactionOperation)
            queue.addOperation(fetchAssetTransactionOperation)
        }

        queue.addOperation(completionOperation)
    }
}

class AssetNotificationCenter {
    static let instance = NotificationCenter()
    
    enum notifications {
        static let newAssetData = Notification.Name("newAssetData")
        static let fetchingAssets = Notification.Name("fetchingAssets")
        static let updateProgress = Notification.Name("updateProgress")
        static let fetchedAssets = Notification.Name("fetchedAssets")
        static let assetsRecalculated = Notification.Name("assetsRecalculated")
        static let assetTxSelected = Notification.Name("assetTxSelected")
    }
    
    private init() {}
}

class AssetHelper {
    typealias AssetBalance = Int
    private static let store = UserDefaultsStore(suite: "AssetHelper")
    
    private static var needsReindex = true
    private static var _allAssets = [String]()
    private static var _allBalances = [String: AssetBalance]()
    static var allBalances: [String: AssetBalance] {
        reindexAssetsIfNeeded()
        return _allBalances
    }
    static var allAssets: [String] {
        reindexAssetsIfNeeded()
        return _allAssets
    }
    
    static var assetWasNotSpentCallback: ((String, Int) -> Bool) = { (_, _) in
        assert(false) // Not assigned
        return false
    }
    
    private static var assetTxIdList = pullAssetTransactionIds()
    private static var needsTxIdListUpdate: Bool = false
    private static var assetAddressListKey = "da_allAddresses"
    
    private static func reindexAssetsIfNeeded() {
        guard needsReindex else { return }
        _allAssets = []
        _allBalances = [:]
        
        assetTxIdList.forEach { (txid) in
            guard let infoModel = getTransactionInfoModel(txid: txid) else { return }
            
            infoModel.vout.forEach { model in
                guard !model.used else {
                    GlobalDebug.default.add("Not adding \(infoModel.txid):\(model.n) to balance because it was already spent")
                    return
                }
                model.assets.forEach { assetModel in
                    guard let addresses = model.scriptPubKey.addresses else { return }
                    
                    // Assuming one address
                    guard addresses.count == 1 else { return }
                    
                    let address = addresses[0]
                    
                    // Check if address is part of wallet
                    if assetWasNotSpentCallback(infoModel.txid, model.n) {
                        _allBalances[assetModel.assetId] = (_allBalances[assetModel.assetId] ?? 0) + assetModel.amount
                    }
                }
            }
        }
        
        _allAssets = _allBalances.keys.map({ return $0 })
        needsReindex = false
        
        AssetNotificationCenter.instance.post(name: AssetNotificationCenter.notifications.assetsRecalculated, object: nil)
    }
    
    private static func pullAssetTransactionIds() -> [String] {
        let key = Key<GlobalNamespace, [String]>(id: assetAddressListKey, defaultValue: [])
        let ret: [String] = store.get(key)
        return ret
    }
    
    private static func putAssetAddressList() {
        let key = Key<GlobalNamespace, [String]>(id: assetAddressListKey, defaultValue: [])
        store.set(key, value: assetTxIdList)
        needsTxIdListUpdate = false
    }
    
    static func getAssetModel(assetID: String) -> AssetModel? {
        // ToDo: build and check cache
        let key = Key<GlobalNamespace, AssetModel?>(id: assetID, defaultValue: nil)
        return store.get(key)
    }
    
    static func getTransactionInfoModel(txid: String) -> TransactionInfoModel? {
        let key = Key<GlobalNamespace, TransactionInfoModel?>(id: txid, defaultValue: nil)
        return store.get(key)
    }
    
    static func saveAssetModel(assetModel: AssetModel) {
        let key = Key<GlobalNamespace, AssetModel?>(id: assetModel.assetId, defaultValue: nil)
        store.set(key, value: assetModel)
        needsReindex = true
    }
    
    static func saveAssetTransactionModel(assetTransactionModel: TransactionInfoModel) {
        let id = assetTransactionModel.txid
        
        if !assetTxIdList.contains(id) {
            assetTxIdList.append(id)
            needsTxIdListUpdate = true
        }
        
        let key = Key<GlobalNamespace, TransactionInfoModel?>(id: id, defaultValue: nil)
        store.set(key, value: assetTransactionModel)
        needsReindex = true
    }
    
    
    static func getAssetUtxos(for assetID: String) -> [ExtendedTransactionOutputModel] {
        var result = [ExtendedTransactionOutputModel]()
        for txid in assetTxIdList {
            guard let model = getTransactionInfoModel(txid: txid) else { continue }
            model.vout.forEach { utxo in
                if utxo.assets.contains(where: { $0.assetId == assetID }) {
                    result.append(ExtendedTransactionOutputModel(utxo, txid: txid))
                }
            }
        }
        
        return result
    }
    
    static func getAssetUtxos(for tx: Transaction) -> [ExtendedTransactionOutputModel]? {
        let txHash = tx.hash
        
        guard let model = getTransactionInfoModel(txid: txHash) else { return nil }
        return model.vout.map { ExtendedTransactionOutputModel($0, txid: txHash) }
    }
    
    static func resolvedAllAssets(for txs: [Transaction]) -> Bool {
        var hasAll: Bool = true
        txs.forEach { tx in
            guard tx.isAssetTx else { return }
            guard hasAll else { return }
            
            guard let infoModel = getTransactionInfoModel(txid: tx.hash) else {
                hasAll = false
                return
            }
            
            guard hasAllAssetModels(for: infoModel.getAssetIds()) else {
                hasAll = false
                return
            }
            
            guard infoModel.temporary != true else {
                hasAll = false
                return
            }
        }
        
        return hasAll
    }
    
    static func hasAllAssetModels(for infoModel: ExtendedTransactionOutputModel) -> Bool {
        return hasAllAssetModels(for: infoModel.getAssetIds())
    }
    
    static func hasAllAssetModels(for assetIds: [String]) -> Bool {
        return assetIds.reduce(true) { (res, id) -> Bool in
            return getAssetModel(assetID: id) != nil
        }
    }
    
    static func invalidateUtxos(with txid: String, index: Int) {
        var changed: Bool = false
        guard var model = getTransactionInfoModel(txid: txid) else { return }
        
        model.vout = model.vout.map({ utxo -> TransactionOutputModel in
            guard utxo.n == index else { return utxo }
            changed = true
            return utxo.wasUsed()
        })
        
        if changed {
            saveAssetTransactionModel(assetTransactionModel: model)
        }
        
        if needsTxIdListUpdate {
            putAssetAddressList()
        }
        
        // Should be triggered by saveAddressInfoModel already
        needsReindex = true
    }
    
    static func resolveAssetTransaction(for txids: [String], callback: (([TransactionInfoModel]) -> Void)?) -> AssetResolver? {
        AssetNotificationCenter.instance.post(name: AssetNotificationCenter.notifications.fetchingAssets, object: nil)
        
        var filtered = txids.filter { (txid) -> Bool in
            guard let infoModel = self.getTransactionInfoModel(txid: txid) else { return true }
            return (infoModel.temporary == true)
        }
        
        if filtered.count == 0 {
            // Workaround: If all transaction info models already exist, refetch!
            filtered = txids
        }
        
        return AssetResolver(txids: filtered) { states in
            states.forEach { state in
                guard state.resolved, !state.failed else { return }
                state.resolvedModels.forEach({ saveAssetModel(assetModel: $0) })
                saveAssetTransactionModel(assetTransactionModel: state.transactionInfoModel!)
            }
            
            if needsTxIdListUpdate {
                putAssetAddressList()
            }

            var relevantItems = [TransactionInfoModel]()

            states.forEach { state in
                // Only add resolved assets
                guard state.resolved, !state.failed else { return }
                guard let infoModel = state.transactionInfoModel else { return }
                relevantItems.append(infoModel)
            }

            DispatchQueue.main.async {
                AssetNotificationCenter.instance.post(name: AssetNotificationCenter.notifications.newAssetData, object: nil)
                AssetNotificationCenter.instance.post(name: AssetNotificationCenter.notifications.fetchedAssets, object: nil)
                callback?(relevantItems)
            }
        }
    }

    
    static func resolveAssetTransaction(for tx: Transaction, callback: (([TransactionInfoModel]) -> Void)?) -> AssetResolver? {
        return resolveAssetTransaction(for: [tx.hash], callback: callback)
    }
    
    enum Operation {
        case send
        case burn
    }
    
    static func createTemporaryAssetModel(for txid: String, mode: Operation, assetModel: AssetModel, amount: Int, to: String) {
        if self.getTransactionInfoModel(txid: txid) != nil { return }
        
        var dadata: [DaData]? = nil
        if mode == .burn {
            let payment = Payment(burn: true, amount: amount, input: 0)
            let burnData = DaData(type: "burn", payments: [payment])
            dadata = [burnData]
        }
        
        let headerModels = AssetHeaderModel(assetId: assetModel.assetId, amount: amount, issueTxid: assetModel.issuanceTxid ?? "", divisibility: assetModel.divisibility, lockStatus: assetModel.lockStatus, aggregationPolicy: assetModel.aggregationPolicy)
        
        let output = TransactionOutputModel(n: 0, used: false, usedTxid: nil, usedBlockheight: nil, value: 0, scriptPubKey: ScriptSigModel(hex: "", addresses: [to]), assets: [headerModels])
        
        var newModel = TransactionInfoModel(blockheight: -1, blockhash: nil, txid: txid, dadata: dadata, colored: true, vin: [], vout: [output])
        newModel.temporary = true
        
        self.saveAssetTransactionModel(assetTransactionModel: newModel)
        
        AssetNotificationCenter.instance.post(name: AssetNotificationCenter.notifications.newAssetData, object: nil)
    }
    
    static func reset() {
        store.clear()
        
        assetTxIdList = []
        _allBalances = [:]
        _allAssets = []
        
        AssetNotificationCenter.instance.post(name: AssetNotificationCenter.notifications.newAssetData, object: nil)
    }
}
