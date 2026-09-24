import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let hapticsEnabledKey = "adaptiveWorkout.hapticsEnabled"
  private var hapticsChannel: FlutterMethodChannel?
  private lazy var selectionFeedback = UISelectionFeedbackGenerator()
  private lazy var impactFeedback = UIImpactFeedbackGenerator(style: .light)
  private lazy var notificationFeedback = UINotificationFeedbackGenerator()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "adaptive_workout/haptics",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "Haptics are unavailable.", details: nil))
        return
      }
      self.handleHaptics(call, result: result)
    }
    hapticsChannel = channel
  }

  private var hapticsEnabled: Bool {
    UserDefaults.standard.object(forKey: Self.hapticsEnabledKey) as? Bool ?? true
  }

  private func handleHaptics(_ call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "isEnabled":
      result(hapticsEnabled)
    case "setEnabled":
      guard let value = call.arguments as? NSNumber,
        CFGetTypeID(value) == CFBooleanGetTypeID()
      else {
        result(FlutterError(
          code: "invalid_arguments", message: "Expected a boolean haptics preference.", details: nil
        ))
        return
      }
      UserDefaults.standard.set(value.boolValue, forKey: Self.hapticsEnabledKey)
      result(nil)
    case "play":
      guard let value = call.arguments as? String, let kind = HapticKind(rawValue: value) else {
        result(FlutterError(
          code: "invalid_arguments", message: "Expected a supported haptic kind.", details: nil
        ))
        return
      }
      if hapticsEnabled && UIApplication.shared.applicationState == .active {
        playHaptic(kind)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func playHaptic(_ kind: HapticKind) {
    // UIKit chooses whether feedback is available and permitted by the system.
    switch kind {
    case .selection:
      selectionFeedback.selectionChanged()
    case .impact:
      impactFeedback.impactOccurred()
    case .success:
      notificationFeedback.notificationOccurred(.success)
    case .warning:
      notificationFeedback.notificationOccurred(.warning)
    case .error:
      notificationFeedback.notificationOccurred(.error)
    }
  }
}

private enum HapticKind: String {
  case selection, impact, success, warning, error
}
