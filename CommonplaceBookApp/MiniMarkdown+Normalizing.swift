// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation

import MiniMarkdown

public extension MiniMarkdown {
  
  public struct NormalizingBlocks {
    
    public typealias NormalizeBlock = (Block) -> [StringChange]
  }
}
