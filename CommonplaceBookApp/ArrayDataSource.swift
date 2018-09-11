// Copyright © 2018 Brian's Brain. All rights reserved.

import UIKit

final class ArrayDataSource<Model>: NSObject, UICollectionViewDataSource {

  let cellForModel: (Model, UICollectionView, IndexPath) -> UICollectionViewCell
  var models: [Model] = []

  init(cellForModel: @escaping (Model, UICollectionView, IndexPath) -> UICollectionViewCell) {
    self.cellForModel = cellForModel
    super.init()
  }

  func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }

  func collectionView(
    _ collectionView: UICollectionView,
    numberOfItemsInSection section: Int
  ) -> Int {
    return models.count
  }

  func collectionView(
    _ collectionView: UICollectionView,
    cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    return cellForModel(models[indexPath.row], collectionView, indexPath)
  }
}
