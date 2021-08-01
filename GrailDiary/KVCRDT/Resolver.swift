import KeyValueCRDT
import Foundation

public protocol Resolver {
  /// Given a non-empty array of versions, returns the "winning" value according to some algorithm.
  func resolveVersions(_ versions: [Version]) -> Value?
}

public struct LastWriterWinsResolver: Resolver {
  public func resolveVersions(_ versions: [Version]) -> Value? {
    versions.max(by: { $0.timestamp < $1.timestamp })?.value
  }
}

extension Resolver where Self == LastWriterWinsResolver {
  static var lastWriterWins: LastWriterWinsResolver { LastWriterWinsResolver() }
}

extension Array where Element == Version {
  func resolved(with resolver: Resolver) -> Value? {
    resolver.resolveVersions(self)
  }
}
