//
//  ActingViewController.swift
//  CoreMLDemo
//
//  Created by Wesley St. John on 12/1/17.
//  Copyright © 2017 mobileforming. All rights reserved.
//

import UIKit

let resultsSegueId = "ResultsSegue"

enum Emotion {
    case happiness
    case anger
    case sadness
    
    var image: UIImage? {
        switch self {
        case .happiness:
            return UIImage(named: "happiness")
        case .anger:
            return UIImage(named: "anger")
        case .sadness:
            return UIImage(named: "sadness")
        }
    }
    
    var directions: String {
        switch self {
        case .happiness:
            return "Show me your happy face!"
        case .anger:
            return "Now show me... Anger!"
        case .sadness:
            return "OK, how about Sadness?"
        }
    }
    
}

class ActingViewController: UIViewController {
    
    @IBOutlet weak var directionLabel: UILabel!
    @IBOutlet weak var feedbackLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    var frameExtractor = FrameExtractor(position: .front, quality: .medium)
    let emotionModel = CNNEmotions()
    let skipFrames = 60
    var frameIndex = 60
    let classificationThreshold = 0.8
    var shouldClassifyImage = true
    var numFails = 0
    let maxFails = 10
    
    var currentEmotion: Emotion {
        didSet {
            updateUI(withEmotion: currentEmotion)
        }
    }
    var currentImage: UIImage?
    var savedImages: [UIImage] = []
    
    required init?(coder aDecoder: NSCoder) {
        currentEmotion = .happiness
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        frameExtractor.delegate = self
        updateUI(withEmotion: currentEmotion)
    }
    
    func updateUI(withEmotion emotion: Emotion) {
        directionLabel.text = emotion.directions
        imageView.image = emotion.image
        feedbackLabel.text = "Give it a shot"
    }

    func updateUI(withModelOutput output: CNNEmotionsOutput) {
        
        imageView.image = currentImage
        
        var emotionKey = ""
        switch currentEmotion {
        case .happiness:
            emotionKey = "Happy"
        case .anger:
            emotionKey = "Angry"
        case .sadness:
            emotionKey = "Sad"
        }
        guard let percent = output.prob[emotionKey] else { return }
        
        numFails += 1
        if percent >= classificationThreshold {
            numFails = 0
            feedbackLabel.text = "Yes, that's perfect!"
            advanceToNextStep()
        } else if percent >= 0.5 {
            feedbackLabel.text = "You're almost there!"
        } else if percent >= 0.3 {
            feedbackLabel.text = "Keep trying..."
        } else {
            feedbackLabel.text = "Give it a shot"
        }
        
        if numFails == maxFails {
            feedbackLabel.text = "OK, cut! Let's just move on..."
            advanceToNextStep()
        }
    }
    
    func advanceToNextStep() {
        
        shouldClassifyImage = false
        
        if let image = currentImage {
            savedImages.append(image)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.shouldClassifyImage = true
            switch self.currentEmotion {
            case .happiness:
                self.currentEmotion = .anger
            case .anger:
                self.currentEmotion = .sadness
            case .sadness:
                // done
                self.shouldClassifyImage = false
                self.performSegue(withIdentifier: resultsSegueId, sender: nil)
            }
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == resultsSegueId {
            guard let resultsVC = segue.destination as? ResultsViewController else { return }
            resultsVC.images = savedImages
        }
    }

}

extension ActingViewController: FrameExtractorDelegate {
    func captured(image: UIImage) {
        
        guard shouldClassifyImage else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            let squareImage = image.centerCropToBounds(width: Double(image.size.width), height: Double(image.size.width))
            self.currentImage = squareImage
            
            guard self.frameIndex == self.skipFrames else {
                self.frameIndex += 1
                DispatchQueue.main.async {
                    self.imageView.image = self.currentImage
                }
                return
            }
            self.frameIndex = 0

            guard let pixelBuffer = squareImage.resized(to: CGSize(width: 224, height: 224)).pixelBuffer() else {
                return
            }
            let input = CNNEmotionsInput(data: pixelBuffer)

            guard let output = try? self.emotionModel.prediction(input: input) else {
                return
            }
            print(output.classLabel)
            print(output.prob)
            
            DispatchQueue.main.async {
                self.updateUI(withModelOutput: output)
            }
        }
        
        
    }
}



