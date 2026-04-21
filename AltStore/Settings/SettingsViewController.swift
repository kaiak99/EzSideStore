//
//  SettingsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 8/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import SwiftUI
import SafariServices
import MessageUI
import Intents
import IntentsUI

import SemanticVersion
import AltStoreCore
import CAltSign
import UniformTypeIdentifiers

extension SettingsViewController
{
    private enum Section: Int, CaseIterable
    {
        case signIn
        case account
        case patreon
        case display
        case appRefresh
        case instructions
        case techyThings
        case credits
        case betaTesting
        case advancedSettings
        case signing
        case diagnostics
    }
    
    private enum AppRefreshRow: Int, CaseIterable
    {
        case backgroundRefresh
        case noIdleTimeout        
        case addToSiri
        case disableAppLimit
        
        static var allCases: [AppRefreshRow] {
            var c: [AppRefreshRow] = [.backgroundRefresh, .noIdleTimeout, .addToSiri]
            if UserDefaults.standard.isCowExploitSupported || !ProcessInfo().sparseRestorePatched {
                c.append(.disableAppLimit)
            }
            return c
        }
    }
    
    private enum CreditsRow: Int, CaseIterable
    {
        case developer
        case operations
        case designer
        case softwareLicenses
    }
    
    private enum TechyThingsRow: Int, CaseIterable
    {
        case errorLog
        case clearCache
    }
    
    private enum AdvancedSettingsRow: Int, CaseIterable
    {
        case sendFeedback
        case refreshAttempts
        case refreshSideJITServer
        case resetPairingFile
        case anisetteServers
        case vpnConfiguration
        case enableEMPForWiregaurd
        case customizeAppId
    }
    
    private enum SigningSettingsRow: Int, CaseIterable {
        case importAccount
        case exportAccount
        case importCert
        case exportCert
    }

    private enum BetaTestingRow: Int, CaseIterable {
        case betaUpdates
        case betaTrack
    }

    private enum DiagnosticsRow: Int, CaseIterable
    {
        case responseCaching
        case exportResignedApp
        case verboseOperationsLogging
        case exportDatabase
        case deleteDatabase
        case operationsLoggingControl
        case recreateDatabase
        case minimuxerConsoleLogging
    }
}

final class SettingsViewController: UITableViewController
{
    private var activeTeam: Team?
    
    private var prototypeHeaderFooterView: SettingsHeaderFooterView!
    
    @IBOutlet private var betaTrackLabel: UILabel!
    @IBOutlet private var betaTrackPopupButton: UIButton!

    private var debugGestureCounter = 0
    private weak var debugGestureTimer: Timer?
    
    @IBOutlet private var accountNameLabel: UILabel!
    @IBOutlet private var accountEmailLabel: UILabel!
    @IBOutlet private var accountTypeLabel: UILabel!
    
    @IBOutlet private var backgroundRefreshSwitch: UISwitch!
    @IBOutlet private var enableEMPforWireguard: UISwitch!
    @IBOutlet private var noIdleTimeoutSwitch: UISwitch!
    @IBOutlet private var disableAppLimitSwitch: UISwitch!
    @IBOutlet private var betaUpdatesSwitch: UISwitch!
    @IBOutlet private var customizeAppIdSwitch: UISwitch!
    @IBOutlet private var exportResignedAppsSwitch: UISwitch!
    @IBOutlet private var verboseOperationsLoggingSwitch: UISwitch!
    @IBOutlet private var minimuxerConsoleLoggingSwitch: UISwitch!
    
    @IBOutlet private var disableResponseCachingSwitch: UISwitch!
    
    @IBOutlet private var mastodonButton: UIButton!
    @IBOutlet private var threadsButton: UIButton!
    @IBOutlet private var twitterButton: UIButton!
    @IBOutlet private var githubButton: UIButton!
    
    @IBOutlet private var versionLabel: UILabel!
    
    @IBOutlet private var recreateDatabaseSwitch: UISwitch!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private static var exportDBInProgress = false
    private static var deleteDBInProgress = false
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.openPatreonSettings(_:)), name: AppDelegate.openPatreonSettingsDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.openErrorLog(_:)), name: ToastView.openErrorLogNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.openExportCertificateConfirm(_:)), name: AppDelegate.exportCertificateNotification, object: nil)
    }
    
    private func handleReleaseChannelSelection(_ channel: String) {
        UserDefaults.standard.betaUdpatesTrack = channel
        updateReleaseChannelButtonTitle()
    }
    
    private func updateReleaseChannelButtonTitle() {
        let channel = UserDefaults.standard.betaUdpatesTrack ?? UserDefaults.defaultBetaUpdatesTrack
        betaTrackPopupButton.setTitle(channel, for: .normal)
    }
    
    private func configureReleaseChannelButton() {
        let currentTrack = UserDefaults.standard.betaUdpatesTrack
        var trackOptions: [String] = ReleaseTracks.betaTracks.map {$0.rawValue}

        if let currentTrack{
            trackOptions = [currentTrack] + trackOptions.filter { $0 != currentTrack }
        }
    
        let items = trackOptions.map{ channel in
            UIAction(title: channel, handler: { [weak self] _ in
                self?.handleReleaseChannelSelection(channel)
            })
        }
        
        let menu = UIMenu(title: "", options: [.singleSelection, .displayInline], children: items)
        betaTrackPopupButton.menu = menu
        updateReleaseChannelButtonTitle()
    }


    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        if #available(iOS 26.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance       
        } 
        
        // ========================================================
        // INIETTA GRADIENTE ARANCIONE DI SFONDO (Sostituisce viola)
        // ========================================================
        let gradientView = UIView()
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1.0).cgColor, // Arancione chiaro in alto
            UIColor(red: 0.85, green: 0.35, blue: 0.0, alpha: 1.0).cgColor // Arancione scuro in basso
        ]
        gradientLayer.frame = UIScreen.main.bounds
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
        self.tableView.backgroundView = gradientView
        self.tableView.backgroundColor = .clear
        // ========================================================

        let nib = UINib(nibName: "SettingsHeaderFooterView", bundle: nil)
        self.prototypeHeaderFooterView = nib.instantiate(withOwner: nil, options: nil)[0] as? SettingsHeaderFooterView
        
        self.tableView.register(nib, forHeaderFooterViewReuseIdentifier: "HeaderFooterView")
        
        let debugModeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(SettingsViewController.handleDebugModeGesture(_:)))
        debugModeGestureRecognizer.delegate = self
        debugModeGestureRecognizer.direction = .up
        debugModeGestureRecognizer.numberOfTouchesRequired = 3
        self.tableView.addGestureRecognizer(debugModeGestureRecognizer)
        
        // ==========================================
        // IMPOSTA VERSIONE FISSA E NASCONDI SOCIAL
        // ==========================================
        self.versionLabel.text = "1.0"
        self.versionLabel.textColor = .white
        self.versionLabel.numberOfLines = 0
        self.versionLabel.lineBreakMode = .byWordWrapping
        self.versionLabel.setNeedsUpdateConstraints()
        
        self.mastodonButton?.isHidden = true
        self.threadsButton?.isHidden = true
        self.twitterButton?.isHidden = true
        self.githubButton?.isHidden = true
        self.tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: CGFloat.leastNormalMagnitude))
        // ==========================================

        self.tableView.contentInset.bottom = 40
        self.update()
        
        if #available(iOS 15, *)
        {
            if let appearance = self.tabBarController?.tabBar.standardAppearance
            {
                appearance.stackedLayoutAppearance.normal.badgeBackgroundColor = .altPrimary
                self.navigationController?.tabBarItem.scrollEdgeAppearance = appearance
            }
            
            for button in [self.mastodonButton!, self.threadsButton!, self.twitterButton!, self.githubButton!]
            {
                let image = button.configuration?.background.image
                button.configuration = nil
                button.setImage(image, for: .normal)
                button.imageView?.contentMode = .scaleAspectFit
            }
        }
        
        configureReleaseChannelButton()
        #if !targetEnvironment(simulator)
        detectAndImportAccountFile()
        #endif
    }
    
    func importAccountAtFile(_ file: URL, remove: Bool = false) {
        _ = file.startAccessingSecurityScopedResource()
        defer { file.stopAccessingSecurityScopedResource() }
        guard let accountD = try? Data(contentsOf: file) else {
            return Logger.main.notice("Could not parse data from file \(file)")
        }
        guard let account = try? Foundation.JSONDecoder().decode(ImportedAccount.self, from: accountD) else {
            return Logger.main.notice("Could not parse data from file \(file)")
        }
        print("We want to import this account probably: \(account)")
        if remove {
            try? FileManager.default.removeItem(at: file)
        }
        Keychain.shared.appleIDEmailAddress = account.email
        Keychain.shared.appleIDPassword = account.password
        Keychain.shared.adiPb = account.adiPB
        Keychain.shared.identifier = account.local_user
        signIn()
        update()
        if let altCert = ALTCertificate(p12Data: account.cert, password: account.certpass) {
            Keychain.shared.signingCertificate = altCert.encryptedP12Data(withPassword: "")!
            Keychain.shared.signingCertificatePassword = account.certpass
            let toastView = ToastView(text: NSLocalizedString("Successfully imported '\(account.email)'!", comment: ""), detailText: "SideStore should be fully operational!")
            return toastView.show(in: self)
        } else {
            let toastView = ToastView(text: NSLocalizedString("Failed to import account certificate!", comment: ""), detailText: "Failed to create ALTCertificate. Check if the password is correct. Still imported account/adi.pb details!")
            return toastView.show(in: self)
        }
    }
    
    func detectAndImportAccountFile() {
        let accountFileURL = FileManager.default.documentsDirectory.appendingPathComponent("Account.sideconf")
        #if !DEBUG
        importAccountAtFile(accountFileURL, remove: true)
        #else
        importAccountAtFile(accountFileURL)
        #endif
    }
    
    func exportAccount(_ certpass: String) -> ImportedAccount? {
        guard let email = Keychain.shared.appleIDEmailAddress,
              let password = Keychain.shared.appleIDPassword,
              let cert = Keychain.shared.signingCertificate,
              let identifier = Keychain.shared.identifier,
              let adiPB = Keychain.shared.adiPb else {
            return nil
        }
        return ImportedAccount(email: email, password: password, cert: cert, certpass: certpass, local_user: identifier, adiPB: adiPB)
    }
    
    func showExportAccount() {
        
        Task {
            guard let password = await withUnsafeContinuation({ (c: UnsafeContinuation<String?,Never>) in
                let alertController = UIAlertController(title: NSLocalizedString("Please enter the password for the certificate.", comment: ""), message: nil, preferredStyle: .alert)
                
                alertController.addTextField { (textField) in
                    textField.autocorrectionType = .no
                    textField.autocapitalizationType = .none
                }
                
                let submitAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { (action) in
                    let textField = alertController.textFields?.first
                    let code = textField?.text ?? ""
                    c.resume(returning: code)
                }
                alertController.addAction(submitAction)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { (action) in
                    c.resume(returning: nil)
                })
                
                self.present(alertController, animated: true)
            }) else {
                return
            }
            
            guard let account = exportAccount(password) else {
                let toastView = ToastView(text: NSLocalizedString("Failed to export account!", comment: ""), detailText: "Account not found.")
                return toastView.show(in: self)
            }
            
            guard let accountData = try? Foundation.JSONEncoder().encode(account) else {
                let toastView = ToastView(text: NSLocalizedString("Failed to export account data!", comment: ""), detailText: "Account malformed.")
                toastView.show(in: self)
                return
            }
            
            let accountTmpPath = FileManager.default.temporaryDirectory.appendingPathComponent("\(account.email).sideconf")
            do {
                try accountData.write(to: accountTmpPath)
            } catch {
                let toastView = ToastView(text: NSLocalizedString("Failed to export account!", comment: ""), detailText: error.localizedDescription)
                toastView.show(in: self)
                return
            }
            let exportVC = UIDocumentPickerViewController(forExporting: [accountTmpPath], asCopy: false)
            self.present(exportVC, animated: true)
        }
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        self.update()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "anisetteServers" {
            let controller = segue.destination
            self.show(controller, sender: nil)
        } else {
            super.prepare(for: segue, sender: sender)
        }
    }

}

private extension SettingsViewController
{
    func update()
    {
        if let team = DatabaseManager.shared.activeTeam()
        {
            self.accountNameLabel.text = team.name
            self.accountEmailLabel.text = team.account.appleID
            self.accountTypeLabel.text = team.type.localizedDescription
            self.activeTeam = team
        }
        else
        {
            self.activeTeam = nil
        }
        
        self.backgroundRefreshSwitch.isOn = UserDefaults.standard.isBackgroundRefreshEnabled
        self.enableEMPforWireguard.isOn = UserDefaults.standard.enableEMPforWireguard
        self.noIdleTimeoutSwitch.isOn = UserDefaults.standard.isIdleTimeoutDisableEnabled
        self.disableAppLimitSwitch.isOn = UserDefaults.standard.isAppLimitDisabled
        self.customizeAppIdSwitch.isOn = UserDefaults.standard.customizeAppId
        self.betaUpdatesSwitch.isOn = UserDefaults.standard.isBetaUpdatesEnabled
        self.betaTrackPopupButton.isEnabled = UserDefaults.standard.isBetaUpdatesEnabled
        self.disableResponseCachingSwitch.isOn = UserDefaults.standard.responseCachingDisabled
        self.exportResignedAppsSwitch.isOn = UserDefaults.standard.isExportResignedAppEnabled
        self.verboseOperationsLoggingSwitch.isOn = UserDefaults.standard.isVerboseOperationsLoggingEnabled
        self.minimuxerConsoleLoggingSwitch.isOn = UserDefaults.standard.isMinimuxerConsoleLoggingEnabled
        self.recreateDatabaseSwitch.isOn = UserDefaults.standard.recreateDatabaseOnNextStart

        if self.isViewLoaded
        {
            self.tableView.reloadData()
        }
    }
    
    private func prepare(_ settingsHeaderFooterView: SettingsHeaderFooterView, for section: Section, isHeader: Bool)
    {
        settingsHeaderFooterView.primaryLabel.isHidden = !isHeader
        settingsHeaderFooterView.secondaryLabel.isHidden = true // NASCONDE I TESTI LUNGHI
        settingsHeaderFooterView.button.isHidden = true
        settingsHeaderFooterView.layoutMargins.bottom = isHeader ? 0 : 8
        settingsHeaderFooterView.primaryLabel.textColor = .white // Titoli bianchi per contrasto sul gradiente arancione
        
        switch section
        {
        case .signIn, .account:
            if isHeader { settingsHeaderFooterView.primaryLabel.text = "ACCOUNT" }
            if section == .account {
                settingsHeaderFooterView.button.setTitle(NSLocalizedString("SIGN OUT", comment: ""), for: .normal)
                settingsHeaderFooterView.button.addTarget(self, action: #selector(SettingsViewController.signOut(_:)), for: .primaryActionTriggered)
                settingsHeaderFooterView.button.isHidden = false
            }
        case .appRefresh:
            if isHeader { settingsHeaderFooterView.primaryLabel.text = "REFRESHING APPS" }
        case .techyThings:
            if isHeader { settingsHeaderFooterView.primaryLabel.text = "TECHY THINGS" }
        case .advancedSettings:
            if isHeader { settingsHeaderFooterView.primaryLabel.text = "ADVANCED SETTINGS" }
        case .signing:
            if isHeader { settingsHeaderFooterView.primaryLabel.text = "SIGNING" }
        case .diagnostics:
            if isHeader { settingsHeaderFooterView.primaryLabel.text = "DIAGNOSTICS" }
        default: break
        }
    }
    
    private func preferredHeight(for settingsHeaderFooterView: SettingsHeaderFooterView, in section: Section, isHeader: Bool) -> CGFloat
    {
        let widthConstraint = settingsHeaderFooterView.contentView.widthAnchor.constraint(equalToConstant: tableView.bounds.width)
        NSLayoutConstraint.activate([widthConstraint])
        defer { NSLayoutConstraint.deactivate([widthConstraint]) }
        self.prepare(settingsHeaderFooterView, for: section, isHeader: isHeader)
        let size = settingsHeaderFooterView.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return size.height
    }
    
    private func isSectionHidden(_ section: Section) -> Bool
    {
        switch section {
        // Nascondiamo interamente le sezioni che non servono
        case .patreon, .display, .instructions, .credits, .betaTesting:
            return true
        default: return false
        }
    }
    
    // Funzione helper per filtrare e far collassare le celle rimosse per mantenere gli angoli curvi corretti
    private func visibleRows(for section: Section) -> [Int] {
        switch section {
        case .appRefresh:
            var rows = [AppRefreshRow.backgroundRefresh.rawValue, AppRefreshRow.noIdleTimeout.rawValue]
            if AppRefreshRow.allCases.contains(.disableAppLimit) { rows.append(AppRefreshRow.disableAppLimit.rawValue) }
            return rows
        case .techyThings:
            return [TechyThingsRow.clearCache.rawValue]
        case .advancedSettings:
            return [
                AdvancedSettingsRow.refreshSideJITServer.rawValue,
                AdvancedSettingsRow.resetPairingFile.rawValue,
                AdvancedSettingsRow.anisetteServers.rawValue,
                AdvancedSettingsRow.vpnConfiguration.rawValue,
                AdvancedSettingsRow.enableEMPForWiregaurd.rawValue,
                AdvancedSettingsRow.customizeAppId.rawValue
            ]
        default:
            let count = super.tableView(self.tableView, numberOfRowsInSection: section.rawValue)
            return count > 0 ? Array(0..<count) : []
        }
    }
}

private extension SettingsViewController
{
    func signIn()
    {
        AppManager.shared.authenticate(presentingViewController: self) { (result) in
            DispatchQueue.main.async {
                switch result
                {
                case .failure(OperationError.cancelled): break
                case .failure(let error):
                    let toastView = ToastView(error: error)
                    toastView.show(in: self)
                case .success: break
                }
                self.update()
            }
        }
    }
    
    @objc func signOut(_ sender: UIBarButtonItem)
    {
        func signOut() {
            DatabaseManager.shared.signOut { (error) in
                DispatchQueue.main.async {
                    if let error = error {
                        let toastView = ToastView(error: error)
                        toastView.show(in: self)
                    }
                    self.update()
                }
            }
        }
        
        let alertController = UIAlertController(title: NSLocalizedString("Are you sure you want to sign out?", comment: ""), message: NSLocalizedString("You will no longer be able to install or refresh apps once you sign out.", comment: ""), preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Sign Out", comment: ""), style: .destructive) { _ in signOut() })
        alertController.addAction(.cancel)
        alertController.popoverPresentationController?.barButtonItem = sender
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func toggleDisableAppLimit(_ sender: UISwitch) {
        if UserDefaults.standard.isCowExploitSupported || !ProcessInfo().sparseRestorePatched {
            UserDefaults.standard.isAppLimitDisabled = sender.isOn
            if UserDefaults.standard.activeAppsLimit != nil {
                UserDefaults.standard.activeAppsLimit = InstalledApp.freeAccountActiveAppsLimit
            }
        }
    }
    
    @IBAction func toggleResignedAppExport(_ sender: UISwitch) { UserDefaults.standard.isExportResignedAppEnabled = sender.isOn }
    @IBAction func toggleVerboseOperationsLogging(_ sender: UISwitch) { UserDefaults.standard.isVerboseOperationsLoggingEnabled = sender.isOn }
    @IBAction func toggleMinimuxerConsoleLogging(_ sender: UISwitch) { UserDefaults.standard.isMinimuxerConsoleLoggingEnabled = sender.isOn }
    @IBAction func toggleMinimuxerStatusCheck(_ sender: UISwitch) { UserDefaults.standard.isMinimuxerStatusCheckEnabled = sender.isOn }
    
    @IBAction func toggleRecreateDatabaseSwitch(_ sender: UISwitch) {
        UserDefaults.standard.recreateDatabaseOnNextStart = sender.isOn
        guard sender.isOn else { return }
        
        DispatchQueue.global().async {
            for time in (1...3).reversed() {
                DispatchQueue.main.async {
                    guard UserDefaults.standard.recreateDatabaseOnNextStart else { return }
                    let toast = ToastView(text: "Database Delete Scheduled on Next Launch", detailText: "App is closing in \(time) seconds...")
                    toast.tintColor = .altPrimary
                    toast.preferredDuration = 1
                    toast.show(in: self)
                }
                sleep(1)
            }
            DispatchQueue.main.async {
                guard UserDefaults.standard.recreateDatabaseOnNextStart else { return }
                exit(0)
            }
        }
    }

    @IBAction func toggleEnableBetaUpdates(_ sender: UISwitch) {
        betaTrackLabel.isEnabled = sender.isOn
        betaTrackPopupButton.isEnabled = sender.isOn
        UserDefaults.standard.isBetaUpdatesEnabled = sender.isOn
    }
    
    @IBAction func toggleEnableAppIdCustomization(_ sender: UISwitch) { UserDefaults.standard.customizeAppId = sender.isOn }
    @IBAction func toggleIsBackgroundRefreshEnabled(_ sender: UISwitch) { UserDefaults.standard.isBackgroundRefreshEnabled = sender.isOn }
    @IBAction func toggleEnableEMPforWireguard(_ sender: UISwitch) { UserDefaults.standard.enableEMPforWireguard = sender.isOn }
    @IBAction func toggleNoIdleTimeoutEnabled(_ sender: UISwitch) { UserDefaults.standard.isIdleTimeoutDisableEnabled = sender.isOn }
    @IBAction func toggleDisableResponseCaching(_ sender: UISwitch) { UserDefaults.standard.responseCachingDisabled = sender.isOn }
    
    func addRefreshAppsShortcut()
    {
        guard let shortcut = INShortcut(intent: INInteraction.refreshAllApps().intent) else { return }
        let viewController = INUIAddVoiceShortcutViewController(shortcut: shortcut)
        viewController.delegate = self
        viewController.modalPresentationStyle = .formSheet
        self.present(viewController, animated: true, completion: nil)
    }
    
    func clearCache()
    {
        let alertController = UIAlertController(title: NSLocalizedString("Are you sure you want to clear SideStore's cache?", comment: ""),
                                                message: NSLocalizedString("This will remove all temporary files as well as backups for uninstalled apps.", comment: ""),
                                                preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: UIAlertAction.cancel.title, style: UIAlertAction.cancel.style) { [weak self] _ in
            self?.tableView.indexPathForSelectedRow.map { self?.tableView.deselectRow(at: $0, animated: true) }
        })
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Clear Cache", comment: ""), style: .destructive) { [weak self] _ in
            AppManager.shared.clearAppCache { result in
                DispatchQueue.main.async {
                    self?.tableView.indexPathForSelectedRow.map { self?.tableView.deselectRow(at: $0, animated: true) }
                    switch result {
                    case .success: break
                    case .failure(let error):
                        let alertController = UIAlertController(title: NSLocalizedString("Unable to Clear Cache", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
                        alertController.addAction(.ok)
                        self?.present(alertController, animated: true)
                    }
                }
            }
        })
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        }
        self.present(alertController, animated: true)
    }
    
    @IBAction func handleDebugModeGesture(_ gestureRecognizer: UISwipeGestureRecognizer)
    {
        self.debugGestureCounter += 1
        self.debugGestureTimer?.invalidate()
        if self.debugGestureCounter >= 3 {
            self.debugGestureCounter = 0
            UserDefaults.standard.isDebugModeEnabled.toggle()
            self.tableView.reloadData()
        } else {
            self.debugGestureTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] (timer) in
                self?.debugGestureCounter = 0
            }
        }
    }
    
    func openTwitter(username: String) { }
    func openMastodon(username: String) { }
    func openThreads(username: String) { }
    @IBAction func followAltStoreMastodon() { }
    @IBAction func followAltStoreThreads() { }
    @IBAction func followAltStoreTwitter() { }
    @IBAction func followAltStoreGitHub() { }
}

private extension SettingsViewController
{
    @objc func openPatreonSettings(_ notification: Notification) { }
    @objc func openErrorLog(_: Notification) { }
    
    @objc func openExportCertificateConfirm(_ notification: Notification)
    {
        func export() {
            guard let template = notification.userInfo?[AppDelegate.exportCertificateCallbackTemplateKey] as? String,
                  template.contains("$(BASE64_CERT)") else { return }
            guard let data = Keychain.shared.signingCertificate,
            let password = Keychain.shared.signingCertificatePassword else { return }
            let base64encodedCert = data.base64EncodedString()
            var allowedQueryParamAndKey = NSCharacterSet.urlQueryAllowed
            allowedQueryParamAndKey.remove(charactersIn: ";/?:@&=+$, ")
            guard let encodedCert = base64encodedCert.addingPercentEncoding(withAllowedCharacters: allowedQueryParamAndKey) else { return }
            var urlStr = template.replacingOccurrences(of: "$(BASE64_CERT)", with: encodedCert, options: .literal, range: nil)
            urlStr = urlStr.replacingOccurrences(of: "$(PASSWORD)", with: password, options: .literal, range: nil)
            guard let callbackUrl = URL(string: urlStr) else { return }
            UIApplication.shared.open(callbackUrl)
        }
        
        let alertController = UIAlertController(title: NSLocalizedString("Export Certificate", comment: ""), message: NSLocalizedString("Do you want to export your certificate to an external app? That app will be able to sign apps using your certificate.", comment: ""), preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Export", comment: ""), style: .default) { _ in export() })
        alertController.addAction(.cancel)
        self.present(alertController, animated: true, completion: nil)
    }
}

// MARK: - Gestione Mappa Tabella
extension SettingsViewController
{
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        var numberOfSections = super.numberOfSections(in: tableView)
        if !UserDefaults.standard.isDebugModeEnabled { numberOfSections -= 1 }
        return numberOfSections
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let sectionType = Section.allCases[section]
        if isSectionHidden(sectionType) { return 0 }
        
        switch sectionType {
        case .signIn: return (self.activeTeam == nil) ? 1 : 0
        case .account: return (self.activeTeam == nil) ? 0 : 3
        default: return visibleRows(for: sectionType).count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let sectionType = Section.allCases[indexPath.section]
        var realRow = indexPath.row
        
        if sectionType != .signIn && sectionType != .account {
            realRow = visibleRows(for: sectionType)[indexPath.row]
        }
        
        let mappedPath = IndexPath(row: realRow, section: indexPath.section)
        let cell = super.tableView(tableView, cellForRowAt: mappedPath)
        
        // Questo Fixa gli angoli curvi per le prime celle come SideJITServer
        if let insetCell = cell as? InsetGroupTableViewCell {
            let totalRows = self.tableView(tableView, numberOfRowsInSection: indexPath.section)
            if totalRows == 1 {
                insetCell.style = .single
            } else if indexPath.row == 0 {
                insetCell.setValue(1, forKey: "style") // Top
            } else if indexPath.row == totalRows - 1 {
                insetCell.setValue(3, forKey: "style") // Bottom
            } else {
                insetCell.setValue(2, forKey: "style") // Middle
            }
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
    {
        let sectionType = Section.allCases[section]
        if isSectionHidden(sectionType) { return nil }
        if sectionType == .signIn && self.activeTeam != nil { return nil }
        if sectionType == .account && self.activeTeam == nil { return nil }
        
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderFooterView") as! SettingsHeaderFooterView
        self.prepare(headerView, for: sectionType, isHeader: true)
        return headerView
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView?
    {
        let empty = UIView()
        empty.backgroundColor = .clear
        return empty
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        let sectionType = Section.allCases[section]
        if isSectionHidden(sectionType) { return CGFloat.leastNormalMagnitude }
        if sectionType == .signIn && self.activeTeam != nil { return CGFloat.leastNormalMagnitude }
        if sectionType == .account && self.activeTeam == nil { return CGFloat.leastNormalMagnitude }
        return self.preferredHeight(for: self.prototypeHeaderFooterView, in: sectionType, isHeader: true)
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    {
        let sectionType = Section.allCases[section]
        if isSectionHidden(sectionType) { return CGFloat.leastNormalMagnitude }
        if sectionType == .signIn && self.activeTeam != nil { return CGFloat.leastNormalMagnitude }
        if sectionType == .account && self.activeTeam == nil { return CGFloat.leastNormalMagnitude }
        return 20.0
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let section = Section.allCases[indexPath.section]
        var realRow = indexPath.row
        if section != .signIn && section != .account { realRow = visibleRows(for: section)[indexPath.row] }
        
        switch section
        {
        case .signIn: self.signIn()
        case .techyThings:
            if TechyThingsRow.allCases[realRow] == .clearCache { self.clearCache() }
        case .advancedSettings:
            switch AdvancedSettingsRow.allCases[realRow] {
            case .refreshSideJITServer:
                if #available(iOS 17, *) {
                   let alertController = UIAlertController(title: NSLocalizedString("SideJITServer", comment: ""), message: NSLocalizedString("Settings for SideJITServer", comment: ""), preferredStyle: UIAlertController.Style.actionSheet)
                    if UserDefaults.standard.sidejitenable {
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("Disable", comment: ""), style: .default){ _ in UserDefaults.standard.sidejitenable = false })
                    } else {
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("Enable", comment: ""), style: .default){ _ in UserDefaults.standard.sidejitenable = true })
                    }
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Server Address", comment: ""), style: .default){ _ in
                        let alertController1 = UIAlertController(title: "SideJITServer Address", message: "Please Enter the SideJITServer Address Below.", preferredStyle: .alert)
                        alertController1.addTextField { textField in textField.placeholder = "SideJITServer Address" }
                        alertController1.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                        alertController1.addAction(UIAlertAction(title: "OK", style: .default) { _ in if let text = alertController1.textFields?.first?.text { UserDefaults.standard.textInputSideJITServerurl = text } })
                        self.present(alertController1, animated: true)
                    })
                   alertController.addAction(UIAlertAction(title: NSLocalizedString("Refresh", comment: ""), style: .destructive){ _ in
                      if UserDefaults.standard.sidejitenable {
                         var SJSURL = ""
                          if (UserDefaults.standard.textInputSideJITServerurl ?? "").isEmpty { SJSURL = "http://sidejitserver._http._tcp.local:8080" } else { SJSURL = UserDefaults.standard.textInputSideJITServerurl ?? "" }
                         let url = URL(string: SJSURL + "/re/")!
                         URLSession.shared.dataTask(with: url) { (data, response, error) in }.resume()
                      }
                   })
                   alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                   alertController.popoverPresentationController?.sourceView = self.tableView
                   alertController.popoverPresentationController?.sourceRect = self.tableView.rectForRow(at: indexPath)
                   self.present(alertController, animated: true)
                }
            case .resetPairingFile:
                let fm = FileManager.default
                let documentsPath = fm.documentsDirectory.appendingPathComponent("/ALTPairingFile.mobiledevicepairing")
                let alertController = UIAlertController(title: NSLocalizedString("Are you sure to reset the pairing file?", comment: ""), message: NSLocalizedString("You can reset the pairing file when you cannot sideload apps or enable JIT. You need to restart SideStore.", comment: ""), preferredStyle: UIAlertController.Style.actionSheet)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Delete and Reset", comment: ""), style: .destructive){ _ in
                    if fm.fileExists(atPath: documentsPath.path), let contents = try? String(contentsOf: documentsPath), !contents.isEmpty {
                        UserDefaults.standard.isPairingReset = true
                        try? fm.removeItem(atPath: documentsPath.path)
                    }
                    let dialogMessage = UIAlertController(title: NSLocalizedString("Pairing File Reset", comment: ""), message: NSLocalizedString("Please restart SideStore", comment: ""), preferredStyle: .alert)
                    dialogMessage.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(dialogMessage, animated: true, completion: nil)
                })
                alertController.addAction(.cancel)
                alertController.popoverPresentationController?.sourceView = self.tableView
                alertController.popoverPresentationController?.sourceRect = self.tableView.rectForRow(at: indexPath)
                self.present(alertController, animated: true)
            case .anisetteServers:
                let anisetteServersView = AnisetteServersView(selected: UserDefaults.standard.menuAnisetteURL, errorCallback: {
                    ToastView(text: "Cleared adi.pb!", detailText: "You will need to log back into Apple ID in SideStore.").show(in: self)
                }, refreshCallback: { _ in })
                let vc = UIHostingController(rootView: anisetteServersView)
                self.prepare(for: UIStoryboardSegue(identifier: "anisetteServers", source: self, destination: vc), sender: nil)
            case .vpnConfiguration:
                let vpnConfigurationView = VPNConfigurationView()
                let vc = UIHostingController(rootView: vpnConfigurationView)
                let appearance = UINavigationBarAppearance()
                appearance.configureWithDefaultBackground()
                vc.navigationItem.scrollEdgeAppearance = appearance
                vc.navigationItem.standardAppearance = appearance
                navigationController?.pushViewController(vc, animated: true)
            default: break
            }
        case .signing:
            switch SigningSettingsRow.allCases[realRow] {
            case .exportAccount: showExportAccount()
            case .importAccount:
                Task {
                    let confUrl = await withUnsafeContinuation { c in
                        let importVc = UIDocumentPickerViewController(forOpeningContentTypes: [UTType(filenameExtension: "sideconf")!], asCopy: false)
                        ImportExport.documentPickerHandler = DocumentPickerHandler { url in c.resume(returning: url) }
                        importVc.delegate = ImportExport.documentPickerHandler
                        self.present(importVc, animated: true)
                    }
                    if let confUrl = confUrl { importAccountAtFile(confUrl) }
                }
            case .importCert:
                Task {
                    let certUrl = await withUnsafeContinuation { c in
                        let importVc = UIDocumentPickerViewController(forOpeningContentTypes: [UTType(filenameExtension: "p12")!], asCopy: false)
                        ImportExport.documentPickerHandler = DocumentPickerHandler { url in
                            _ = url?.startAccessingSecurityScopedResource()
                            defer { url?.stopAccessingSecurityScopedResource() }
                            c.resume(returning: url)
                        }
                        importVc.delegate = ImportExport.documentPickerHandler
                        self.present(importVc, animated: true)
                    }
                    guard let certUrl = certUrl else { return }
                    let password = await withUnsafeContinuation { (c: UnsafeContinuation<String?,Never>) in
                        let alertController = UIAlertController(title: NSLocalizedString("Please enter the password for the certificate.", comment: ""), message: nil, preferredStyle: .alert)
                        alertController.addTextField { (textField) in textField.autocorrectionType = .no; textField.autocapitalizationType = .none }
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in c.resume(returning: alertController.textFields?.first?.text ?? "") })
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in c.resume(returning: nil) })
                        self.present(alertController, animated: true)
                    }
                    guard let pwd = password else { return }
                    _ = certUrl.startAccessingSecurityScopedResource()
                    defer { certUrl.stopAccessingSecurityScopedResource() }
                    let certData = try! Data(contentsOf: certUrl)
                    guard let altCert = ALTCertificate(p12Data: certData, password: pwd) else { return }
                    Keychain.shared.signingCertificate = altCert.encryptedP12Data(withPassword: "")!
                    ToastView(text: NSLocalizedString("Certificate imported successfully!", comment: ""), detailText: nil).show(in: self)
                }
            case .exportCert:
                Task {
                    guard let certData = Keychain.shared.signingCertificate else { return }
                    let password = await withUnsafeContinuation { (c: UnsafeContinuation<String?,Never>) in
                        let alertController = UIAlertController(title: NSLocalizedString("Please enter the password for the certificate.", comment: ""), message: nil, preferredStyle: .alert)
                        alertController.addTextField { (textField) in textField.autocorrectionType = .no; textField.autocapitalizationType = .none }
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in c.resume(returning: alertController.textFields?.first?.text ?? "") })
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in c.resume(returning: nil) })
                        self.present(alertController, animated: true)
                    }
                    guard let pwd = password, let altCert = ALTCertificate(p12Data: certData, password: nil), let newCertData = altCert.encryptedP12Data(withPassword: pwd) else { return }
                    let newCertTmpPath = FileManager.default.temporaryDirectory.appendingPathComponent("SideStoreSigningCertificate.p12")
                    try? newCertData.write(to: newCertTmpPath)
                    self.present(UIDocumentPickerViewController(forExporting: [newCertTmpPath], asCopy: false), animated: true)
                }
            }
        case .diagnostics:
            switch DiagnosticsRow.allCases[realRow] {
            case .deleteDatabase:
                if !Self.deleteDBInProgress {
                    Self.deleteDBInProgress = true
                    _ = DatabaseManager.deleteDatabase()
                    exit(0)
                }
            case .exportDatabase:
                if !Self.exportDBInProgress {
                    Self.exportDBInProgress = true
                    Task{
                        var toastView: ToastView?
                        do{
                            _ = try await CoreDataHelper.exportCoreDataStore()
                            toastView = ToastView(text: "Export Successful", detailText: nil)
                        }catch{
                            toastView = ToastView(error: error)
                        }
                        DispatchQueue.main.async { toastView?.show(in: self) }
                        Self.exportDBInProgress = false
                    }
                }
            case .operationsLoggingControl:
                let operationsLoggingController = UIHostingController(rootView: OperationsLoggingControlView())
                self.present(operationsLoggingController, animated: true, completion: nil)
            default: break
            }
        default: break
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension SettingsViewController: MFMailComposeViewControllerDelegate
{
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?)
    {
        controller.dismiss(animated: true, completion: nil)
    }
}

extension SettingsViewController: UIGestureRecognizerDelegate
{
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
    {
        return true
    }
}

extension SettingsViewController: INUIAddVoiceShortcutViewControllerDelegate
{
    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController, didFinishWith voiceShortcut: INVoiceShortcut?, error: Error?)
    {
        controller.dismiss(animated: true, completion: nil)
    }
    
    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController)
    {
        controller.dismiss(animated: true, completion: nil)
    }
}