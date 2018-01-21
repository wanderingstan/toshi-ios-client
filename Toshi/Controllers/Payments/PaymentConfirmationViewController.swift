// Copyright (c) 2017 Token Browser, Inc
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

protocol PaymentConfirmationViewControllerDelegate: class {
    func paymentConfirmationViewControllerFinished(on controller: PaymentConfirmationViewController, parameters: [String: Any], transactionHash: String?, error: ToshiError?)
    func paymentConfirmationViewControllerDidCancel(on controller: PaymentConfirmationViewController)
}

enum RecipientType {
    case
    user(info: UserInfo?),
    dapp(info: DappInfo)
}

class PaymentConfirmationViewController: UIViewController {

    weak var delegate: PaymentConfirmationViewControllerDelegate?

    let paymentManager: PaymentManager

    private var recipientType: RecipientType
    private let shouldSendSignedTransaction: Bool

    private let parameters: [String: Any]

    // MARK: - Lazy views

    private lazy var avatarImageView: AvatarImageView = {
        let imageView = AvatarImageView()
        imageView.image = UIImage(named: "avatar-placeholder")

        return imageView
    }()

    var originalUnsignedTransaction: String? {
        return paymentManager.transaction
    }

    private lazy var recipientLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.font = Theme.preferredRegular()
        view.textColor = Theme.lightGreyTextColor
        view.adjustsFontForContentSizeCategory = true

        switch recipientType {
        case .user:
            view.textAlignment = .center
            view.text = Localized("confirmation_recipient")
        case .dapp:
            view.textAlignment = .left
            view.text = Localized("confirmation_dapp")
        }

        return view
    }()

    // MARK: User

    private lazy var userNameLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.font = Theme.preferredDisplayName()
        view.textAlignment = .center
        view.adjustsFontForContentSizeCategory = true
        view.textColor = Theme.darkTextColor

        switch recipientType {
        case .user(let userInfo):
            view.text = userInfo?.name
        default:
            break // don't set.
        }

        return view
    }()

    // MARK: Dapp

    private lazy var dappInfoLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 2
        view.font = Theme.preferredSemibold()
        view.adjustsFontForContentSizeCategory = true
        view.textColor = Theme.darkTextColor

        return view
    }()

    private lazy var dappURLLabel: UILabel = {
        let view = UILabel()
        view.font = Theme.preferredFootnote()
        view.textColor = Theme.lightGreyTextColor

        return view
    }()

    // MARK: Payment sheet style title

    private lazy var paymentSheetTitleLabel: UILabel = {
        let view = UILabel()
        view.font = Theme.preferredSemibold()
        view.textAlignment = .center
        view.adjustsFontForContentSizeCategory = true
        view.text = title

        return view
    }()

    private lazy var paymentSheetCancelButton: UIButton = {
        let view = UIButton()
        view.titleLabel?.adjustsFontForContentSizeCategory = true
        view.setTitleColor(Theme.tintColor, for: .normal)
        view.addTarget(self, action: #selector(cancelItemTapped), for: .touchUpInside)
        view.setTitle(Localized("cancel_action_title"), for: .normal)

        return view
    }()

    // MARK: Payment section

    private lazy var fetchingNetworkFeesLabel: UILabel = {
        let view = UILabel()
        view.backgroundColor = Theme.viewBackgroundColor
        view.numberOfLines = 0
        view.font = Theme.preferredRegular()
        view.textColor = Theme.lightGreyTextColor
        view.textAlignment = .center
        view.adjustsFontForContentSizeCategory = true

        view.text = Localized("confirmation_fetching_estimated_network_fees")

        return view
    }()

    private lazy var receiptView: ReceiptView = {
        let view = ReceiptView()

        view.alpha = 0

        return view
    }()

    private lazy var payButton: ActionButton = {
        let button = ActionButton(margin: 15)
        button.title = Localized("confirmation_pay")
        button.addTarget(self, action: #selector(didTapPayButton), for: .touchUpInside)

        return button
    }()

    private lazy var balanceLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.font = Theme.preferredFootnote()
        view.textColor = Theme.lightGreyTextColor
        view.textAlignment = .center
        view.adjustsFontForContentSizeCategory = true

        view.text = Localized("confirmation_fetching_balance")

        return view
    }()

    // MARK: - Initialization

    init(parameters: [String: Any], recipientType: RecipientType, shouldSendSignedTransaction: Bool = true) {
        paymentManager = PaymentManager(parameters: parameters)
        self.recipientType = recipientType
        self.shouldSendSignedTransaction = shouldSendSignedTransaction
        self.parameters = parameters

        super.init(nibName: nil, bundle: nil)

        guard let address = parameters[PaymentParameters.to] as? String, EthereumAddress.validate(address) else {
            assertionFailure("Invalid payment address on Payment confirmation")
            return
        }

        fetchUserWithCurrentPaymentAddressIfNeeded(address)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = Localized("confirmation_title")
        addSubviewsAndConstraints()

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelItemTapped))

        displayRecipientDetails()
        view.backgroundColor = Theme.viewBackgroundColor

        payButton.showSpinner()

        paymentManager.fetchPaymentInfo { [weak self] paymentInfo in
            DispatchQueue.main.async {
                self?.payButton.hideSpinner()
                self?.receiptView.setPaymentInfo(paymentInfo)

                self?.receiptView.alpha = 1
                UIView.animate(withDuration: 0.2) {
                    self?.fetchingNetworkFeesLabel.alpha = 0
                }

                self?.setBalance(paymentInfo.balanceString, isSufficient: paymentInfo.sufficientBalance)
            }
        }
    }

    // MARK: - View Setup

    private func addSubviewsAndConstraints() {
        let receiptPayBalanceView = setupReceiptPayBalance(in: view)

        switch recipientType {
        case .user:
            addProfileStackViewLayout(to: view, above: receiptPayBalanceView)
        case .dapp:
            let dappStackView = addDappStackViewLayout(to: view, above: receiptPayBalanceView)
            addBackgroundView(to: view, above: dappStackView)
        }
    }

    private func setupReceiptPayBalance(in parentView: UIView) -> UIView {
        let receiptPayBalanceStackView = UIStackView()
        receiptPayBalanceStackView.axis = .vertical
        receiptPayBalanceStackView.alignment = .center
        parentView.addSubview(receiptPayBalanceStackView)

        receiptPayBalanceStackView.bottom(to: layoutGuide(), offset: -.defaultMargin)
        receiptPayBalanceStackView.leftToSuperview(offset: .defaultMargin)
        receiptPayBalanceStackView.rightToSuperview(offset: .defaultMargin)

        receiptPayBalanceStackView.addWithDefaultConstraints(view: receiptView)
        receiptPayBalanceStackView.addSpacing(.largeInterItemSpacing, after: receiptView)

        // Don't add the network fees view as an arranged subview - pin it to the receipt view
        // so it floats in the same place where the pay balance view will appear
        receiptPayBalanceStackView.addSubview(fetchingNetworkFeesLabel)
        fetchingNetworkFeesLabel.edges(to: receiptView)

        receiptPayBalanceStackView.addWithDefaultConstraints(view: payButton)
        receiptPayBalanceStackView.addSpacing(.largeInterItemSpacing, after: payButton)

        receiptPayBalanceStackView.addWithDefaultConstraints(view: balanceLabel)

        return receiptPayBalanceStackView
    }

    private func addProfileStackViewLayout(to parentView: UIView, above viewToPinToTopOf: UIView) {
        let profileDetailsStackView = UIStackView()
        profileDetailsStackView.axis = .vertical
        profileDetailsStackView.alignment = .center

        // Setup layout guides to allow the profile details stack view to float in between the top of
        // the parent view and the top of the view to pin it above.
        let profileDetailsTopLayoutGuide = UILayoutGuide()
        parentView.addLayoutGuide(profileDetailsTopLayoutGuide)
        profileDetailsTopLayoutGuide.height(.mediumInterItemSpacing, relation: .equalOrGreater)
        profileDetailsTopLayoutGuide.top(to: layoutGuide())
        profileDetailsTopLayoutGuide.left(to: parentView)
        profileDetailsTopLayoutGuide.right(to: parentView)

        let profileDetailsBottomLayoutGuide = UILayoutGuide()
        parentView.addLayoutGuide(profileDetailsBottomLayoutGuide)
        profileDetailsBottomLayoutGuide.height(to: profileDetailsTopLayoutGuide)
        profileDetailsBottomLayoutGuide.left(to: parentView)
        profileDetailsBottomLayoutGuide.right(to: parentView)
        profileDetailsBottomLayoutGuide.bottomToTop(of: viewToPinToTopOf)

        parentView.addSubview(profileDetailsStackView)

        profileDetailsStackView.topToBottom(of: profileDetailsTopLayoutGuide)
        profileDetailsStackView.leftToSuperview(offset: .defaultMargin)
        profileDetailsStackView.rightToSuperview(offset: .defaultMargin)
        profileDetailsStackView.bottomToTop(of: profileDetailsBottomLayoutGuide)

        profileDetailsStackView.addWithCenterConstraint(view: avatarImageView)
        avatarImageView.height(.defaultAvatarHeight)
        avatarImageView.width(.defaultAvatarHeight)
        profileDetailsStackView.addSpacing(.defaultMargin, after: avatarImageView)

        profileDetailsStackView.addWithDefaultConstraints(view: recipientLabel)
        profileDetailsStackView.addWithDefaultConstraints(view: userNameLabel)
    }

    func addDappStackViewLayout(to parentView: UIView, above viewToPinToTopOf: UIView) -> UIView {
        let dappStackView = UIStackView()
        dappStackView.axis = .vertical
        dappStackView.alignment = .center

        parentView.addSubview(dappStackView)
        dappStackView.leftToSuperview()
        dappStackView.rightToSuperview()
        dappStackView.bottomToTop(of: viewToPinToTopOf, offset: -.largeInterItemSpacing)

        dappStackView.addStandardBorder()
        addTitleCancelView(to: dappStackView)

        let afterTitleBorder = dappStackView.addStandardBorder()
        dappStackView.addSpacing(.largeInterItemSpacing, after: afterTitleBorder)

        dappStackView.addWithDefaultConstraints(view: recipientLabel, margin: .defaultMargin)
        dappStackView.addSpacing(12, after: recipientLabel)

        let textStackView = UIStackView()
        textStackView.axis = .vertical
        textStackView.spacing = 4

        textStackView.addArrangedSubview(dappInfoLabel)
        textStackView.addArrangedSubview(dappURLLabel)

        let websiteInfoStackView = UIStackView()
        websiteInfoStackView.axis = .horizontal
        websiteInfoStackView.alignment = .top

        websiteInfoStackView.addArrangedSubview(textStackView)
        websiteInfoStackView.addArrangedSubview(avatarImageView)

        let dappAvatarHeight: CGFloat = 48
        avatarImageView.height(dappAvatarHeight)
        avatarImageView.width(dappAvatarHeight)

        dappStackView.addWithDefaultConstraints(view: websiteInfoStackView, margin: .defaultMargin)
        dappStackView.addSpacing(.largeInterItemSpacing, after: websiteInfoStackView)

        dappStackView.addStandardBorder()

        return dappStackView
    }

    func addTitleCancelView(to stackView: UIStackView) {
        let titleView = UIView()
        titleView.backgroundColor = .clear

        titleView.addSubview(paymentSheetCancelButton)
        paymentSheetCancelButton.centerYToSuperview()
        paymentSheetCancelButton.leftToSuperview(offset: .defaultMargin)

        titleView.addSubview(paymentSheetTitleLabel)
        paymentSheetTitleLabel.centerYToSuperview()
        paymentSheetTitleLabel.centerXToSuperview()
        paymentSheetTitleLabel.leftToRight(of: paymentSheetCancelButton, offset: .mediumInterItemSpacing, relation: .equalOrGreater)

        stackView.addWithDefaultConstraints(view: titleView)
        titleView.height(.defaultBarHeight)
    }

    func addBackgroundView(to parentView: UIView, above viewToPinToTopOf: UIView) {
        let background = UIView()
        background.backgroundColor = .clear

        parentView.addSubview(background)
        background.edgesToSuperview(excluding: .bottom)
        background.bottomToTop(of: viewToPinToTopOf)
    }

    // MARK: - Configuration for display

    private func displayRecipientDetails() {
        fetchAvatarIfNeeded()

        switch recipientType {
        case .user(let userInfo):
            userNameLabel.text = userInfo?.name
        case .dapp(let dappInfo):
            dappInfoLabel.text = dappInfo.headerText
            guard let urlComponents = URLComponents(url: dappInfo.dappURL, resolvingAgainstBaseURL: false) else { return }
            dappURLLabel.text = urlComponents.host
        }
    }

    private func fetchUserWithCurrentPaymentAddressIfNeeded(_ address: String) {
        switch recipientType {
        case .dapp:
            // No info needs to be fetched for something that is not a user.
            return
        case .user:
            IDAPIClient.shared.findUserWithPaymentAddress(address) { [weak self] user, _ in
                self?.recipientType = .user(info: user?.userInfo)
                self?.displayRecipientDetails()
            }
        }
    }

    private func fetchAvatarIfNeeded() {
        let path: String?
        switch recipientType {
        case .user(let userInfo):
            path = userInfo?.avatarPath
        case .dapp(let dappInfo):
            path = dappInfo.imagePath
        }

        guard let avatarPath = path else { return }

        AvatarManager.shared.avatar(for: avatarPath, completion: { [weak self] image, _ in
            self?.avatarImageView.image = image
        })
    }

    private func setBalance(_ balanceString: String, isSufficient: Bool) {
        if isSufficient {
            UIView.animate(withDuration: 0.2) {
                self.balanceLabel.textColor = Theme.lightGreyTextColor
                self.balanceLabel.text = String(format: Localized("confirmation_your_balance"), balanceString)

                self.payButton.isEnabled = true
            }
        } else {
            UIView.animate(withDuration: 0.2) {
                self.balanceLabel.textColor = Theme.errorColor
                self.balanceLabel.text = String(format: Localized("confirmation_insufficient_balance"), balanceString)

                self.payButton.isEnabled = false
            }
        }
    }

    // MARK: - Action Targets

    @objc func cancelItemTapped() {
        self.dismiss(animated: true, completion: nil)
        delegate?.paymentConfirmationViewControllerDidCancel(on: self)
    }

    @objc func didTapPayButton() {
        guard shouldSendSignedTransaction else {
            dismiss(animated: true, completion: {
                self.delegate?.paymentConfirmationViewControllerFinished(on: self, parameters: self.paymentManager.parameters, transactionHash: "", error: nil)
            })

            return
        }

        paymentManager.sendPayment { [weak self] error, transactionHash in
            guard let weakSelf = self else { return }

            guard error == nil else {
                let alert = UIAlertController(title: Localized("transaction_error_message"), message: (error?.description ?? ToshiError.genericError.description), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
                    weakSelf.dismiss(animated: true, completion: {
                        weakSelf.delegate?.paymentConfirmationViewControllerFinished(on: weakSelf, parameters: weakSelf.paymentManager.parameters, transactionHash: transactionHash, error: error)
                    })
                }))

                Navigator.presentModally(alert)

                return
            }

            weakSelf.dismiss(animated: true, completion: {
                weakSelf.delegate?.paymentConfirmationViewControllerFinished(on: weakSelf, parameters: weakSelf.paymentManager.parameters, transactionHash: transactionHash, error: error)
            })
        }
    }
}
