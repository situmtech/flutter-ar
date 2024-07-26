//
//  FLNativeView.swift
//  situm_flutter_ar
//
//  Created by Rodrigo Lago on 24/7/24.
//

import Foundation
import Flutter
import UIKit
import WebKit

class FLNativeViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return FLNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger)
    }

    /// Implementing this method is only necessary when the `arguments` in `createWithFrame` is not `nil`.
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
          return FlutterStandardMessageCodec.sharedInstance()
    }
}

class FLNativeView: NSObject, FlutterPlatformView {
    private var _view: UIView

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        _view = UIView()
        super.init()
        // iOS views can be created here
        if #available(iOS 13.0, *) {
            createNativeView(view: _view)
        } else {
            createNativeViewAltarnative(view: _view)
        }
    }

    func view() -> UIView {
        return _view
    }

    @available(iOS 13.0, *)
    func createNativeView(view _view: UIView) {
        _view.backgroundColor = UIColor.blue

        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.preferences.javaScriptEnabled = true
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.websiteDataStore = .default()

        let webView = WKWebView(frame: _view.bounds, configuration: webConfiguration)
        webView.translatesAutoresizingMaskIntoConstraints = false

        _view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: _view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: _view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: _view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: _view.bottomAnchor)
        ])

        // Load the URL in a background thread to keep the UI responsive.
        DispatchQueue.global(qos: .userInitiated).async {
            if let url = URL(string: "https://map-viewer.situm.com") {
                let request = URLRequest(url: url)
                DispatchQueue.main.async {
                    webView.load(request)
                }
            }
        }
    }
    
    func createNativeViewAltarnative(view _view: UIView){
            _view.backgroundColor = UIColor.blue
            let nativeLabel = UILabel()
            nativeLabel.text = "Native text from iOS"
            nativeLabel.textColor = UIColor.white
            nativeLabel.textAlignment = .center
            nativeLabel.frame = CGRect(x: 0, y: 0, width: 180, height: 48.0)
            _view.addSubview(nativeLabel)
        }
}

