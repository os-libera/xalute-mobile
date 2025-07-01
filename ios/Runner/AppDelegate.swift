import UIKit
import os.log
import Flutter
import HealthKit

//ecg_date_{normal, abnormal}.{json/txt}
typealias ISODateString = String
struct ECGUploadResult: Codable {
    let date: ISODateString
    let prediction: String
}

enum Storage {
    //appData/Documents acess
    static var docs: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    static let resultsURL = docs.appendingPathComponent("ecg_results.json")
    static let lastDateURL = docs.appendingPathComponent("ecg_lastDate.json")
    static func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    //save ecg_results.json
    static func saveResults(_ results: [ECGUploadResult]) throws {
        let data = try JSONEncoder().encode(results)
        try data.write(to: resultsURL)
    }

    //ecg_lastDate.json (ISO8601, fractional seconds)
    static func saveLastDate(_ date: Date) throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso = formatter.string(from: date)
        let data = try JSONEncoder().encode(iso)
        try data.write(to: lastDateURL)
    }

    //last date check if don't exist, return nil
    static func loadLastDate() throws -> Date? {
        guard fileExists(at: lastDateURL) else { return nil }
        let data = try Data(contentsOf: lastDateURL)
        let iso = try JSONDecoder().decode(ISODateString.self, from: data)
        let fracFormatter = ISO8601DateFormatter()
        fracFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fracFormatter.date(from: iso) {
            return date
        }
        return ISO8601DateFormatter().date(from: iso)
    }

    // ecg_result.json load
    static func loadResults() throws -> [ECGUploadResult]? {
        guard fileExists(at: resultsURL) else { return nil }
        let data = try Data(contentsOf: resultsURL)
        return try JSONDecoder().decode([ECGUploadResult].self, from: data)
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let healthStore = HKHealthStore()
    private var methodChannel: FlutterMethodChannel?
    private let predictURL = URL(string: "http://34.69.44.173:7000/predict_single_lead")!
    private let addDataURL = URL(string: "http://34.121.231.99:3000/mutation/addData")!
    private var lastFetchDate: Date?
    private var savedResults: [ECGUploadResult] = []
    private let targetFs: Double = 512.0

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        //os_log("resultsURL: %{public}@ exists: %{public}@", type: .info,
               //Storage.resultsURL.path, Storage.fileExists(at: Storage.resultsURL).description)
        //os_log("lastDateURL: %{public}@ exists: %{public}@", type: .info,
               //Storage.lastDateURL.path, Storage.fileExists(at: Storage.lastDateURL).description)

        // 로컬에 저장된 result 불러오기
        do {
            savedResults = try Storage.loadResults() ?? []
            if savedResults.isEmpty {
                os_log("No existing ecg_results.json, starting fresh", type: .info)
                try Storage.saveResults(savedResults)
            } else {
                os_log("Loaded %d savedResults", type: .info, savedResults.count)
            }
        } catch {
            os_log("Error loading or initializing results file: %{public}@", type: .error, error.localizedDescription)
        }

        // 마지막 처리 날짜 로드 (없으면 nil)
        do {
            lastFetchDate = try Storage.loadLastDate()
            if let dt = lastFetchDate {
                os_log("Loaded lastFetchDate: %{public}@", type: .info, String(describing: dt))
            } else {
                os_log("No lastFetchDate file found - will fetch all samples", type: .info)
            }
        } catch {
            os_log("Error loading lastDate: %{public}@", type: .error, error.localizedDescription)
        }
        //flutter <-> iOS 연결
        GeneratedPluginRegistrant.register(with: self)
        guard let controller = window?.rootViewController as? FlutterViewController else {
            fatalError("RootViewController is not FlutterViewController.")
        }
        methodChannel = FlutterMethodChannel(
            name: "com.example.health/ecg",
            binaryMessenger: controller.binaryMessenger
        )
        methodChannel?.setMethodCallHandler(handle)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Flutter 호출 처리
    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestAuthorization":
            requestAuthorization(result: result)
        case "getECGData":
            fetchAndUploadECG(result: result)
        case "getSavedECGResults": //flutter가 로컬의 json, txt를 읽도록
            do {
                    let results = try Storage.loadResults() ?? []
                    let fileURLs = try FileManager.default.contentsOfDirectory(at: Storage.docs, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                    var outputs: [[String: Any]] = []
                    for res in results {
                        let safeIso = res.date.replacingOccurrences(of: ":", with: "-")
                        let base = "ecg_\(safeIso)_\(res.prediction)"
                        let txtURL  = fileURLs.first { $0.lastPathComponent == "\(base).txt" }
                        let jsonURL = fileURLs.first { $0.lastPathComponent == "\(base).json" }
                        /*
                        if let t = txtURL?.path {
                            os_log("▶︎ getSavedECGResults found TXT at: %{public}@", type: .info, t)
                        } else {
                            os_log("▶︎ getSavedECGResults no TXT for base: %{public}@", type: .info, base)
                        }
                        if let j = jsonURL?.path {
                            os_log("▶︎ getSavedECGResults found JSON at: %{public}@", type: .info, j)
                        } else {
                            os_log("▶︎ getSavedECGResults no JSON for base: %{public}@", type: .info, base)
                        }
                        */
                        var entry: [String: Any] = [
                            "date": res.date,
                            "prediction": res.prediction
                        ]
                        if let t = txtURL?.path { entry["txtPath"]  = t }
                        if let j = jsonURL?.path { entry["jsonPath"] = j }
                        outputs.append(entry)
                    }

                    let data = try JSONSerialization.data(withJSONObject: outputs, options: [])
                    result(String(data: data, encoding: .utf8)!)
                } catch {
                os_log("Error in getSavedECGResults: %{public}@", type: .error, error.localizedDescription)
                result(FlutterError(code: "file_error", message: error.localizedDescription, details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // HealthKit 권한 요청
    private func requestAuthorization(result: @escaping FlutterResult) {
        guard HKHealthStore.isHealthDataAvailable() else {
            return result(false)
        }
        let ecgType = HKObjectType.electrocardiogramType()
        healthStore.requestAuthorization(toShare: [], read: [ecgType]) { success, _ in
            result(success)
        }
    }

    // ecg 서버로 전송
    private func fetchAndUploadECG(result: @escaping FlutterResult) {
        let ecgType = HKObjectType.electrocardiogramType()
        let predicate: NSPredicate? = {
            if let last = lastFetchDate {
                let start = last.addingTimeInterval(0.001)
                return HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            } else {
                return nil
            }
        }()
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(
            sampleType: ecgType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, error in
            guard let self = self,
                  let ecgSamples = samples as? [HKElectrocardiogram],
                  error == nil else {
                return result(FlutterError(code: "hk_error", message: error?.localizedDescription, details: nil))
            }
            os_log("[Fetch] total ecgSamples: %d", type: .info, ecgSamples.count)

            var outputs: [[String: Any]] = []
            let group = DispatchGroup()

            for sample in ecgSamples {
                group.enter()
                var rawTs: [Double] = []
                var rawVs: [Double] = []

                let ecgQ = HKElectrocardiogramQuery(sample) { _, qr in
                    switch qr {
                    case .measurement(let m):
                        let ts = sample.startDate.timeIntervalSince1970 + m.timeSinceSampleStart
                        let uv = m.quantity(for: .appleWatchSimilarToLeadI)!.doubleValue(for: HKUnit.voltUnit(with: .micro))
                        rawTs.append(ts)
                        rawVs.append(uv)
                    case .done:
                        // raw
                        let rawTxt = zip(rawVs, rawTs)
                            .map { String(format: "(%.3f, %.6f)", $0, $1) }
                            .joined(separator: " ")
                        // sampled
                        let (resTs, resVs) = self.resampleLinear(rawTs: rawTs, rawVal: rawVs, targetFs: self.targetFs)
                        let sampledTxt = zip(resVs, resTs)
                            .map { String(format: "(%.3f, %.6f)", $0, $1) }
                            .joined(separator: " ")
                        os_log(
                          "[Fetch] Calling uploadAndSave for sample at %@",
                          type: .info,
                          String(describing: sample.startDate)
                        )
                        let iso = ISO8601DateFormatter().string(from: sample.startDate)
                        self.uploadAndSave(rawTxt: rawTxt, sampledTxt: sampledTxt, sampleDate: sample.startDate) { prediction, txtPath, jsonPath in
                            outputs.append([
                                "date": iso,
                                "prediction": prediction,
                                "txtPath": txtPath,
                                "jsonPath": jsonPath
                            ])
                            group.leave()
                        }

                    case .error:
                        group.leave()
                    @unknown default:
                        group.leave()
                    }
                }
                self.healthStore.execute(ecgQ)
            }

            group.notify(queue: .main) {
                if let lastSample = ecgSamples.last?.startDate {
                    self.lastFetchDate = lastSample
                    try? Storage.saveLastDate(lastSample)
                }
                let newEntries = outputs.compactMap { dict -> ECGUploadResult? in
                    guard let date = dict["date"] as? String,
                          let pred = dict["prediction"] as? String else { return nil }
                    return ECGUploadResult(date: date, prediction: pred)
                }
                self.savedResults.append(contentsOf: newEntries)
                try? Storage.saveResults(self.savedResults)
                result(outputs)
            }
        }
        healthStore.execute(query)
    }

    // resampling
    private func resampleLinear(rawTs: [Double], rawVal: [Double], targetFs: Double) -> ([Double], [Double]) {
        guard rawTs.count >= 2 else { return (rawTs, rawVal) }
        let start = rawTs.first!, end = rawTs.last!, dt = 1.0 / targetFs
        let count = Int(floor((end - start)/dt)) + 1
        var tsArr = [Double](repeating: 0, count: count)
        var valArr = [Double](repeating: 0, count: count)
        for i in 0..<count {
            let t = start + Double(i) * dt
            tsArr[i] = t
            let idx = rawTs.firstIndex(where: { $0 > t }) ?? rawTs.count-1
            let i1 = max(0, idx-1), i2 = min(idx, rawTs.count-1)
            let t1 = rawTs[i1], t2 = rawTs[i2]
            let v1 = rawVal[i1], v2 = rawVal[i2]
            valArr[i] = (t2 != t1) ? v1 + (t - t1)/(t2 - t1)*(v2 - v1) : v1
        }
        return (tsArr, valArr)
    }

    private func uploadAndSave(
        rawTxt: String,
        sampledTxt: String,
        sampleDate: Date,
        completion: @escaping (_ prediction: String, _ txtPath: String, _ jsonPath: String) -> Void
    ) {
        //setting_page의 이름과 생일을 load
        let prefs = UserDefaults.standard
        let name = prefs.string(forKey: "flutter.username") ?? "Unknown"
        let birth = prefs.string(forKey: "flutter.birthDate") ?? ""
        //timestamp mapping
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        dateFormatter.timeZone = TimeZone.current
        let isoLocal = dateFormatter.string(from: sampleDate)

        let fileDate = sampleDate.addingTimeInterval(9 * 3600)
        let fileNameFormatter = DateFormatter()
        fileNameFormatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        fileNameFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let safeIso = fileNameFormatter.string(from: fileDate)

        let boundary = "Boundary-\(UUID().uuidString)"
        var rawForm = Data()
        rawForm.append("--\(boundary)\r\n".data(using: .utf8)!)
        rawForm.append("Content-Disposition: form-data; name=\"file\"; filename=\"raw_\(safeIso).txt\"\r\n".data(using: .utf8)!)
        rawForm.append("Content-Type: text/plain\r\n\r\n".data(using: .utf8)!)
        rawForm.append(rawTxt.data(using: .utf8)!)
        rawForm.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let subjectFormatter = DateFormatter()
        subjectFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let subjectValue = "Patient/\(name): \(birth) \(subjectFormatter.string(from: sampleDate))"
        let bundle: [String: Any] = [
            "type": "batch",
            "resourceType": "Bundle",
            "entry": [[
                "request": ["url": "Observation", "method": "POST"],
                "resource": [
                    "resourceType": "Observation",
                    "id": "\(safeIso)", //sampledData
                    "component": [[
                        "code": ["coding": [
                            ["display": "MDC_ECG_ELEC_POTL_I"],
                            ["code": "mV", "display": "microvolt", "system": "http:"]
                        ]],
                        "valueSampledData": [
                            "origin": ["value": 55],
                            "period": 1.0 / targetFs * 1000,
                            "data": sampledTxt,
                            "dimensions": 2
                        ]
                    ]],
                    "subject": ["reference": subjectValue],
                    "status": "final",
                    "code": [:]
                ]
            ]]
        ]
        let jsonData = try! JSONSerialization.data(withJSONObject: bundle, options: [])

        // 각 서버로 데이터 전송
        let urls = [predictURL, addDataURL]
        let group = DispatchGroup()
        var finalPrediction = "unknown"
        var predict1ResponseData: Data?

        for url in urls {
            group.enter()
            var req = URLRequest(url: url)
            req.httpMethod = "POST"

            if url == predictURL {
                req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                req.httpBody = rawForm
            } else {
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = jsonData
            }

            URLSession.shared.dataTask(with: req) { data, _, error in
                defer { group.leave() }
                if let error = error {
                    os_log("[ERROR] Network error on %@: %@", type: .error, url.absoluteString, error.localizedDescription)
                    return
                }
                guard let data = data else {
                    os_log("[ERROR] No data received from %@", type: .error, url.absoluteString)
                    return
                }
                let responseBody = String(data: data, encoding: .utf8) ?? "<Non-UTF8 data>"
                if url == self.predictURL {
                    os_log("[PREDICT] Received response: %{public}@", type: .info, responseBody)
                    predict1ResponseData = data
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let resultDict = json["result"] as? [String: Any],
                       let distances = resultDict["distance_from_median"] as? [Any] {
                        finalPrediction = distances.isEmpty ? "normal" : "abnormal"
                    }
                } else {
                    os_log("[addData] Received response: %{public}@", type: .info, responseBody)
                }
            }.resume()
        }

        // save txt, json
        group.notify(queue: .main) {
            let baseName = "ecg_\(safeIso)_\(finalPrediction)"

            // txt
            let txtURL = Storage.docs.appendingPathComponent("\(baseName).txt")
            do {
                try sampledTxt.data(using: .utf8)?.write(to: txtURL)
                os_log("[uploadAndSave] Saved sampled ECG txt to %@", type: .info, txtURL.path)
            } catch {
                os_log("[uploadAndSave] Failed to save TXT: %{public}@", type: .error, error.localizedDescription)
            }

            // json(by predict)
            var jsonPath = ""
            if let data = predict1ResponseData {
                let jsonURL = Storage.docs.appendingPathComponent("\(baseName).json")
                do {
                    try data.write(to: jsonURL)
                    os_log("[uploadAndSave] Saved predict1 JSON to %@", type: .info, jsonURL.path)
                    jsonPath = jsonURL.path
                } catch {
                    os_log("[uploadAndSave] Failed to save JSON: %{public}@", type: .error, error.localizedDescription)
                }
            }

            os_log("[uploadAndSave] All done, returning prediction: %@", type: .info, finalPrediction)
            completion(finalPrediction, txtURL.path, jsonPath)
        }
    }
}
