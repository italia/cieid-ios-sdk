//
//  CiedSDKInsertPinVC.swift
//  CiedSDKTest
//
//  Copyright © 2021 IPZS. All rights reserved.
//

import UIKit

public class CiedSDKInsertPinVC: UIViewController {
    @IBOutlet weak var pinTextField: UITextField!
    var cancelAction: () -> () = { }
    var successAction: () -> () = { }
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyBoad(_:))))
        pinTextField.resignFirstResponder()
    }
    
    @objc func dismissKeyBoad(_ sender: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }
    
    
    @IBAction func cancelAction(_ sender: UIButton) {
        self.dismiss(animated: true) {
            self.cancelAction()
        }
    }
    
    @IBAction func successAction(_ sender: UIButton) {
        guard let text = pinTextField.text else { return }
        CiedSDK.current.setPin(pin: text) { value in
            if value {
                self.dismiss(animated: true) {
                    self.successAction()
                }
            } else {
                let alert = UIAlertController(title: "Alert", message: "Formato Pin Errrato", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Chiudi", style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
        
    }
    
    
    static func instanteAndPresent(on parent: UIViewController, successAction: @escaping (() -> Void), cancellAction: @escaping(() -> Void)) {
        if let vc = UIStoryboard(name: "CiedSDK", bundle: Bundle(identifier: "com.indra.CiedSDKTest")).instantiateViewController(withIdentifier: "CiedSDKInsertPinVC") as? CiedSDKInsertPinVC {
            vc.modalPresentationStyle = .fullScreen
            vc.successAction = successAction
            vc.cancelAction = cancellAction
            parent.present(vc, animated: true, completion: nil)
        }
    }
}

