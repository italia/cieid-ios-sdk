//
//  CieIDButton.swift
//  CieID SDK
//
//  Copyright © 2021 IPZS. All rights reserved.
//

import Foundation
import UIKit

@IBDesignable public class CieIDButton: UIButton{
        
      override init(frame: CGRect) {
        
       super.init(frame: frame)
        
      }
      
      required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
            setupButton()

      }
      
        // UI Setup
        // This method is called at design time
    public override func prepareForInterfaceBuilder() {
            
            setupButton()

        }
        
        func setupButton() {
            
            if #available(iOS 13, *) {
                
                //Colors
                let color: UIColor = UIColor.init(red: 16/255, green: 104/255, blue: 201/255, alpha: 1)
                self.backgroundColor = color
                self.tintColor = .white
                let textColor: UIColor = .white
                
                //Corners
                self.layer.cornerRadius = cornerRadius
                
                //Image
                let leftSideImage = UIImage(named: "CieLogo",
                                    in: Bundle(for: type(of:self)),
                                    compatibleWith: nil)
                self.setImage(leftSideImage, for: .normal)
                self.imageView?.contentMode = .scaleAspectFit
                let imageSpaceFromLeftEdge : CGFloat = 32
                let imageTitleSpacer = ((self.frame.size.width - (self.imageView?.frame.size.width)!) / 2 ) - imageSpaceFromLeftEdge
                self.imageEdgeInsets = UIEdgeInsets(top: 0, left: -imageTitleSpacer, bottom: 0, right: 0)
                
                //Title
                let titleString: String = "Entra con CIE"
                self.setTitle(titleString, for: .normal)
                self.titleLabel?.tintColor = textColor
                self.titleLabel?.font = UIFont.systemFont(ofSize: textSize)
                self.titleLabel?.textAlignment = .center
                self.titleLabel?.adjustsFontSizeToFitWidth = true
                self.titleLabel?.minimumScaleFactor = 0.5
                self.titleEdgeInsets = UIEdgeInsets(top: 0, left: -((self.imageView!
                                                                        .frame.size.width)), bottom: 0, right: 0)
                
            } else {
                
                self.isHidden = true
                print("CieID SDK ERROR: CieIDButton requires iOS 13 or later to be shown")
                
            }

        }
    
        //Properties
        @IBInspectable
        var cornerRadius: CGFloat = 10{
            didSet {
                self.layer.cornerRadius = cornerRadius
            }
        }
    
        @IBInspectable
        var textSize: CGFloat = 22 {
            didSet {
                self.titleLabel!.font = UIFont.systemFont(ofSize: textSize)
            }
        }

    }
