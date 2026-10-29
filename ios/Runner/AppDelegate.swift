import Flutter
import UIKit
import GoogleCast

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RemoteCastCapabilities") {
      FlutterMethodChannel(name: "chromecast_remote/cast_capabilities", binaryMessenger: registrar.messenger())
        .setMethodCallHandler { call, result in
          guard call.method == "read" else { result(FlutterMethodNotImplemented); return }
          guard GCKCastContext.isSharedInstanceInitialized(),
                let session = GCKCastContext.sharedInstance().sessionManager.currentCastSession,
                let status = session.remoteMediaClient?.mediaStatus else { result(nil); return }
          result([
            "deviceId": session.device.deviceID,
            "mediaSessionId": status.mediaSessionID,
            "seek": status.isMediaCommandSupported(kGCKMediaCommandSeek),
            "pause": status.isMediaCommandSupported(kGCKMediaCommandPause)
          ])
        }
    }
  }
}
