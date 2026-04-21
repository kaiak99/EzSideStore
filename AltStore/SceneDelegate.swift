//
//  SceneDelegate.swift
//  AltStore
//
//  Created by Riley Testut on 7/6/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import UIKit
import AltStoreCore

@available(iOS 13, *)
final class SceneDelegate: UIResponder, UIWindowSceneDelegate
{
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions)
    {
        guard let _ = (scene as? UIWindowScene) else { return }
        
        // ==========================================
        // FORZA ICONA INGRANAGGIO PER SETTINGS (Tab 1)
        // ==========================================
        if let tabBarController = window?.rootViewController as? UITabBarController,
           let viewControllers = tabBarController.viewControllers,
           viewControllers.count >= 2 {
            
            // L'indice 1 è il tab Settings
            viewControllers[1].tabBarItem.image = UIImage(systemName: "gear")
            viewControllers[1].tabBarItem.selectedImage = UIImage(systemName: "gear")
        }
        // ==========================================
        
        if let context = connectionOptions.urlContexts.first
        {
            self.open(context)
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene)
    {
        guard DatabaseManager.shared.isStarted else { return }
        
        AppManager.shared.update()
        if UserDefaults.standard.enableEMPforWireguard {
            startEMProxy(bind_addr: AppConstants.Proxy.serverURL)
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene)
    {
        guard UIApplication.shared.applicationState == .background else { return }
        
        if UserDefaults.standard.enableEMPforWireguard {
            stopEMProxy()
        }

        guard let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) else { return }
        
        let midnightOneMonthAgo = Calendar.current.startOfDay(for: oneMonthAgo)
        DatabaseManager.shared.purgeLoggedErrors(before: midnightOneMonthAgo) { result in
            switch result
            {
            case .success: break
            case .failure(let error): print("[ALTLog] Failed to purge logged errors before \(midnightOneMonthAgo).", error)
            }
        }
        
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>)
    {
        guard let context = URLContexts.first else { return }
        self.open(context)
    }
}

private extension SceneDelegate
{
    func open(_ context: UIOpenURLContext)
    {
        if context.url.isFileURL
        {
            guard context.url.pathExtension.lowercased() == "ipa" else { return }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: AppDelegate.importAppDeepLinkNotification, object: nil, userInfo: [AppDelegate.importAppDeepLinkURLKey: context.url])
            }
        }
        else
        {
            guard let components = URLComponents(url: context.url, resolvingAgainstBaseURL: false) else { return }
            guard let host = components.host?.lowercased() else { return }
            
            guard let tabBarController = window?.rootViewController as? UITabBarController else { return }

            switch host
            {
            case "appbackupresponse":
                let result: Result<Void, Error>
                
                switch context.url.path.lowercased()
                {
                case "/success": result = .success(())
                case "/failure":
                    let queryItems = components.queryItems?.reduce(into: [String: String]()) { $0[$1.name] = $1.value } ?? [:]
                    guard
                        let errorDomain = queryItems["errorDomain"],
                        let errorCodeString = queryItems["errorCode"], let errorCode = Int(errorCodeString),
                        let errorDescription = queryItems["errorDescription"]
                    else { return }
                    
                    let error = NSError(domain: errorDomain, code: errorCode, userInfo: [NSLocalizedDescriptionKey: errorDescription])
                    result = .failure(error)
                    
                default: return
                }
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: AppDelegate.appBackupDidFinish, object: nil, userInfo: [AppDelegate.appBackupResultKey: result])
                }
                
            case "install", "apps", "myapps":
                DispatchQueue.main.async {
                    // Indice 0 = My Apps
                    tabBarController.selectedIndex = 0
                    
                    if host == "install" {
                        let queryItems = components.queryItems?.reduce(into: [String: String]()) { $0[$1.name.lowercased()] = $1.value } ?? [:]
                        if let downloadURLString = queryItems["url"], let downloadURL = URL(string: downloadURLString) {
                            NotificationCenter.default.post(name: AppDelegate.importAppDeepLinkNotification, object: nil, userInfo: [AppDelegate.importAppDeepLinkURLKey: downloadURL])
                        }
                    }
                }
            
            case "source", "sources":
                // Ignoriamo sources dato che abbiamo rimosso il tab, andiamo su My Apps
                DispatchQueue.main.async {
                    tabBarController.selectedIndex = 0
                }
                
            case "settings":
                // Indice 1 = Settings
                tabBarController.selectedIndex = 1
                
            case "pairing":
                let queryItems = components.queryItems?.reduce(into: [String: String]()) { $0[$1.name.lowercased()] = $1.value } ?? [:]
                Logger.main.info("queryItems \(queryItems)")
                guard let callbackTemplate = queryItems["urlname"]?.removingPercentEncoding else { return }
                
                DispatchQueue.main.async {
                    exportPairingFile(callbackTemplate)
                }
                
            case "certificate":
                let queryItems = components.queryItems?.reduce(into: [String: String]()) { $0[$1.name.lowercased()] = $1.value } ?? [:]
                guard let callbackTemplate = queryItems["callback_template"]?.removingPercentEncoding else { return }
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: AppDelegate.exportCertificateNotification, object: nil, userInfo: [AppDelegate.exportCertificateCallbackTemplateKey: callbackTemplate])
                }

            default: break
            }
        }
    }
}

func exportPairingFile(_ urlname: String) {
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = windowScene.windows.first, let viewcontroller = window.rootViewController {
        let fm = FileManager.default
        let documentsPath = fm.documentsDirectory.appendingPathComponent("ALTPairingFile.mobiledevicepairing")
        
        guard let data = try? Data(contentsOf: documentsPath) else {
            let toastView = ToastView(text: NSLocalizedString("Failed to find Pairing File!", comment: ""), detailText: nil)
            toastView.show(in: viewcontroller)
            return
        }
        
        let base64encodedCert = data.base64EncodedString()
        var allowedQueryParamAndKey = NSCharacterSet.urlQueryAllowed
        allowedQueryParamAndKey.remove(charactersIn: ";/?:@&=+$, ")
        guard let encodedCert = base64encodedCert.addingPercentEncoding(withAllowedCharacters: allowedQueryParamAndKey) else {
            let toastView = ToastView(text: NSLocalizedString("Failed to encode pairingFile!", comment: ""), detailText: nil)
            toastView.show(in: viewcontroller)
            return
        }
        
        var urlStr = "\(urlname)://pairingFile?data=$(BASE64_PAIRING)"
        let finished = urlStr.replacingOccurrences(of: "$(BASE64_PAIRING)", with: encodedCert, options: .literal, range: nil)
        
        print(finished)
        guard let callbackUrl = URL(string: finished) else {
            let toastView = ToastView(text: NSLocalizedString("Failed to initialize callback URL!", comment: ""), detailText: nil)
            toastView.show(in: viewcontroller)
            return
        }
        UIApplication.shared.open(callbackUrl)
    }
}