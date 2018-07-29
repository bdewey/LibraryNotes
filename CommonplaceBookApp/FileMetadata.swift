// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

struct FileMetadata {
  
  let metadataItem: NSMetadataItem
  
  init(metadataItem: NSMetadataItem) {
    assert(metadataItem.attributes.contains(NSMetadataItemURLKey))
    assert(metadataItem.attributes.contains(NSMetadataItemDisplayNameKey))
    assert(metadataItem.attributes.contains(NSMetadataItemContentTypeKey))
    self.metadataItem = metadataItem
  }
  
  var fileURL: URL {
    return metadataItem.value(forAttribute: NSMetadataItemURLKey) as! URL
  }
  
  var displayName: String {
    let nsstring = metadataItem.value(forAttribute: NSMetadataItemDisplayNameKey) as! NSString
    return String(nsstring)
  }
  
  var contentType: String {
    let nsstring = metadataItem.value(forAttribute: NSMetadataItemContentTypeKey) as! NSString
    return String(nsstring)
  }
}
