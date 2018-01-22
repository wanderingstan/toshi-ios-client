import Foundation
import UIKit
import TinyConstraints
import CameraScanner

protocol PaymentAddressControllerDelegate: class {
    func paymentAddressControllerFinished(with address: String, on controller: PaymentAddressController)
}

class PaymentAddressController: UIViewController {

    private let valueInWei: NSDecimalNumber

    private var paymentAddress: String? {
        didSet {
            if let address = paymentAddress, EthereumAddress.validate(address) {
                navigationItem.rightBarButtonItem?.isEnabled = true
            } else {
                navigationItem.rightBarButtonItem?.isEnabled = false
            }
        }
    }

    weak var delegate: PaymentAddressControllerDelegate?

    private lazy var valueLabel: UILabel = {
        let value: String = EthereumConverter.fiatValueString(forWei: self.valueInWei, exchangeRate: ExchangeRateClient.exchangeRate)

        let view = UILabel()
        view.font = Theme.preferredTitle1()
        view.adjustsFontForContentSizeCategory = true
        view.textAlignment = .center
        view.adjustsFontSizeToFitWidth = true
        view.minimumScaleFactor = 0.5
        view.text = Localized("payment_send_prefix") + "\(value)"

        return view
    }()

    private lazy var descriptionLabel: UILabel = {
        let view = UILabel()
        view.font = Theme.preferredRegular()
        view.textAlignment = .center
        view.numberOfLines = 0
        view.text = Localized("payment_send_description")
        view.adjustsFontForContentSizeCategory = true

        return view
    }()

    private lazy var addressInputView: PaymentAddressInputView = {
        let view = PaymentAddressInputView()
        view.delegate = self

        return view
    }()

    lazy var scannerController: ScannerViewController = {
        let controller = ScannerController(instructions: Localized("payment_qr_scanner_instructions"), types: [.qrCode])
        controller.delegate = self

        return controller
    }()

    init(with valueInWei: NSDecimalNumber) {
        self.valueInWei = valueInWei
        super.init(nibName: nil, bundle: nil)

        navigationItem.backBarButtonItem = UIBarButtonItem.back
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(nextBarButtonTapped(_:)))
        navigationItem.rightBarButtonItem?.isEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Theme.viewBackgroundColor

        view.addSubview(valueLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(addressInputView)

        valueLabel.top(to: view, offset: 67)
        valueLabel.left(to: view, offset: 16)
        valueLabel.right(to: view, offset: -16)

        descriptionLabel.topToBottom(of: valueLabel, offset: 10)
        descriptionLabel.left(to: view, offset: 16)
        descriptionLabel.right(to: view, offset: -16)

        addressInputView.topToBottom(of: descriptionLabel, offset: 40)
        addressInputView.left(to: view)
        addressInputView.right(to: view)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        addressInputView.addressTextField.becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        addressInputView.addressTextField.resignFirstResponder()
    }

    @objc func nextBarButtonTapped(_ item: UIBarButtonItem) {
        goToConfirmation()
    }

    func goToConfirmation() {
        guard let paymentAddress = paymentAddress, EthereumAddress.validate(paymentAddress) else { return }

        delegate?.paymentAddressControllerFinished(with: paymentAddress, on: self)
    }
}

extension PaymentAddressController: ScannerViewControllerDelegate {
    
    func scannerViewControllerDidCancel(_ controller: ScannerViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    func scannerViewController(_ controller: ScannerViewController, didScanResult result: String) {
        if let intent = QRCodeIntent(result: result) {
            switch intent {
            case .addContact(let username):
                let name = TokenUser.name(from: username)
                fillPaymentAddress(username: name)
            case .addressInput(let address):
                fillPaymentAddress(address: address)
            case .paymentRequest(_, let address, let username, _):
                if let username = username {
                    fillPaymentAddress(username: username)
                } else if let address = address {
                    fillPaymentAddress(address: address)
                }
            default:
                scannerController.startScanning()
            }
        } else {
            scannerController.startScanning()
        }
    }

    private func fillPaymentAddress(username: String) {
        IDAPIClient.shared.retrieveUser(username: username) { [weak self] contact in
            guard let contact = contact else {
                self?.scannerController.startScanning()

                return
            }
            self?.fillPaymentAddress(address: contact.paymentAddress)
        }
    }

    private func fillPaymentAddress(address: String) {
        paymentAddress = address
        self.addressInputView.paymentAddress = address
        SoundPlayer.playSound(type: .scanned)
        scannerController.dismiss(animated: true, completion: nil)
    }
}

extension PaymentAddressController: PaymentAddressInputDelegate {


    func didRequestScanner() {
        Navigator.presentModally(scannerController)
    }

    func didRequestSendPayment() {
        goToConfirmation()
    }

    func didChangeAddress(to address: String?) {
      paymentAddress = address
    }
}
