import Foundation
import Teapot

public class EthereumAPIClient {
    static let shared: EthereumAPIClient = EthereumAPIClient()

    public var teapot: Teapot

    public var cereal = Cereal()

    public init() {
        self.teapot = Teapot(baseURL: URL(string: "https://token-eth-service.herokuapp.com")!)
    }

    func timestamp(completion: @escaping((_ timestamp: String) -> Void)) {
        self.teapot.get("/v1/timestamp") { (result: NetworkResult) in
            switch result {
            case .success(let json, _):
                guard let json = json?.dictionary else { fatalError() }
                guard let timestamp = json["timestamp"] as? Int else { fatalError("Timestamp should be an integer") }

                completion(String(timestamp))
            case .failure(_, _, let error):
                print(error)
            }
        }
    }

    public func createUnsignedTransaction(to address: String, value: NSDecimalNumber, completion: @escaping((_ unsignedTransaction: String?, _ error: Error?) -> Void)) {
        let parameters: [String: Any] = [
            "from": self.cereal.address,
            "to": address,
            "value": value.toHexString,
        ]

        let json = JSON(parameters)

        self.teapot.post("/v1/tx/skel", parameters: json) { result in
            switch result {
            case .success(let json, let response):
                print(response)
                completion(json!.dictionary!["tx"] as? String, nil)
            case .failure(let json, let response, let error):
                print(response)
                print(json ?? "")
                print(error)
                completion(nil, error)
            }
        }
    }

    public func sendSignedTransaction(originalTransaction: String, transactionSignature: String, completion: @escaping((_ json: JSON?, _ error: Error?) -> Void)) {
        self.timestamp { (timestamp) in

            let path = "/v1/tx"

            let params = [
                "tx": originalTransaction,
                "signature": transactionSignature,
            ]

            let payloadString = String(data: try! JSONSerialization.data(withJSONObject: params, options: []), encoding: .utf8)!
            let hashedPayload = self.cereal.sha3(string: payloadString)

            let signature = "0x\(self.cereal.sign(message: "POST\n\(path)\n\(timestamp)\n\(hashedPayload)"))"

            let headers: [String: String] = [
                "Token-ID-Address": self.cereal.address,
                "Token-Signature": signature,
                "Token-Timestamp": timestamp,
            ]

            let json = JSON(params)

            self.teapot.post(path, parameters: json, headerFields: headers) { (result) in
                switch result {
                case .success(let json, let response):
                    print(response)
                    print(json ?? "")
                    completion(json, nil)
                case .failure(let json, let response, let error):
                    print(response)
                    print(json ?? "")
                    print(error)
                    let json = JSON((json!.dictionary!["errors"] as! [[String: Any]]).first!)
                    completion(json, error)
                }
            }
        }
    }

    public func getBalance(address: String, completion: @escaping((_ balance: NSDecimalNumber, _ error: Error?) -> Void)) {
        self.teapot.get("/v1/balance/\(address)") { (result: NetworkResult) in
            switch result {
            case .success(let json, let response):
                guard response.statusCode == 200 else { fatalError() }
                guard let json = json?.dictionary else { fatalError() }

                let confirmedBalanceString = json["confirmed_balance"] as? String ?? "0"

                completion(NSDecimalNumber(hexadecimalString: confirmedBalanceString), nil)
            case .failure(let json, let response, let error):
                completion(0, error)
                print(error)
                print(response)
                print(json ?? "")
            }
        }
    }

    public func registerForPushNotifications() {
        self.timestamp { (timestamp) in
            let path = "/v1/apn/register"
            let address = self.cereal.address

            let params = ["registration_id": address]

            let payloadString = String(data: try! JSONSerialization.data(withJSONObject: params, options: []), encoding: .utf8)!
            let hashedPayload = self.cereal.sha3(string: payloadString)
            let signature = "0x\(self.cereal.sign(message: "POST\n\(path)\n\(timestamp)\n\(hashedPayload)"))"

            let headerFields: [String: String] = [
                "Token-ID-Address": address,
                "Token-Signature": signature,
                "Token-Timestamp": timestamp,
            ]

            let json = JSON(params)
            self.teapot.post(path, parameters: json, headerFields: headerFields) { result in
                switch result {
                case .success(let json, let response):
                    print(json ?? "")
                    print(response)
                case .failure(let json, let response, let error):
                    print(json ?? "")
                    print(response)
                    print(error)
                }
            }
        }
    }

    public func registerForNotifications() {
        self.timestamp { (timestamp) in
            let address = self.cereal.address
            let path = "/v1/register"

            let params = [
                "addresses": [
                    address,
                ],
            ]

            let payloadString = String(data: try! JSONSerialization.data(withJSONObject: params, options: []), encoding: .utf8)!
            let hashedPayload = self.cereal.sha3(string: payloadString)
            let signature = "0x\(self.cereal.sign(message: "POST\n\(path)\n\(timestamp)\n\(hashedPayload)"))"

            let headerFields: [String: String] = [
                "Token-ID-Address": address,
                "Token-Signature": signature,
                "Token-Timestamp": timestamp,
            ]

            let json = JSON(params)

            self.teapot.post(path, parameters: json, headerFields: headerFields) { (result) in
                switch result {
                case .success(let json, let response):
                    print(json ?? "")
                    print(response)
                case .failure(let json, let response, let error):
                    print(json ?? "")
                    print(response)
                    print(error)
                }
            }
        }
    }

    public func deregisterForNotifications() {
        self.timestamp { (timestamp) in
            let address = self.cereal.address
            let path = "/v1/deregister"

            let params = [
                "addresses": [
                    address,
                ],
            ]

            let payloadString = String(data: try! JSONSerialization.data(withJSONObject: params, options: []), encoding: .utf8)!
            let hashedPayload = self.cereal.sha3(string: payloadString)
            let signature = "0x\(self.cereal.sign(message: "POST\n\(path)\n\(timestamp)\n\(hashedPayload)"))"

            let headerFields: [String: String] = [
                "Token-ID-Address": address,
                "Token-Signature": signature,
                "Token-Timestamp": timestamp,
            ]

            let json = JSON(params)

            self.teapot.post(path, parameters: json, headerFields: headerFields) { (result) in
                switch result {
                case .success(let json, let response):
                    print(json ?? "")
                    print(response)
                case .failure(let json, let response, let error):
                    print(json ?? "")
                    print(response)
                    print(error)
                }
            }
        }
    }
}