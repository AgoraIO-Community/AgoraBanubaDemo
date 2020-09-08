import UIKit
import AVKit
import VideoToolbox
import MobileCoreServices
import BanubaSdk
import BanubaEffectPlayer
import AgoraRtcKit
import FirebaseDatabase

class ViewController: UIViewController {
    struct Defaults {
        static let renderSize: CGSize = CGSize(width: 720, height: 1280)
        static let PhotoCameraModeAspectRatio: CGFloat = 3.0 / 4.0
        static let VideoCameraModeAspectRatio: CGFloat = 9.0 / 16.0
        static let previewInteractiveIdentifier = "toPreviewInteractive"
        static let previewIdentifier = "toPreview"
    }
    
    var effects: [String] = []
    var externalEffects: [String] = []
    var glView: EffectPlayerView!
    let playerController = AVPlayerViewController()
    let sdkManager = BanubaSdkManager()
    var previewImage: UIImage?
    var previewImageSrc: UIImage?
    var binState: Bool = false
    var isFrontCamera: Bool = true
    var renderMode: EffectPlayerRenderMode = .photo
    var frameDurationLogger: FrameDurationLogger! = nil
    var fakePhoto = false
    var cameraSessionType: CameraSessionType {
        if isFrontCamera {
            return renderMode == .photo ? .FrontCameraPhotoSession : .FrontCameraVideoSession
        } else {
            return renderMode == .photo ? .BackCameraPhotoSession : .BackCameraVideoSession
        }
    }
    
    var roomName: String?
    var agoraKit: AgoraRtcEngineKit?
    var videoSource = CustomVideoSource()
    
    @IBOutlet weak var chatTableView: UITableView!
    @IBOutlet weak var glViewContainer: UIView!
    @IBOutlet weak var photoButton: UIButton!
    @IBOutlet weak var videoButton: UIButton!
    @IBOutlet weak var effectsList: UICollectionView!
    @IBOutlet weak var sdkVersion: UILabel!
    @IBOutlet weak var renderLabel: UILabel!
    @IBOutlet weak var recognizerLabel: UILabel!
    @IBOutlet weak var cameraLabel: UILabel!
    @IBOutlet weak var switchCameraNote: UILabel!
    @IBOutlet weak var frameLoggerNote: UILabel!
    @IBOutlet weak var saveVideoMode: UISwitch!
    @IBOutlet weak var saveModeLabel: UILabel!
    
    //MARK: ViewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        sdkVersion.text = UIApplication.banubaVersion
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: UIApplication.didBecomeActiveNotification, object: nil)
        initializeAgoraEngine()
        configureCameraModeUI()
        setupPlayer()
        sdkManager.input.startCamera()
        effects = EffectsService.shared.loadEffects(path: EffectsService.shared.path)
        externalEffects = EffectsService.shared.loadEffects(path: EffectsService.shared.externalEffectsPath)
        effectsList.dataSource = self
        effectsList.delegate = self
        effectsList.reloadData()
        sdkManager.effectPlayer?.add(self as BNBFrameDurationListener)
        sdkManager.output?.startForwardingFrames(handler: { (buffer) in
            self.videoSource.sendBuffer(buffer, timestamp: Date().timeIntervalSinceReferenceDate)
        })
        
    }
    
    func initializeAgoraEngine() {
        agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: "YOUR_APP_ID_HERE", delegate: self)
        

        agoraKit?.enableVideo() // - enable video
        agoraKit?.setVideoSource(self.videoSource) // - set the video source to the custom source
 
        agoraKit?.enableWebSdkInteroperability(true)
        agoraKit?.setChannelProfile(.liveBroadcasting)
        if let channel = roomName {
            agoraKit?.joinChannel(byToken: nil, channelId: channel, info: nil, uid: 0, joinSuccess: { (channel, uid, elapsed) in
                print("Join channel success")
            })
        }
    }
    
    deinit
    {
        sdkManager.effectPlayer?.remove(self as BNBFrameDurationListener)
        NotificationCenter.default.removeObserver(self)
        if let userName = roomName {
            Database.database().reference(withPath: "live").child(userName).removeValue()
            agoraKit?.leaveChannel(nil)
        }
    }
    //MARK: ReloadData
    @objc func reloadData() {
        self.externalEffects = []
        externalEffects = EffectsService.shared.loadEffects(path: EffectsService.shared.externalEffectsPath)
        effectsList.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        sdkManager.startEffectPlayer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        sdkManager.stopEffectPlayer()
        
    }
    //MARK: TakeFakePhoto
    func takeFakePhoto() {
        DispatchQueue.main.async { [weak self] in
            self!.fakePhoto = true
            self!.makePhoto(0)
        }
    }
    //MARK: SetupPlayer
    func setupPlayer() {
        let configuration = EffectPlayerConfinguration(renderMode: renderMode)
        sdkManager.setup(configuration: configuration)
        self.prepareRenderTargetLayer(renderMode)
        guard let layer = glView.layer as? CAEAGLLayer else {return}
        sdkManager.setRenderTarget(layer: layer, playerConfiguration: nil)
        sdkManager.setMaxFaces(2)
        TestHandler.setupTesting(sdkManager: sdkManager, view: self)
        
        //MARK: Watermark
        //guard let watermark = UIImage(named: "watermark") else {return}
        //let offset = CGPoint(x: 20.0, y: 10.0)
        //let watermarkInfo = WatermarkInfo(image: watermark, corner: .bottomLeft, offset: offset, targetNormalizedWidth: 0.7)
        //sdkManager.configureWatermark(watermarkInfo)
    }
    //MARK: FileURL
    func fileURL() -> URL {
      let fileUrl = EffectsService.shared.fm.temporaryDirectory.appendingPathComponent("video.mp4")
        return fileUrl
    }
    //MARK: OnStartBinButton
    @IBAction func onStartBinButton(_ sender: Any) {
        let button = sender as! UIButton
        binState = !binState
        sdkManager.setFrameDataRecord(binState)
        let title = binState ? "[Stop]" : "[Record BIN]"
        button.setTitle(title, for: .normal)
    }
    //MARK: OnDurationButtonClicked
    @IBAction func onDurationButtonClicked(_ sender: UIButton) {
        if frameDurationLogger == nil {
            frameDurationLogger = FrameDurationLogger()
            sdkManager.effectPlayer?.add(frameDurationLogger as BNBFrameDurationListener)
            frameLoggerNote.text = "Disable frame logger"
        } else {
            sdkManager.effectPlayer?.remove(frameDurationLogger as BNBFrameDurationListener)
            frameDurationLogger.printResult()
            frameDurationLogger = nil
            frameLoggerNote.text = "Enable frame logger"
        }
    }
    //MARK: MakePhoto
    @IBAction func makePhoto(_ sender: Any) {
        let makeStart = Date()
        sdkManager.stopEffectPlayer()
        let useInteractivePreview = true
        //flashMode parametr allows you to turn on, off, auto flashlight of your device.
        //But if your device use Arkit like iPhone X and above, flash won't work
        let settings = CameraPhotoSettings(useStabilization: true, flashMode: .off)
        sdkManager.makeCameraPhoto(cameraSettings: settings, flipFrontCamera: true, srcImageHandler: {
            [weak self] (srcCVPixelBuffer) in
            var cgImage: CGImage?
            VTCreateCGImageFromCVPixelBuffer(srcCVPixelBuffer, options: nil, imageOut: &cgImage)
            var orient: UIImage.Orientation
            switch (self?.sdkManager.imageOrientationForCameraPhoto ?? .deg0) {
            case .deg0:
                orient = UIImage.Orientation.up
            case .deg90:
                orient = UIImage.Orientation.right
            case .deg180:
                orient = UIImage.Orientation.down
            case .deg270:
                orient = UIImage.Orientation.left
            default:
                orient = UIImage.Orientation.up
            }
            let image = UIImage.init(cgImage: cgImage!, scale:1, orientation: orient)
            self?.previewImageSrc = image
        }) { [weak self] (image) in
            DispatchQueue.main.async {
                if let image = image {
                    print("Process photo time \(-makeStart.timeIntervalSinceNow) s.")
                    self?.previewImage = image
                    if self?.fakePhoto ?? false {
                        self?.fakePhoto = false
                        self?.sdkManager.startEffectPlayer()
                        return
                    }
                    if useInteractivePreview {
                        self?.performSegue(withIdentifier: Defaults.previewInteractiveIdentifier, sender: self)
                    } else {
                        self?.performSegue(withIdentifier: Defaults.previewIdentifier, sender: self)
                    }
                }
            }
        }
    }
    //MARK: SwitchCamera
    @IBAction func switchCamera(_ sender: Any) {
        isFrontCamera = !isFrontCamera
        if isFrontCamera {
            switchCameraNote.text = "Front camera"
        } else {
            switchCameraNote.text = "Back camera"
        }
        sdkManager.input.switchCamera(to: cameraSessionType) {
            print("RotateCamera")
        }
    }
    //MARK: SwitchRecordMode
    @IBAction func switchRecordMode(_ sender: Any) {
        renderMode = renderMode == .photo ? .video : .photo
        sdkManager.input.setCameraSessionType(cameraSessionType)
        configureCameraModeUI()
        sdkManager.stopEffectPlayer()
        prepareRenderTargetLayer(renderMode)
        guard let layer = glView.layer as? CAEAGLLayer else {return}
        sdkManager.setRenderTarget(layer: layer, playerConfiguration: nil)
        sdkManager.startEffectPlayer()
    }
    //MARK: OpenGallery
    @IBAction func openGallery(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.allowsEditing = false
        picker.delegate = self
        picker.modalPresentationStyle = .fullScreen
        present(picker, animated: true, completion: nil)
    }
    //MARK: RestartPlayer
    @IBAction func restartPlayer(_ sender: Any?) {
        if frameDurationLogger != nil {
            sdkManager.effectPlayer?.remove(frameDurationLogger as BNBFrameDurationListener)
            frameDurationLogger.printResult()
            frameDurationLogger = nil
            frameLoggerNote.text = "Enable frame logger"
        }
        sdkManager.destroyEffectPlayer()
        setupPlayer()
        sdkManager.startEffectPlayer()
    }
    //MARK: ConfigureCameraModeUI
    private func configureCameraModeUI() {
        saveModeLabel.isHidden = renderMode == .photo
        saveVideoMode.isHidden = renderMode == .photo
        photoButton.isHidden = renderMode == .video
        videoButton.isHidden = renderMode == .photo
    }
    
    private func saveVideoToGallery(fileURL: String) {
        if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileURL) {
            UISaveVideoAtPathToSavedPhotosAlbum(fileURL, nil, nil, nil)
        }
    }
    //MARK: ToggleVideo
    @IBAction func toggleVideo(_ sender: Any) {
        let shouldRecord = !(sdkManager.output?.isRecording ?? false)
        let hasSpace =  sdkManager.output?.hasDiskCapacityForRecording() ?? true
        if shouldRecord && hasSpace {
            let fileURL = self.fileURL()
            sdkManager.input.startAudioCapturing()
            sdkManager.output?.startVideoCapturing(fileURL:fileURL) { (success, error) in
                print("Done Writing: \(success)")
                if let _error = error {
                    print(_error)
                }
                self.sdkManager.input.stopAudioCapturing()
                print("voiceChanger.isConfigured:\(self.sdkManager.voiceChanger?.isConfigured ?? false)")
                guard self.sdkManager.voiceChanger?.isConfigured ?? false else {
                    self.presentVideoController(fileURL: fileURL)
                    if self.saveVideoMode.isOn {
                        self.saveVideoToGallery(fileURL: fileURL.relativePath)
                    }
                    return
                }
                self.sdkManager.effectPlayer?.setEffectVolume(0.0)
                self.sdkManager.voiceChanger?.process(file: fileURL, completion: { (success, error) in
                    self.sdkManager.effectPlayer?.setEffectVolume(1.0)
                    print("--- Voice Changer:[Success:\(success)][Error:\(String(describing: error))]")
                    if success {
                        DispatchQueue.main.async {
                            self.presentVideoController(fileURL: fileURL)
                            if self.saveVideoMode.isOn {
                                self.saveVideoToGallery(fileURL: fileURL.relativePath)
                            }
                        }
                    }
                })
            }
            self.videoButton.setImage(UIImage(named: "stop_video"), for: .normal)
        } else {
            sdkManager.output?.stopVideoCapturing(cancel: false)
            self.videoButton.setImage(UIImage(named: "shutter_video"), for: .normal)
        }
    }
    //MARK: PrepareRenderTargetLayer
    func prepareRenderTargetLayer(_ renderMode: EffectPlayerRenderMode) {
        if glView != nil {
            glView.removeFromSuperview()
            glView = nil
        }
        let cameraSessionAspectRatio: CGFloat = (renderMode == .photo) ? Defaults.PhotoCameraModeAspectRatio : Defaults.VideoCameraModeAspectRatio
        let frame = calculateRenderLayerFrame(layerAspectRatio: cameraSessionAspectRatio)
        guard let effectPlayer = sdkManager.effectPlayer else { return }
        glView = EffectPlayerView(frame: frame)
        glView.effectPlayer = effectPlayer
        glView.isMultipleTouchEnabled = true
        glView.layer.contentsScale = UIScreen.main.scale
        glViewContainer.addSubview(glView)
    }
    //MARK: CalculateRenderLayerFrame
    private func calculateRenderLayerFrame(layerAspectRatio: CGFloat) -> CGRect {
        let screenSize = UIScreen.main.bounds.size
        let screenAspectRatio = screenSize.width / screenSize.height
        let width = (layerAspectRatio < screenAspectRatio) ? screenSize.height * layerAspectRatio : screenSize.width
        let height = (layerAspectRatio < screenAspectRatio) ? screenSize.height : screenSize.width / layerAspectRatio
        let size = CGSize(width: width, height: height)
        let x: CGFloat = (screenSize.width - width) / 2.0
        let y: CGFloat = (screenSize.height - height) / 2.0
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
    //MARK:  Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Defaults.previewIdentifier {
            guard let previewController = segue.destination as? PreviewController else {return}
            previewController.image = self.previewImage
            self.previewImage = nil
            self.previewImageSrc = nil
        }
        if segue.identifier == Defaults.previewInteractiveIdentifier {
            guard let previewController = segue.destination as? InteractivePreviewController else {return}
            previewController.image = self.previewImage
            previewController.srcImage = self.previewImageSrc
            previewController.sdkManager = sdkManager
            self.previewImage = nil
            self.previewImageSrc = nil
        }
    }
    
    func presentVideoController(fileURL:URL) {
        let player = AVPlayer(url: fileURL)
        self.playerController.player = player
        self.present(self.playerController, animated: true, completion: nil)
    }
}
//MARK: EffectCell Custom Class
class EffectCell: UICollectionViewCell {
    
    @IBOutlet weak var image: UIImageView!
    
    func loadImageFromPath(imgPath: String) {
        var imageTemplate = UIImage(contentsOfFile: imgPath)
        if imageTemplate == nil {
            imageTemplate = UIImage(named: "eyes_prod")
        }
        image.image = imageTemplate
    }
}

//MARK: addNewEffectCell Custom Class
class addNewEffectCell: UICollectionViewCell {
    
    @IBOutlet weak var addView: UIView!
    
    override func layoutSubviews() {
        super.layoutSubviews()
        addView.layer.cornerRadius = addView.frame.width / 2
    }
}

// MARK: Collection  View Extension
extension ViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 3
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        else if section == 1 {
            return externalEffects.count
        }
        else {
            return effects.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "addCell", for: indexPath)
            return cell
        } else if indexPath.section == 1 {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "newEffectCell", for: indexPath)
                as? EffectCell else {return EffectCell()}
            let imgPath = AppDelegate.documentsPath + "/effects/" +  (externalEffects[indexPath.row])  + "/preview.png"
            cell.loadImageFromPath(imgPath: imgPath)
            return cell
        } else {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "effectCell", for: indexPath)
                as? EffectCell else {return EffectCell()}
            let imgPath = Bundle.main.bundlePath + "/effects/" +  (effects[indexPath.row])  + "/preview.png"
            cell.loadImageFromPath(imgPath: imgPath)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let documentPicker = UIDocumentPickerViewController(documentTypes: [kUTTypeArchive as String], in: .import)
            documentPicker.delegate = self
            if #available(iOS 11.0, *) {
                documentPicker.allowsMultipleSelection = false
            }
            present(documentPicker, animated: true, completion: nil)
        } else if indexPath.section == 1 {
            sdkManager.loadEffect((externalEffects[indexPath.row]))
        } else {
            sdkManager.loadEffect((effects[indexPath.row]))
        }
    }
}
// MARK: Image Picker Extension
extension ViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: false) {
            guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else {return}
            let useInteractivePreview = true
            self.previewImageSrc = image
            self.sdkManager.processImageData(image) { procImage in
                DispatchQueue.main.async {
                    self.previewImage = procImage
                    if useInteractivePreview {
                        self.performSegue(withIdentifier: Defaults.previewInteractiveIdentifier, sender: self)
                    } else {
                        self.performSegue(withIdentifier: Defaults.previewIdentifier, sender: self)
                    }
                }
            }
        }
    }
}
//MARK: Document Picker Extenstion
extension ViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedFileURL = urls.first else {return}
        guard let dir = EffectsService.shared.fm.urls(for: .documentDirectory, in: .userDomainMask).first else {return}
        let sandboxFileURL = dir.appendingPathComponent(selectedFileURL.lastPathComponent)
        if EffectsService.shared.fm.fileExists(atPath: sandboxFileURL.path) {
            let alertController = UIAlertController(title: "Already exists", message: "File not copied", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            present(alertController, animated: true, completion: nil)
        }
        else {
            do {
                try EffectsService.shared.fm.copyItem(at: selectedFileURL, to: sandboxFileURL)
                let alertController = UIAlertController(title: "Archive is imported!", message: "", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                present(alertController, animated: true, completion: nil)
            }
            catch {
                print("Error: \(error)")
            }
        }
    }
}
//MARK: BNBFrameDurationListener Extenstion
extension ViewController: BNBFrameDurationListener {
    
    func onRecognizerFrameDurationChanged(_ instant: Float, averaged: Float) {
        DispatchQueue.main.async {
            self.recognizerLabel.text = (NSString(format:"%.2f", 1/averaged)) as String
        }
    }
    
    func onCameraFrameDurationChanged(_ instant: Float, averaged: Float) {
        DispatchQueue.main.async {
            self.cameraLabel.text = (NSString(format:"%.2f", 1/averaged)) as String
        }
    }
    
    func onRenderFrameDurationChanged(_ instant: Float, averaged: Float) {
        DispatchQueue.main.async {
            self.renderLabel.text = (NSString(format:"%.2f", 1/averaged)) as String
        }
    }
}
//MARK: UIApplication Extenstion
extension UIApplication {
    static var banubaVersion: String? {
        let frameworkBundle = Bundle(identifier: "banuba.sdk.effect-player")
        return frameworkBundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
}

//MARK: AgoraRtcEngineDelegate Extension
extension ViewController: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, remoteVideoStateChangedOfUid uid: UInt, state: AgoraVideoRemoteState, reason: AgoraVideoRemoteStateReason, elapsed: Int) {
        print("Got remote video state for uid \(uid)")
    }
}
