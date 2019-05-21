//
//  ViewController.swift
//  Gesture-Recognition
//


import UIKit
import SceneKit
import ARKit
import Vision
import Speech

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var debugTextView: UITextView!
    @IBOutlet weak var textOverlay: UITextField!
    
    let dispatchQueueML = DispatchQueue(label: "com.hw.dispatchqueueml") // A Serial Queue
    var visionRequests = [VNRequest]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // --- ARKIT ---
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene() // SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // --- ML & VISION ---
        //Patterns
        //signSymbolGuestures4 : 4
        //signSymbolGuesture3 : 4
        //SignSymbol : 4
        // Setup Vision Model
        guard let selectedModel = try? VNCoreMLModel(for: example_5s0_hand_model().model) else {
            fatalError("Could not load model. Ensure model has been drag and dropped (copied) to XCode Project. Also ensure the model is part of a target")
        }
        
        // Set up Vision-CoreML Request
        let classificationRequest = VNCoreMLRequest(model: selectedModel, completionHandler: classificationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop // Crop from centre of images and scale to appropriate size.
        visionRequests = [classificationRequest]
        
        // Begin Loop to Update CoreML
        loopCoreMLUpdate()
    }
    
    func speakMyText(text: String) {
        var mySpeech = "Hello"
//        if (text == "Hate You") { mySpeech = "I hate you" }
//        if (text == "Hello") { mySpeech = "Hello. How are you?"  }
//        if (text == "Love You") { mySpeech = "I love you"  }
//        if (text == "OK") { mySpeech = "I am Ok"  }
//        if (text == "Thank You") { mySpeech = "Thank you so much"  }
//        if (text == "Not OK") { mySpeech = "I am not ok"  }
//        if (text == "Okay") { mySpeech = "I am absolutely fine"  }
//        if (text == "Not Okay") { mySpeech = "I am not fine"  }
        
        if (text == "fist-UB-RHand") {
            mySpeech = "Fist Hand"
        }
        else if (text == "FIVE-UB-RHand") {
            mySpeech = "Hello everyone"
        } else {
            mySpeech = "No Hand"
        }
        // Line 1. Create an instance of AVSpeechSynthesizer.
        let speechSynthesizer = AVSpeechSynthesizer()
        // Line 2. Create an instance of AVSpeechUtterance and pass in a String to be spoken.
//        var speechUtterance: AVSpeechUtterance = AVSpeechUtterance(string: "This is a test. This is only a test. If this was an actual emergency, then this wouldn’t have been a test.")
        let speechUtterance: AVSpeechUtterance = AVSpeechUtterance(string: mySpeech)
        //Line 3. Specify the speech utterance rate. 1 = speaking extremely the higher the values the slower speech patterns. The default rate, AVSpeechUtteranceDefaultSpeechRate is 0.5
        speechUtterance.rate = AVSpeechUtteranceMaximumSpeechRate / 4.0
        // Line 4. Specify the voice. It is explicitly set to English here, but it will use the device default if not specified.
        speechUtterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        // Line 5. Pass in the urrerance to the synthesizer to actually speak.
        speechSynthesizer.speak(speechUtterance)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            // Do any desired updates to SceneKit here.
        }
    }
    
    // MARK: - MACHINE LEARNING
    
    func loopCoreMLUpdate() {
        // Continuously run CoreML whenever it's ready. (Preventing 'hiccups' in Frame Rate)
        dispatchQueueML.async {
            // 1. Run Update.
                self.updateCoreML()
            // 2. Loop this function.
                self.loopCoreMLUpdate()
        }
    }
    
    func updateCoreML() {
        // Get Camera Image as RGB
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        
        // Prepare CoreML/Vision Request
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        // Run Vision Image Request
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
    }
    
    func classificationCompleteHandler(request: VNRequest, error: Error?) {
        // Catch Errors
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        guard let observations = request.results else {
            print("No results")
            return
        }
        
        // Get Classifications
        let classifications = observations[0...2] // top 3 results // Change it according to the labels added in the training model
            .compactMap({ $0 as? VNClassificationObservation })
            .map({ "\($0.identifier) \(String(format:" : %.2f", $0.confidence))" })
            .joined(separator: "\n")
        
        // Render Classifications
        DispatchQueue.main.async {
            // Print Classifications
                // print(classifications)
                // print("-------------")
            
            // Display Debug Text on screen
            self.debugTextView.text = "TOP 3 PROBABILITIES: \n" + classifications //Change the number of probabilities according to the label
            
            // Display Top Symbol
            var symbol = "❎"
            let topPrediction = classifications.components(separatedBy: "\n")[0]
            let topPredictionName = topPrediction.components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
            // Only display a prediction if confidence is above 1%
            let topPredictionScore:Float? = Float(topPrediction.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces))
            if (topPredictionScore != nil && topPredictionScore! > 0.01) {
                if (topPredictionName == "fist-UB-RHand") { symbol = "👊" }
                if (topPredictionName == "FIVE-UB-RHand") { symbol = "🖐" }
//                if (topPredictionName == "Hate You") { symbol = "😡" }
//                if (topPredictionName == "Hello") { symbol = "🤝" }
//                if (topPredictionName == "Love You") { symbol = "🤟" }
//                if (topPredictionName == "OK") { symbol = "👍" }
//                if (topPredictionName == "Thank You") { symbol = "🙏" }
//                if (topPredictionName == "Not OK") { symbol = "👎" }
//                if (topPredictionName == "Okay") { symbol = "👌" }
//                if (topPredictionName == "Not Okay") { symbol = "😿" }
                self.speakMyText(text: topPredictionName)
            }
            
            self.textOverlay.text = symbol
            
        }
    }
    
    // MARK: - HIDE STATUS BAR
    override var prefersStatusBarHidden : Bool { return true }
}
