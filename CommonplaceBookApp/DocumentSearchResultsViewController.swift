// Copyright © 2017-present Brian's Brain. All rights reserved.

import MiniMarkdown
import UIKit

/// Shows search results.
final class DocumentSearchResultsViewController: UIViewController {
  init(notebook: NoteArchiveDocument, delegate: DocumentTableControllerDelegate) {
    self.notebook = notebook
    self.delegate = delegate
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private lazy var tableView: UITableView = DocumentTableController.makeTableView()

  private let notebook: NoteArchiveDocument
  public weak var delegate: DocumentTableControllerDelegate?
  public var dataSource: DocumentTableController?

  override func loadView() {
    view = tableView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    let dataSource = DocumentTableController(tableView: tableView, notebook: notebook)
    dataSource.delegate = delegate
    self.dataSource = dataSource
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    dataSource?.startObservingNotebook()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    dataSource?.stopObservingNotebook()
  }
}
