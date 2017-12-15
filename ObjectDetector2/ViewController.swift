
import UIKit
import AVFoundation
import CoreML

class ViewController: UIViewController {

    @IBOutlet weak var predictLabel: UILabel!
    @IBOutlet weak var previewView: PreviewView!
    
    private let session = AVCaptureSession()
    private var isSessionRunning = false
    private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil)
    private var permissionGranted = false
    
    let model = Inceptionv3()
    let modelInputSize = CGSize(width: 299, height: 299)
    override func viewDidLoad() {
        super.viewDidLoad()
        previewView.videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewView.session = session
        checkPermission()
        sessionQueue.async {[unowned self] in
            self.configureSession()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async {
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async { [unowned self] in
            if self.permissionGranted {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
        super.viewWillDisappear(animated)
    }
    
    private func configureSession() {
        guard permissionGranted else {return}
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.hd1280x720
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back) else {return}
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        guard session.canAddInput(captureDeviceInput) else {return}
        session.addInput(captureDeviceInput)
        
        let videoOutput = AVCaptureVideoDataOutput()
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer"))
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(videoOutput) else {return}
        session.addOutput(videoOutput)
        
        session.commitConfiguration()
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
    }
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
        }
    }
    
    private func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: {[unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        })
    }
   
   


}
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection!) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        guard let uiImage = UIImage(ciImage: ciImage).resize(modelInputSize),
            let cgImage = uiImage.cgImage,
            let pixelBuffer = ImageConverter.pixelBuffer(from: cgImage)?.takeRetainedValue(),
            let output = try? model.prediction(image:pixelBuffer) else {
                return
        }
        
        DispatchQueue.main.async {
            self.predictLabel.text = output.classLabel
        }
        
    }
}
extension UIImage {
    func resize(_ size:CGSize) -> UIImage? {
        UIGraphicsBeginImageContext(size)
        draw(in: CGRect(x:0, y: 0, width: size.width, height: size.height))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
