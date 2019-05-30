// Copyright © 2017-present Brian's Brain. All rights reserved.

import AVFoundation
import Foundation

@objc public final class PersonalitySpeechSynthesizer: NSObject {
  public typealias SpeechCompletionBlock = () -> Void

  public init(voice: AVSpeechSynthesisVoice) {
    self.voice = voice
    self.speechSynthesizer = AVSpeechSynthesizer()
    super.init()
    speechSynthesizer.delegate = self
  }

  private let voice: AVSpeechSynthesisVoice
  private let speechSynthesizer: AVSpeechSynthesizer
  private var completionBlocks: [AVSpeechUtterance: SpeechCompletionBlock] = [:]

  public func speak(_ utterance: AVSpeechUtterance, completion: SpeechCompletionBlock? = nil) {
    if let completion = completion {
      completionBlocks[utterance] = completion
    }
    utterance.voice = voice
    speechSynthesizer.speak(utterance)
  }
}

extension PersonalitySpeechSynthesizer {
  public static let british: PersonalitySpeechSynthesizer = {
    PersonalitySpeechSynthesizer.make(with: "en-GB")
  }()

  public static let spanish: PersonalitySpeechSynthesizer = {
    PersonalitySpeechSynthesizer.make(with: "es-MX")
  }()

  /// Maps from a language code to a PeronalitySpeechSynthesizer that ues that language.
  private static var personalitySpeechSynthesizers = [String: PersonalitySpeechSynthesizer]()

  public static func make(with language: String) -> PersonalitySpeechSynthesizer {
    if let synthesizer = personalitySpeechSynthesizers[language] {
      return synthesizer
    } else {
      let voice = AVSpeechSynthesisVoice(language: language)!
      let synthesizer = PersonalitySpeechSynthesizer(voice: voice)
      personalitySpeechSynthesizers[language] = synthesizer
      return synthesizer
    }
  }
}

extension PersonalitySpeechSynthesizer: AVSpeechSynthesizerDelegate {
  public func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didFinish utterance: AVSpeechUtterance
  ) {
    if let completion = completionBlocks[utterance] {
      completion()
      completionBlocks[utterance] = nil
    }
  }
}
