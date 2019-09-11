// Copyright © 2017-present Brian's Brain. All rights reserved.

import AVFoundation
import CocoaLumberjack
import Foundation

/// Interface to the AVSpeechSynthesizer with diagnostic logging, automatic voice selection.
final class LoggingSpeechSynthesizer: NSObject {
  /// Singleton access.
  static let shared = LoggingSpeechSynthesizer()

  private override init() {
    self.speechSynthesizer = AVSpeechSynthesizer()
    super.init()
    speechSynthesizer.delegate = self
    LoggingSpeechSynthesizer.enableAudioPlayback()
  }

  private let speechSynthesizer: AVSpeechSynthesizer
  private let voiceForLanguage = NSCache<NSString, AVSpeechSynthesisVoice>()

  func speakWord(_ word: VocabularyChallengeTemplate.Word) {
    let utterance = AVSpeechUtterance(string: word.text)
    utterance.voice = voice(for: word.language)
    speechSynthesizer.speak(utterance)
  }

  /// Enable audio even if the phone is muted -- key for spoken lessons
  private static func enableAudioPlayback() {
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
      try AVAudioSession.sharedInstance().setActive(true, options: [])
    } catch {
      DDLogError("Unexpected error configuring audio: \(error)")
    }
  }

  /// Find a voice for this language. Prefer voices of enhanced quality.
  private func voice(for language: String) -> AVSpeechSynthesisVoice? {
    let key = language as NSString
    if let cachedVoice = voiceForLanguage.object(forKey: key) {
      return cachedVoice
    }
    let voices = AVSpeechSynthesisVoice.speechVoices().filter { currentVoice -> Bool in
      currentVoice.language.range(of: language, options: [.anchored, .caseInsensitive]) != nil
    }
    .sorted { (lhs, rhs) -> Bool in
      lhs.quality.rawValue > rhs.quality.rawValue
    }
    if let voice = voices.first {
      voiceForLanguage.setObject(voice, forKey: key)
      return voice
    }
    return nil
  }
}

extension LoggingSpeechSynthesizer: AVSpeechSynthesizerDelegate {
  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
    DDLogInfo("Started \(utterance.speechString)")
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    DDLogInfo("Finished \(utterance.speechString)")
  }
}
