//
//  SPWKWebViewController.swift
//  CieID SDK
//
//  Copyright © 2021 IPZS. All rights reserved.
//

import UIKit
import WebKit
import SafariServices


public enum FlowType {
    case Internal,Redirect
}
//Costanti di classe
let NOTIFICATION_NAME : String = "RETURN_FROM_CIEID"

public protocol CieIdDelegate : AnyObject {
    func CieIDAuthenticationClosedWithSuccess()
    func CieIDAuthenticationClosedWithError(errorMessage: String)
    func CieIDAuthenticationCanceled()
}
//

public class CieIDWKWebViewController: UIViewController, WKNavigationDelegate,UIWebViewDelegate {

    private var webView: WKWebView = WKWebView()
    private var cancelButton: UIButton!
    private var activityIndicator: UIActivityIndicatorView!
    private var internalFlow: Bool = false
    var delegate: CieIdDelegate?
    var webViewOBV : NSKeyValueObservation?
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.addCancelButton()
        self.addActivityIndicatory()

    }
    
    
    public func setupDelegate(delegate: CieIdDelegate, and flowType: FlowType) {
        self.delegate = delegate
        self.internalFlow = flowType == .Internal
    }
    public override func loadView() {

        super.loadView()

        if #available(iOS 13, *) {

            //Evita che l'utente possa annullare l'operazione con uno swipe
            self.isModalInPresentation = true

            //Setup webView properties
            let SP_URL_KEY : String = "SP_URL"
            let CUSTOM_USER_AGENT : String = "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1"
            let DEV_EXTRA_KEY : String = "developerExtrasEnabled"

            NotificationCenter.default.addObserver(self, selector: #selector(self.onDidReceivedResponse(_:)), name: Notification.Name(NOTIFICATION_NAME), object: nil)
            webView.configuration.preferences.setValue(true, forKey: DEV_EXTRA_KEY)
            webView.customUserAgent = CUSTOM_USER_AGENT
            webView.navigationDelegate = self
            webViewOBV = webView.observe(\.url, options: .new, changeHandler: { webView, urlOpt in
//                guard let url = urlOpt.newValue as? URL else { return }
//                let string = url.absoluteString
//
//                var editUrl = string.replacingOccurrences(of: "idp/login/livello1mobile", with: "return/login/livello1mobile")
//                editUrl = editUrl.replacingOccurrences(of: "idp/login/livello1e2postqrcode", with: "idp/login/livello1e2postqrcode")
//                print(editUrl)
//                if string.containsValidIdpUrl && (string.contains("nextUrl") || string.contains("login/livello1") || string.contains("login/livello2") ){
//                    if self.internalFlow {
//                        self.handleInternalFlow(with: editUrl)
//                    } else {
//                        self.redirectFlow(with: URL(string: editUrl)!)
//                    }
//                }
            })
            webView.configuration.preferences.javaScriptEnabled = true
            
            self.webView.frame = self.view.frame
            self.view.addSubview(webView)

            //Check if SP_URL key exists in info.plist
            if let spUrlString : String = Bundle.main.infoDictionary?[SP_URL_KEY] as? String{

                //Check if SP_URL_KEY contains a valid URL
                if (spUrlString.containsValidSPUrl){

                    let url = URL(string: spUrlString)!
                    webView.load(URLRequest(url: url))

                }else{

                    print("CieID SDK ERROR: Service provider URL non valido")

                }

            }else{

                print("CieID SDK ERROR: Service provider URL non presente in Info.plist")

            }

        }else{

            print("CieID SDK ERROR: Questa funzionalità richiede iOS 13 o superiore")
            self.gestisciErrore(errorMessage: "Questa funzionalità richiede iOS 13 o superiore")

        }

    }

    
    private func handleInternalFlow(with url: String) {
        CiedSDK.current.setURL(url: url)
        CiedSDKInsertPinVC.instanteAndPresent(on: self) {
            CiedSDK.current.authenticate(completion: { [weak self] success , string in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if success {
                        self.webView.load(URLRequest(url: URL(string: string!)!))
                        self.delegate?.CieIDAuthenticationClosedWithSuccess()
                    } else {
                        self.dismiss(animated: true, completion: nil)
                        self.delegate?.CieIDAuthenticationClosedWithError(errorMessage: string ?? "Errore")
                    }
                }
                
            })
        } cancellAction: {
            print("cancell")
            self.dismiss(animated: true, completion: nil)
        }
    }
    private func addCancelButton(){

        let CANCEL_BUTTON_HEIGHT : CGFloat = 70

        cancelButton = UIButton.init(type: .roundedRect)
        cancelButton.frame = CGRect.init(x: 0, y: self.view.frame.size.height - CANCEL_BUTTON_HEIGHT, width: self.view.frame.size.width, height: 70)
        cancelButton.setTitle("ANNULLA", for: .normal)
        cancelButton.titleLabel!.font = UIFont.systemFont(ofSize: 22)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.backgroundColor = UIColor.init(red: 16/255, green: 104/255, blue: 201/255, alpha: 1)
        cancelButton.addTarget(self, action: #selector(self.annullaButtonPressed), for: .touchUpInside)

        self.view.addSubview(self.cancelButton)
        self.webView.frame.size.height = self.view.frame.size.height - self.cancelButton.frame.size.height

    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {

        removeActivityIndicatoryIfPresent()

    }

    private func addActivityIndicatory() {

        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = UIColor.lightGray
        activityIndicator.center = self.view.center
        self.view.addSubview(activityIndicator)
        activityIndicator.startAnimating()

    }

    private func removeActivityIndicatoryIfPresent() {

        if (activityIndicator != nil){

            if (activityIndicator.isAnimating){

                activityIndicator.stopAnimating()

            }

        }

    }

    @objc private func annullaButtonPressed() {

        self.chiudiWebView()
        delegate?.CieIDAuthenticationCanceled()

    }


    @objc private func onDidReceivedResponse(_ notification: Notification) {

        if let dict = notification.userInfo as Dictionary? {

            if let urlString = dict["payload"] as? String{

                //Response contiene un errore
                if let errorMessage = urlString.responseError{

                    self.gestisciErrore(errorMessage: errorMessage.replacingOccurrences(of: "_", with: " "))

                }else{

                    //Response è valida
                    if urlString.containsValidIdpResponse{ //TODO: Splittare logica per L3 e L1L2
                        
                        let url = URL(string: urlString)!

                        self.webView.load(URLRequest(url: url))

                        /*
                            L'app Cie ID ha eseguito con successo l'autenticazione,
                            sposta la chiamata al delegato CieIDAuthenticationClosedWithSuccess()
                            dove le logiche dell'SP lo richiedono.
                        */
                        self.delegate?.CieIDAuthenticationClosedWithSuccess()



                    }else{

                        self.gestisciErrore(errorMessage: "URL non valido")

                    }

                }

            }else{

                self.gestisciErrore(errorMessage: "URL non valido")

            }

        }else{

            self.gestisciErrore(errorMessage: "URL non valido")

        }

    }

    private func gestisciErrore(errorMessage: String){

        self.chiudiWebView()
        delegate?.CieIDAuthenticationClosedWithError(errorMessage: errorMessage)

    }

    private func gestisciAppNonInstallata(){

        let alert = UIAlertController(title: "Installa Cie ID", message: "Per procedere con l'autenticazione mediante Carta di Identità Elettronica è necessario installare una versione aggiornata dell'app Cie ID e procedere con la registrazione della carta.", preferredStyle: .actionSheet)

        //Scarica Cie ID
        alert.addAction(UIAlertAction(title: "Scarica Cie ID", style: .default, handler: { (_) in

            if let url = URL(string: "https://apps.apple.com/it/app/cieid/id1504644677") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }

            self.chiudiWebView()

        }))

        //Chiudi Alert - Chiudi WebView
        alert.addAction(UIAlertAction(title: "ANNULLA", style: .destructive, handler: { (_) in

            self.chiudiWebView()

        }))

        //Mostra Alert
        DispatchQueue.main.async {

            self.present(alert, animated: true, completion: {

            })

        }

    }

    private func chiudiWebView(){

        DispatchQueue.main.async {

            self.dismiss(animated: true, completion: nil)

        }

    }
    
    
    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
//        print(webView.url)
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: ((WKNavigationActionPolicy) -> Void)) {
//        print(navigationAction.request.url?.absoluteString)
        
        guard let url = navigationAction.request.url else { return }
        let string = url.absoluteString
                
        let path = url.pathComponents
        if ((string.containsValidIdpUrl && string.contains("nextUrl")) || path.contains("livello1") || path.contains("livello2")) {
            if self.internalFlow {
                self.handleInternalFlow(with: string)
            } else {
                self.redirectFlow(with: url)//URL(string: editUrl)!)
            }
            decisionHandler(.cancel)
            return
        }
        
        
        
        if(navigationAction.request.url?.absoluteString.contains("OpenApp") ?? false) {
            print("Hellooo")
        }
        switch navigationAction.navigationType {
        case .linkActivated:
            if navigationAction.targetFrame == nil {

                self.webView.load(navigationAction.request)// It will load that link in same WKWebView

            }
            break
            default:
                break

        }

        if let urlCaught = navigationAction.request.url {

            //AUTHENTICATION REQUEST START
//            if (urlCaught.absoluteString.containsValidIdpUrl){
//                if self.internalFlow {
//                    decisionHandler(.cancel)
//                    print("Internal")
//                    CiedSDK.current.setURL(url: "")
//                    CiedSDKInsertPinVC.instanteAndPresent(on: self) {
//                        CiedSDK.current.authenticate(completion: { [weak self] value , string in
//                            guard let self = self else { return }
//                            if value {
//                                DispatchQueue.main.async {
//                                    self.webView.load(URLRequest(url: URL(string: string!)!))
//                                }
//                                self.delegate?.CieIDAuthenticationClosedWithSuccess()
//                            } else {
//                                self.delegate?.CieIDAuthenticationClosedWithError(errorMessage: string ?? "Errore")
//                            }
//                        })
//                    } cancellAction: {
//                        print("cancell")
//                        self.dismiss(animated: true, completion: nil)
//                    }
//
//                } else {
//                    decisionHandler(.cancel)
//                    redirectFlow(with: urlCaught)
//                }
//
//            }else{

                decisionHandler(.allow)

//            }

        }

    }
    
    
    private func redirectFlow(with urlCaught: URL) {
        //Blocco link all'iDP, evito che sia il browser ad avviare CieID
        
        //Aggiungo sourceApp url paramete
        let urlSchemeString : String = Bundle.main.infoDictionary?["SP_URL_SCHEME"] as! String
        let string = urlCaught.absoluteString + "&sourceApp=\(urlSchemeString)"
        let urlToCieID = URL(string: string)

        if (urlToCieID != nil){

            let finalURL = urlToCieID?.addAppDomainPrefix

            if (finalURL != nil){

                //Chiama Cie ID
                DispatchQueue.main.async(){
                    UIApplication.shared.open(finalURL!, options: [:], completionHandler: { [self] (success) in

                        if success {

                            print("CieID SDK INFO: The URL was delivered to CieID app successfully!")

                        }else{

                            //L'app Cie ID non è installata
                            self.gestisciAppNonInstallata()

                        }

                    })

                }

            }

        }else{

            print("CieID SDK ERROR: Service provider URL Scheme non presente in Info.plist")

        }

    }

    deinit {

        NotificationCenter.default.removeObserver(self, name: Notification.Name(NOTIFICATION_NAME), object: nil)

    }

}
