import BookKit
import Foundation
import SnapKit
import SwiftUI
import UIKit

public protocol BookEditDetailsViewControllerDelegate: AnyObject {
  func bookEditDetailsViewControllerDidCancel(_ viewController: BookEditDetailsViewController)
  func bookEditDetailsViewController(_ viewController: BookEditDetailsViewController, didFinishEditing book: AugmentedBook, coverImage: UIImage?)
}

/// A view controller that edits a `BookKit.AugmentedBook` structure.
public final class BookEditDetailsViewController: UIViewController {
  public init(book: AugmentedBook, coverImage: UIImage?) {
    self.model = BookEditViewModel(
      book: book,
      coverImage: coverImage
    )
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private var model: BookEditViewModel

  public weak var delegate: BookEditDetailsViewControllerDelegate?

  public override func viewDidLoad() {
    super.viewDidLoad()
    let hostingViewController = UIHostingController(rootView: BookEditView(model: model))
    view.addSubview(hostingViewController.view)
    hostingViewController.view.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }
    addChild(hostingViewController)
    hostingViewController.didMove(toParent: self)

    navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(handleCancel))
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(handleDone))
  }

  @objc private func handleCancel() {
    delegate?.bookEditDetailsViewControllerDidCancel(self)
  }

  @objc private func handleDone() {
    delegate?.bookEditDetailsViewController(self, didFinishEditing: model.book, coverImage: model.coverImage)
  }
}
