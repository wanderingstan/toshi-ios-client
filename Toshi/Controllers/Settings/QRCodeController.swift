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
import SweetUIKit
import CoreImage
import MobileCoreServices

final class SelectableImageView: UIImageView {
    private var stringRepresentation: String

    init(stringRepresentation: String) {
        self.stringRepresentation = stringRepresentation

        super.init(frame: .zero)

        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func becomeFirstResponder() -> Bool {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        return super.becomeFirstResponder()
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(copy(_:))
    }

    override func copy(_ sender: Any?) {
        UIPasteboard.general.items = [
            [kUTTypeJPEG as String: image!],
            [kUTTypeUTF8PlainText as String: stringRepresentation]
        ]
    }
}

class QRCodeController: UIViewController {
    private var username: String?

    static let addUsernameBasePath = "https://app.toshi.org/add/"
    static let addUserPath = "/add/"
    static let paymentWithUsernamePath = "/pay/"
    static let paymentWithAddressPath = "/ethereum:"

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    private lazy var qrCodeImageView: SelectableImageView = {
        return SelectableImageView(stringRepresentation: "\(QRCodeController.addUsernameBasePath)\(username!)")
    }()

    private let subtitleLabel = TextLabel(Localized("profile_qr_code_subtitle"))

    convenience init(for username: String, name: String) {
        self.init(nibName: nil, bundle: nil)

        self.username = username
        title = Localized("profile_qr_code_title")

        qrCodeImageView.image = UIImage.imageQRCode(for: "\(QRCodeController.addUsernameBasePath)\(username)", resizeRate: 20.0)
    }

    open override func loadView() {
        let scrollView = UIScrollView()

        view = scrollView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.2
        qrCodeImageView.addGestureRecognizer(longPressGesture)
        
        view.backgroundColor = Theme.lightGrayBackgroundColor
        
        let contentView = UIView()
        view.addSubview(contentView)

        contentView.edges(to: view)
        contentView.width(to: view)
        contentView.height(to: layoutGuide(), relation: .equalOrGreater)
        
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(qrCodeImageView)

        subtitleLabel.top(to: contentView, offset: 13)
        subtitleLabel.left(to: view, offset: 20)
        subtitleLabel.right(to: view, offset: -20)

        let qrCodeTopLayoutGuide = UILayoutGuide()
        contentView.addLayoutGuide(qrCodeTopLayoutGuide)

        qrCodeTopLayoutGuide.topToBottom(of: subtitleLabel)
        qrCodeTopLayoutGuide.height(40, relation: .equalOrGreater)
        qrCodeTopLayoutGuide.left(to: contentView)
        qrCodeTopLayoutGuide.right(to: contentView)

        qrCodeImageView.topToBottom(of: qrCodeTopLayoutGuide)
        qrCodeImageView.height(300)
        qrCodeImageView.width(300)
        qrCodeImageView.centerX(to: contentView)
        
        let qrCodeBottomLayoutGuide = UILayoutGuide()
        contentView.addLayoutGuide(qrCodeBottomLayoutGuide)

        qrCodeBottomLayoutGuide.topToBottom(of: qrCodeImageView)
        qrCodeBottomLayoutGuide.left(to: contentView)
        qrCodeBottomLayoutGuide.right(to: contentView)
        qrCodeBottomLayoutGuide.bottom(to: contentView)
        qrCodeBottomLayoutGuide.height(to: qrCodeTopLayoutGuide)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        preferLargeTitleIfPossible(true)
    }

    @objc private func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began  else { return }

        if let recognizerView = sender.view, let recognizerSuperView = recognizerView.superview, recognizerView.becomeFirstResponder() {
            let menuController = UIMenuController.shared
            menuController.setTargetRect(recognizerView.frame, in: recognizerSuperView)
            menuController.setMenuVisible(true, animated:true)
        }
    }
}

extension QRCodeController: UIToolbarDelegate {

    func position(for _: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}
