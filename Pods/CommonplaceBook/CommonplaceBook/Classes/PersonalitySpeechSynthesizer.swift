// Copyright © 2018 Brian's Brain. All rights reserved.

import Foundation
import AVFoundation

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
  private var completionBlocks: [AVSpeechUtterance : SpeechCompletionBlock] = [:]
  
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
    let voices = AVSpeechSynthesisVoice.speechVoices()
    let voice = AVSpeechSynthesisVoice(language: "en-GB")!
    return PersonalitySpeechSynthesizer(voice: voice)
  }()

  public static let spanish: PersonalitySpeechSynthesizer = {
    let voices = AVSpeechSynthesisVoice.speechVoices()
    let voice = AVSpeechSynthesisVoice(language: "es-MX")!
    return PersonalitySpeechSynthesizer(voice: voice)
  }()
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
