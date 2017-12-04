//
//  ResultsViewController.swift
//  CoreMLDemo
//
//  Created by Wesley St. John on 12/3/17.
//  Copyright © 2017 mobileforming. All rights reserved.
//

import UIKit

class ResultsViewController: UIViewController {

    var images: [UIImage] = []
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet var imageViews: [UIImageView]!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        for i in 0..<imageViews.count {
            guard i < images.count - 1 else { return }
            let imageView = imageViews[i]
            let image = images[i]
            
            imageView.image = image            
        }
        
        stackView.transform = CGAffineTransform(translationX: 0, y: -1000)
        UIView.animate(withDuration: 1.0, animations: {
            // drop it
            self.stackView.transform = CGAffineTransform.identity
        }, completion: nil)
        
    }

 

}
