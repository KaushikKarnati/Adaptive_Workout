import WorkoutDomain

/// Implementations must capture and compare-and-save under the same consistency
/// boundary, including every revision and the action receipt. Independent reads
/// of the existing separate stores do not satisfy this contract.
public protocol SessionGenerationSource {
  func capture(_ requestId: String) throws -> CapturedSessionInputs
  func saveIfCurrent(
    captured: CapturedSessionInputs, result: SessionCompositionResult, actionId: String) throws
}
public struct CapturedSessionInputs: Sendable {
  public let revisionToken: String
  public let input: SessionCompositionInput
  public init(revisionToken: String, input: SessionCompositionInput) {
    self.revisionToken = revisionToken
    self.input = input
  }
}
/// No production source is registered until an atomic cross-store capture exists.
public struct SessionGenerationService {
  public let source: any SessionGenerationSource
  public let composer: SessionComposer
  public init(source: any SessionGenerationSource, composer: SessionComposer) {
    self.source = source
    self.composer = composer
  }
  public func generate(_ requestId: String, actionId: String) throws -> SessionCompositionResult {
    let captured = try source.capture(requestId)
    let result = composer.compose(captured.input)
    if result.snapshot != nil {
      try source.saveIfCurrent(captured: captured, result: result, actionId: actionId)
    }
    return result
  }
}
