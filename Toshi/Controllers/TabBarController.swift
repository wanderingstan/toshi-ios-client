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

import UIKit
import UserNotifications
import CameraScanner

let TabBarItemTitleOffset: CGFloat = -3.0

class TabBarController: UITabBarController, OfflineAlertDisplaying {
    let offlineAlertView = defaultOfflineAlertView()

    enum Tab {
        case browsing
        case messaging
        case scanner
        case favorites
        case me
    }

    var currentNavigationController: UINavigationController? {
        return selectedViewController as? UINavigationController
    }

    private var chatAPIClient: ChatAPIClient {
        return ChatAPIClient.shared
    }

    private var idAPIClient: IDAPIClient {
        return IDAPIClient.shared
    }

    private lazy var reachabilityManager: ReachabilityManager = {
        let reachabilityManager = ReachabilityManager()
        reachabilityManager.delegate = self

        return reachabilityManager
    }()

    lazy var scannerController: ScannerViewController = {
        let controller = ScannerController(instructions: "Scan QR code", types: [.qrCode])
        controller.delegate = self

        return controller
    }()

    lazy var placeholderScannerController: UIViewController = {
        let controller = UIViewController()
        controller.tabBarItem = UITabBarItem(title: Localized("tab_bar_title_scan"), image: #imageLiteral(resourceName: "tab3"), tag: 0)
        controller.tabBarItem.titlePositionAdjustment.vertical = TabBarItemTitleOffset
        
        return controller
    }()

    var browseViewController: BrowseNavigationController!
    var messagingController: RecentNavigationController!
    var profilesController: ProfilesNavigationController!
    var settingsController: SettingsNavigationController!

    init() {
        super.init(nibName: nil, bundle: nil)

        delegate = self
        reachabilityManager.register()

        setupOfflineAlertView(hidden: true)
    }

    required init?(coder _: NSCoder) {
        fatalError()
    }

    @objc func setupControllers() {
        browseViewController = BrowseNavigationController(rootViewController: BrowseViewController())
        let datasource = ProfilesDataSource(type: .favorites)
        datasource.excludedProfilesIds = []
        profilesController = ProfilesNavigationController(rootViewController: ProfilesViewController(datasource: datasource))

        messagingController = RecentNavigationController(nibName: nil, bundle: nil)
        let recentViewController = RecentViewController(style: .grouped)

        if Yap.isUserSessionSetup, let address = UserDefaultsWrapper.selectedThreadAddress, let thread = recentViewController.thread(withAddress: address) {
            messagingController.viewControllers = [recentViewController, ChatViewController(thread: thread)]
        } else {
            messagingController.viewControllers = [recentViewController]
        }

        settingsController = SettingsNavigationController(rootViewController: SettingsController())

        viewControllers = [
            self.browseViewController,
            self.messagingController,
            self.placeholderScannerController,
            self.profilesController,
            self.settingsController
        ]

        view.tintColor = Theme.tintColor
        view.backgroundColor = Theme.viewBackgroundColor

        tabBar.barTintColor = Theme.viewBackgroundColor
        tabBar.unselectedItemTintColor = Theme.unselectedItemTintColor

        selectedIndex = UserDefaultsWrapper.tabBarSelectedIndex
    }

    func openPaymentMessage(to address: String, parameters: [String: Any]? = nil, transaction: String?) {
        dismiss(animated: false) {

            ChatInteractor.getOrCreateThread(for: address)

            DispatchQueue.main.async {
                self.displayMessage(forAddress: address) { controller in
                    if let chatViewController = controller as? ChatViewController, let parameters = parameters {
                        chatViewController.sendPayment(with: parameters, transaction: transaction)
                    }
                }
            }
        }
    }

    func displayMessage(forAddress address: String, completion: ((Any?) -> Void)? = nil) {
        if let index = viewControllers?.index(of: messagingController) {
            selectedIndex = index
        }

        messagingController.openThread(withAddress: address, completion: completion)
    }

    public func openThread(_ thread: TSThread, animated: Bool = true) {
        messagingController.openThread(thread, animated: animated)
    }

    func `switch`(to tab: Tab) {
        switch tab {
        case .browsing:
            selectedIndex = 0
        case .messaging:
            selectedIndex = 1
        case .scanner:
            presentScanner()
        case .favorites:
            selectedIndex = 3
        case .me:
            selectedIndex = 4
        }
    }

    private func presentScanner() {
        SoundPlayer.playSound(type: .menuButton)
        Navigator.presentModally(scannerController)
    }

    @objc func openDeepLinkURL(_ url: URL) {
        if url.user == "username" {
            guard let username = url.host else { return }

            idAPIClient.retrieveUser(username: username) { [weak self] contact in
                guard let contact = contact else { return }

                let contactController = ProfileViewController(profile: contact)
                (self?.selectedViewController as? UINavigationController)?.pushViewController(contactController, animated: true)
            }
        }
    }
}

extension TabBarController: UITabBarControllerDelegate {

    func tabBarController(_: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if viewController != browseViewController {

            guard let browseViewController = browseViewController.viewControllers.first as? BrowseViewController else { return true }
            browseViewController.dismissSearch()

            browseViewController.navigationController?.popToRootViewController(animated: false)
        }

        if viewController == placeholderScannerController {
            presentScanner()

            return false
        }

        return true
    }

    func tabBarController(_: UITabBarController, didSelect viewController: UIViewController) {
        SoundPlayer.playSound(type: .menuButton)

        automaticallyAdjustsScrollViewInsets = viewController.automaticallyAdjustsScrollViewInsets

        if let index = self.viewControllers?.index(of: viewController) {
            UserDefaultsWrapper.tabBarSelectedIndex = index
        }
    }
}

extension TabBarController: ScannerViewControllerDelegate {

    func scannerViewControllerDidCancel(_: ScannerViewController) {
        dismiss(animated: true)
    }

    func scannerViewController(_ controller: ScannerViewController, didScanResult result: String) {
        
        guard reachabilityManager.reachability?.currentReachabilityStatus != .notReachable else {
            let alert = UIAlertController(title: Localized("error-alert-title"), message: Localized("offline_alert_message"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: Localized("alert-ok-action-title"), style: .cancel, handler: { _ in
                self.scannerController.startScanning()
            }))
            
            Navigator.presentModally(alert)
            
            return
        }
        
        if let intent = QRCodeIntent(result: result) {
            switch intent {
            case .webSignIn(let loginToken):
                idAPIClient.adminLogin(loginToken: loginToken) {[weak self] _, _ in
                    SoundPlayer.playSound(type: .scanned)
                    self?.dismiss(animated: true)
                }
            case .paymentRequest(let weiValue, let address, let username, _):

                let valueInWei = NSDecimalNumber(hexadecimalString: weiValue)
                let fiatValueString = EthereumConverter.fiatValueString(forWei: valueInWei, exchangeRate: ExchangeRateClient.exchangeRate)
                let ethValueString = EthereumConverter.ethereumValueString(forWei: valueInWei)

                if let username = username {
                    let confirmationText = String(format: Localized("payment_request_confirmation_warning_message"), fiatValueString, ethValueString, username)
                    proceedToPayment(username: username, weiValue: weiValue, confirmationText: confirmationText)
                } else if let address = address {
                    let confirmationText = String(format: Localized("payment_request_confirmation_warning_message"), fiatValueString, ethValueString, address)
                    proceedToPayment(address: address, weiValue: weiValue, confirmationText: confirmationText)
                }
            case .addContact(let username):
                let contactName = TokenUser.name(from: username)
                viewContact(with: contactName)
            default:
                scannerController.startScanning()
            }
        } else {
            scannerController.startScanning()
        }
    }

    private func proceedToPayment(address: String, weiValue: String?, confirmationText: String) {
        let userInfo = UserInfo(address: address, paymentAddress: address, avatarPath: nil, name: nil, username: address, isLocal: false)
        var parameters = ["from": Cereal.shared.paymentAddress, "to": address]
        parameters["value"] = weiValue

        proceedToPayment(userInfo: userInfo, parameters: parameters, confirmationText: confirmationText)
    }

    private func proceedToPayment(username: String, weiValue: String?, confirmationText: String) {
        idAPIClient.retrieveUser(username: username) { [weak self] contact in
            if let contact = contact, let validWeiValue = weiValue {
                var parameters = ["from": Cereal.shared.paymentAddress, "to": contact.paymentAddress]
                parameters["value"] = validWeiValue

                self?.proceedToPayment(userInfo: contact.userInfo, parameters: parameters, confirmationText: confirmationText)
            } else {
                self?.scannerController.startScanning()
            }
        }
    }

    private func proceedToPayment(userInfo: UserInfo, parameters: [String: Any], confirmationText: String) {

        if parameters["value"] != nil, let scannerController = self.scannerController as? ScannerController {
            scannerController.setStatusBarHidden(true)

            SoundPlayer.playSound(type: .scanned)

            PaymentConfirmation.shared.present(for: parameters, title: Localized("payment_confirmation_warning_message"), message: confirmationText, approveHandler: { [weak self] transaction, error in

                guard error == nil else {
                    self?.scannerController.startScanning()
                    return
                }

                if let scannerController = self?.scannerController as? ScannerController {
                    scannerController.approvePayment(with: parameters, userInfo: userInfo, transaction: transaction, error: error)
                } else {
                    scannerController.startScanning()
                }
            }, cancelHandler: {
                scannerController.startScanning()
            })

        } else {
            scannerController.startScanning()
        }
    }

    private func viewContact(with contactName: String) {
        idAPIClient.retrieveUser(username: contactName) { [weak self] contact in
            guard let contact = contact else {
                self?.scannerController.startScanning()

                return
            }

            SoundPlayer.playSound(type: .scanned)

            self?.dismiss(animated: true) {
                self?.switch(to: .favorites)
                let contactController = ProfileViewController(profile: contact)
                self?.profilesController.pushViewController(contactController, animated: true)
            }
        }
    }

}

extension TabBarController: ReachabilityDelegate {
    func reachabilityDidChange(toConnected connected: Bool) {

        if connected {
            hideOfflineAlertView()
        } else {
            showOfflineAlertView()
        }
    }
}
