/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 The app's main view controller object.
 */

import UIKit
import AVFoundation
import Vision
import WebKit

@available(iOS 14.0, *)
//[app,mode,scroll,corsur]
public var slideFlag:Bool = true
public var configList:[Int] = [1, 1, 0]

class CameraViewController: UIViewController {
    
    @IBOutlet weak var web: WKWebView!
    
    @IBOutlet weak var back: UIButton!
    
    private var testView:UIView!
    
    private var topView:UIView!
    
    private var cameraView: CameraView { view as! CameraView }
    //文字列のURLをURL型にキャスト
    
    //    private var cameraView: CameraView
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInteractive)
    private var cameraFeedSession: AVCaptureSession?// デバイスからの入力と出力を管理するオブジェクトの作成(カメラ)
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    
    private let drawOverlay = CAShapeLayer()//レイヤーの指定
    private let drawPath = UIBezierPath()
    private var evidenceBuffer = [HandGestureProcessor.PointsPair]()
    private var lastDrawPoint: CGPoint?
    private var isFirstSegment = true
    private var lastObservationTimestamp = Date()
    
    private var gestureProcessor = HandGestureProcessor()
    
    //自作
    private var middleTips:CGPoint?
    private var middleTipsConverted:CGPoint?
    
    private var indexPips:CGPoint?
    private var indexPipsConverted:CGPoint?
    
    private var middlePips:CGPoint?
    private var middlePipsConverted:CGPoint?
    
    private var fingersConfidence:Bool?
    
    var viewX:CGFloat!
    var viewY:CGFloat!
    
    private var countPinchFrames:[Int] = [Int]()
    private var countTime:Int = 0
    private let pinchedThreshold:Int = 40
    private var topCloseFlag:Bool = false
    
    private var topColseThreshold:Int = 50
    
    private let colorList:[[UIColor]] = [[.green, .red, .blue], [.yellow, .magenta, .cyan], [.black, .orange, .purple]]
    
    private var pointsCanvas = UIBezierPath()
    //インジゲーターを宣言
    var indicator = UIActivityIndicatorView()
    
    func openConfig(){
        let configViewController = self.storyboard?.instantiateViewController(withIdentifier: "ConfigViewController") as! Config
        
        self.present(configViewController, animated: true, completion: nil)
        
    }
    
    func setIndicator(referenceView: UIView) {
        //インジケーターを初期化
        indicator = UIActivityIndicatorView()
        //インジケーターの座標とサイズ
        indicator.frame = CGRect(x: 0, y: 0, width: referenceView.bounds.size.width, height: 100)
        //インジケーターが止まった時に非表示にするか？
        indicator.hidesWhenStopped = true
        //インジケーターの色
        indicator.style = .gray
        //webViewに追加
        web.addSubview(indicator)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /*--web各種設定--*/
        let url = URL(string: "https://www.google.com/?hl=ja")
        let request = URLRequest(url: url!)
        
        web.load(request)
        /*--------------*/
        
        countTime = 0
        /*--countPinchedFrameの初期化--*/
        for _ in (0 ..< pinchedThreshold + 10) {
            countPinchFrames.append(0)// 0 -> unpinchedを追加
        }
        /*----*/
        
        drawOverlay.frame = view.layer.bounds
        drawOverlay.lineWidth = 5
        drawOverlay.backgroundColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0.5).cgColor//背景色
        drawOverlay.strokeColor = #colorLiteral(red: 0.5725490451, green: 0, blue: 0.2313725501, alpha: 1).cgColor
        drawOverlay.fillColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0).cgColor
        drawOverlay.lineCap = .round
        
        topView = UIView(frame:CGRect(x: 0, y: 0, width: view.bounds.size.width, height:  view.bounds.size.height))
        topView.backgroundColor = .white
        let topViewRect = CGRect(x: 0, y: 0, width: view.bounds.size.width/2, height:  view.bounds.size.height/2)
        let topImageView = UIImageView(frame: topViewRect)
        
        topImageView.contentMode = .scaleAspectFit
        topImageView.image = UIImage(named: "けいすけ")
        topImageView.center = topView.center
        topView.addSubview(topImageView)
        
        view.layer.addSublayer(overlayLayer)//指のマーカー表示
        view.layer.addSublayer(web.layer)//レイヤーとして追加
        //view.layer.addSublayer(cameraView.overlayLayer)//指のマーカー表示
        //        view.layer.addSublayer(drawOverlay)// ここを書き換えればいけるか
        
        testView = UIView(frame:CGRect(x: 0, y: 0, width: view.bounds.size.width/8, height: view.bounds.size.height/12))
        testView.backgroundColor = .white
        
        // This sample app detects one hand only.
        // このサンプルアプリでは、片手のみを検出します。
        handPoseRequest.maximumHandCount = 1
        
        // Add state change handler to hand gesture processor.
        //ハンドジェスチャープロセッサに状態変化ハンドラを追加。
        gestureProcessor.didChangeStateClosure = { [weak self] state in
            
            self?.countTiming()
            self?.closeTopLayer()
            let flag:Bool = self!.topCloseFlag
            //ここは毎フレーム呼ばれている
            if(flag){
                self?.handleGestureStateChange(state: state)//描画
            }
        }
        
        // Add double tap gesture recognizer for clearing the draw path.
        // 描画パスをクリアするためのダブルタップジェスチャー認識機能を追加しました。
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        recognizer.numberOfTouchesRequired = 1
        recognizer.numberOfTapsRequired = 2
        view.addGestureRecognizer(recognizer)
        
        //        let layer = view.layer.sublayers![0]
        //        view.layer.sublayers![0] = view.layer.sublayers![0]
        //        view.layer.sublayers![0] = layer
        
        view.layer.addSublayer(topView.layer)
        //view.layer.addSublayer(topView.layer)
        let layers = view.layer.sublayers!
        
        print(layers.count)
    }
    
    //最初に読み込まれる
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            if cameraFeedSession == nil {
                cameraView.previewLayer.videoGravity = .resizeAspectFill//サイズを合わせる
                try setupAVSession()//設定を開始
                cameraView.previewLayer.session = cameraFeedSession
            }
            cameraFeedSession?.startRunning()//カメラの動き出しの開始
        } catch {
            //エラー処理
            AppError.display(error, inViewController: self)
        }
    }
    
    //Viewを消した時
    override func viewWillDisappear(_ animated: Bool) {
        cameraFeedSession?.stopRunning()
        super.viewWillDisappear(animated)
    }
    
    //カメラの設定
    func setupAVSession() throws {
        // Select a front facing camera, make an input.
        // 前面カメラを選択し、入力を行う。
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw AppError.captureSessionSetup(reason: "Could not find a front facing camera.")
        }
        // プロパティの条件を満たしたカメラデバイスの取得
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            throw AppError.captureSessionSetup(reason: "Could not create video device input.")
        }
        
        // デバイスからの入力と出力を管理するオブジェクトの作成
        let session = AVCaptureSession()
        session.beginConfiguration()//構成変更の開始
        session.sessionPreset = AVCaptureSession.Preset.high
        
        // Add a video input.
        guard session.canAddInput(deviceInput) else {
            throw AppError.captureSessionSetup(reason: "Could not add video device input to the session")
        }
        session.addInput(deviceInput)//指定された入力をセッションに追加
        
        let dataOutput = AVCaptureVideoDataOutput()// 出力設定
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
            // Add a video data output.
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            throw AppError.captureSessionSetup(reason: "Could not add video data output to the session")
        }
        session.commitConfiguration()
        cameraFeedSession = session
    }
    //ブラウザ操作の管理
    func operatedWebView(idx: Int){
        
        if(idx == 0){
            web.goBack()
            
        }else if(idx == 1){
            web.goForward()
            
        }else if(idx == 2){
            web.reload()
            
        }
        
        webFlag = -1//リセット
    }
    
    func processPoints(thumbTip: CGPoint?, indexTip: CGPoint?, middleTip:CGPoint?, indexPip:CGPoint?, middlePip:CGPoint?) {
        // Check that we have both points.
        guard let thumbPoint = thumbTip, let indexPoint = indexTip, let middlePoint = middleTip,
              let indexPPoint = indexPip, let middlePPoint = middlePip else {
            // If there were no observations for more than 2 seconds reset gesture processor.
            // 2秒以上観測されなかった場合は、ジェスチャープロセッサーをリセットします。
            if Date().timeIntervalSince(lastObservationTimestamp) > 1 {
                gestureProcessor.reset()
            }
            cameraView.showPoints([], color: .blue)// 線の描画
            return
        }
        
        // Convert points from AVFoundation coordinates to UIKit coordinates.
        let previewLayer = cameraView.previewLayer
        let thumbPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: thumbPoint)
        let indexPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: indexPoint)
        //中指の取得
        let middlePointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: middlePoint)
        middleTipsConverted = middlePointConverted
        //人差し指(第二関節)
        let indexPointPConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: indexPPoint)
        indexPipsConverted = indexPointPConverted
        
        //中指(第二関節)
        let middlePointPConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: middlePPoint)
        middlePipsConverted = middlePointPConverted
        
        // Process new points
        gestureProcessor.processPointsPair((thumbPointConverted, indexPointConverted))
    }
    //    //左のクリックダウン
    //    private func mouseDown(){
    //        guard let mouseDown = CGEvent(mouseEventSource: nil,
    //                                mouseType: .leftMouseDown,
    //                                mouseCursorPosition: CGPoint(x: 200, y: 300),
    //                                mouseButton: .left
    //                                ) else {return}
    //        mouseDown?.post(tap: .cghidEventTap)
    //    }
    
    //指の形を判定
    private func judgeFingerPose(pointColor: inout UIColor, indexTips: CGPoint, middleTips: CGPoint, indexPips:CGPoint, middlePips:CGPoint, pinchFlag:Bool){
        
        //指の検出が無効
        if(fingersConfidence == false){
            //モードviewの貼り付け
            
            testView.backgroundColor = .white
            view.layer.addSublayer(testView.layer)
            autoAction(modeNumber: -1)
            return;
        }
        
        //configの表示
        if(pinchFlag){
            
            pointColor = colorList[configList[2]][0]
            //モードviewの貼り付け
            testView.backgroundColor = colorList[configList[2]][0]
            view.layer.addSublayer(testView.layer)
            
            //.pinchedの連続回数を記録
            countPinchFrames.append(1)// 1 -> pintched
            countPinchFrames.remove(at: 0)//一番古い要素の削除
            
            print(countOneInList())
            //一定数以上連続したとき
            if(countOneInList() >= pinchedThreshold){
                autoAction(modeNumber: 3)
                //配列の初期化
                resetCountPinchFrame()
            }
            
            return;
        }else{
            //pinchではないとき
            countPinchFrames.append(0)
            countPinchFrames.remove(at: 0)//一番古い要素の削除
        }
        
        
        print(countPinchFrames.count)
        //        if((indexTips.y < indexPips.y) && (middleTips.y >= middlePips.y)){
        //            pointColor = .green
        //            //モードviewの貼り付け
        //            testView.backgroundColor = .green
        //            view.layer.addSublayer(testView.layer)
        //            autoAction(modeNumber: 2)
        //            return;
        //        }
        //上モード
        if ((indexTips.y < indexPips.y) && (middleTips.y < middlePips.y)){//第二関節が指先より上
            
            //モードviewの貼り付け
            testView.backgroundColor = colorList[configList[2]][1]
            view.layer.addSublayer(testView.layer)
            autoAction(modeNumber: 0)
            return;
            //下モード
        }else if((indexTips.y >= indexPips.y) && (middleTips.y >= middlePips.y)){//第二関節が指先より下
            pointColor = colorList[configList[2]][2]
            //モードviewの貼り付け
            testView.backgroundColor = colorList[configList[2]][2]
            view.layer.addSublayer(testView.layer)
            autoAction(modeNumber: 1)
            return;
            
        }
    }
    
    private func autoAction(modeNumber: Int){
        
        
        //contentSizehight -> webサイトの高さ, frame.size -> 写っている部分の高さ
        var maxYOffset = web.scrollView.contentSize.height - web.scrollView.frame.size.height;
        var y_offset = web.scrollView.contentOffset.y;//どこかのy座標
        var x_offset = web.scrollView.contentOffset.x;//どこかのx座標
        let scrollSpeed = 5-configList[1]; //スクロール感度
        //
        //        var mode = 1; //上スクロール，下スクロール，クリックのモード管理
        
        operatedWebView(idx: webFlag)//ブラウザボタンの監視
        
        //上スクロール
        if(modeNumber == 0){
            web.scrollView.setContentOffset(CGPoint(x: x_offset, y:max(y_offset - web.bounds.size.height/CGFloat(scrollSpeed),0)), animated: true)
            //viewX = x_offset; viewY = max(y_offset - web.bounds.size.height/CGFloat(scrollSpeed),0)
            //下スクロール
        }else if(modeNumber == 1){
            web.scrollView.setContentOffset(CGPoint(x: x_offset, y:min(y_offset + web.bounds.size.height/CGFloat(scrollSpeed), maxYOffset)), animated: true)
            //viewX = x_offset; viewY = min(y_offset + web.bounds.size.height/CGFloat(scrollSpeed), maxYOffset)
        }else if(modeNumber == 2){
            //web.scrollView.setContentOffset(CGPoint(x: viewX, y:viewY), animated: true)
            print("クリック")
        }else if(modeNumber == 3){
            //ここでconfigを呼ぶ
            openConfig()
            
            
        }else{
            //web.scrollView.setContentOffset(CGPoint(x: viewX, y:viewY), animated: true)
            //指の検出ができていない
        }
    }
    
    private func countTiming(){
        countTime += 1
    }
    
    //描画色
    private func handleGestureStateChange(state: HandGestureProcessor.State) {
        
        let pointsPair = gestureProcessor.lastProcessedPointsPair
        var tipsColor: UIColor
        var pintched:Bool = false
        switch state {
        case .possiblePinch, .possibleApart:
            // We are in one of the "possible": states, meaning there is not enough evidence yet to determine
            // 私たちは "可能性 "のある状態、つまり、まだ十分な証拠がない状態です。
            // if we want to draw or not. For now, collect points in the evidence buffer, so we can add them
            // to a drawing path when required.
            // 描画するかどうかを判断します。
            // とりあえず、エビデンスバッファにポイントを集めておけば、必要に応じて描画パスに追加することができます。
            evidenceBuffer.append(pointsPair)
            tipsColor = .white
        case .pinched:
            // We have enough evidence to draw. Draw the points collected in the evidence buffer, if any.
            for bufferedPoints in evidenceBuffer {
                updatePath(with: bufferedPoints, isLastPointsPair: false)
            }
            // Clear the evidence buffer.
            evidenceBuffer.removeAll()
            // Finally, draw the current point.
            updatePath(with: pointsPair, isLastPointsPair: false)
            pintched = true
            tipsColor = .green
        case .apart, .unknown://通常時
            // We have enough evidence to not draw. Discard any evidence buffer points.
            evidenceBuffer.removeAll()
            // And draw the last segment of our draw path.
            updatePath(with: pointsPair, isLastPointsPair: true)
            tipsColor = colorList[configList[2]][1]
        }
        
        //optionalのアンラップ(中指)
        guard let middleTipsUnwrap = middleTipsConverted else {
            return
        }
        
        guard let indexPipsUnwrap = indexPipsConverted else {
            return
        }
        
        guard let middlePipsUnwrap = middlePipsConverted else {
            return
        }
        
        if(slideFlag){
            //関数で判定
            judgeFingerPose(pointColor: &tipsColor, indexTips: pointsPair.indexTip, middleTips: middleTipsUnwrap, indexPips: indexPipsUnwrap, middlePips: middlePipsUnwrap, pinchFlag: pintched)
        }
        pintched = false
        
        if(configList[0] == 0){
            
        }else if(configList[0] == 1){
            cameraView.showPoints([pointsPair.thumbTip, pointsPair.indexTip, middleTipsUnwrap, indexPipsUnwrap, middlePipsUnwrap], color: tipsColor)//指先の表示
            web.layer.addSublayer(overlayLayer)//指の表示
        }
    }
    
    private func updatePath(with points: HandGestureProcessor.PointsPair, isLastPointsPair: Bool) {
        // Get the mid point between the tips.
        let (thumbTip, indexTip) = points
        let drawPoint = CGPoint.midPoint(p1: thumbTip, p2: indexTip)
        
        if isLastPointsPair {
            if let lastPoint = lastDrawPoint {
                // Add a straight line from the last midpoint to the end of the stroke.
                // 最後の中間点からストロークの終わりまで直線を加えます。
                drawPath.addLine(to: lastPoint)
            }
            // We are done drawing, so reset the last draw point.
            // 描画が終了したので、最後の描画ポイントをリセットします。
            lastDrawPoint = nil
        } else {
            if lastDrawPoint == nil {
                // This is the beginning of the stroke.
                // これがストロークの始まりです。
                //                drawPath.move(to: drawPoint)//線の描画の核
                isFirstSegment = true
            } else {
                let lastPoint = lastDrawPoint!
                // Get the midpoint between the last draw point and the new point.
                // 前回の描画点と新しい点の中間点を取得します。
                let midPoint = CGPoint.midPoint(p1: lastPoint, p2: drawPoint)
                if isFirstSegment {
                    // If it's the first segment of the stroke, draw a line to the midpoint.
                    // ストロークの最初のセグメントであれば、中間点まで線を引く。
                    drawPath.addLine(to: midPoint)
                    isFirstSegment = false
                } else {
                    // Otherwise, draw a curve to a midpoint using the last draw point as a control point.
                    // それ以外の場合は、最後に描いた点を制御点として、中間点まで曲線を描きます。
                    drawPath.addQuadCurve(to: midPoint, controlPoint: lastPoint)
                }
            }
            // Remember the last draw point for the next update pass.
            lastDrawPoint = drawPoint
        }
        // Update the path on the overlay layer.
        drawOverlay.path = drawPath.cgPath
    }
    
    @IBAction func handleGesture(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else {
            return
        }
        evidenceBuffer.removeAll()
        drawPath.removeAllPoints()
        drawOverlay.path = drawPath.cgPath
    }
    //配列内の1の数を返す
    func countOneInList() -> Int {
        let sum:Int = countPinchFrames[0...(countPinchFrames.count-1)].filter({$0 == 1}).count //1の取得
        return (sum)
    }
    
    //要素を0に初期化
    func resetCountPinchFrame() {
        countPinchFrames = [Int]()
        for _ in (0 ..< pinchedThreshold + 10) {
            countPinchFrames.append(0)// 0 -> unpinchedを追加
        }
    }
    
    func closeTopLayer(){
        //        if(countTime == 0){
        //            let layer = view.layer.sublayers![4]
        //            view.layer.sublayers![4] = view.layer.sublayers![0]
        //            view.layer.sublayers![0]  = layer
        //        }
        if(countTime > 61){
            topCloseFlag = true
            return
        }
        
        if(countTime == 60){
            //webとtop
            let layer = view.layer.sublayers![4]
            view.layer.sublayers![4] = view.layer.sublayers![1]
            view.layer.sublayers![1]  = layer
            
            let layer2 = view.layer.sublayers![1]
            view.layer.sublayers![1] = view.layer.sublayers![2]
            view.layer.sublayers![2]  = layer2
            //
            //            print(view.layer.sublayers![0].name as Any)
            //            print(view.layer.sublayers![1].name as Any)
            //            print(view.layer.sublayers![2].name as Any)
            //            print(view.layer.sublayers![3].name as Any)
            //            print(view.layer.sublayers![4].name as Any)
            topCloseFlag = true
        }else{
            topCloseFlag = false
        }
    }
}

@available(iOS 14.0, *)
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //指変数のインスタンス
        var thumbTip: CGPoint?
        var indexTip: CGPoint?
        var middleTip: CGPoint?
        var indexPip: CGPoint?
        var middlePip: CGPoint?
        
        defer {
            DispatchQueue.main.sync {
                self.processPoints(thumbTip: thumbTip, indexTip: indexTip, middleTip: middleTip, indexPip: indexPip, middlePip: middlePip)
            }
        }
        
        //おそらくVisionを動かすコンストラクタ
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            // Perform VNDetectHumanHandPoseRequest
            try handler.perform([handPoseRequest])//手で指定
            // Continue only when a hand was detected in the frame.
            // フレーム内に手が検出された場合のみ続行します。
            // Since we set the maximumHandCount property of the request to 1, there will be at most one observation.
            //リクエストの maximumHandCount プロパティを 1 に設定しているため、観測は最大でも 1 回となります。
            guard let observation = handPoseRequest.results?.first else {
                fingersConfidence = false
                return
            }
            // Get points for thumb and index finger.
            // 親指と人差し指にポイントが入ります。
            let thumbPoints = try observation.recognizedPoints(.thumb)//親指の取得
            let indexFingerPoints = try observation.recognizedPoints(.indexFinger)//人差し指の取得
            let middleFingerPoints = try observation.recognizedPoints(.middleFinger)//中指の取得
            
            // Look for tip points.
            // ティップポイントを探す
            guard let thumbTipPoint = thumbPoints[.thumbTip],
                  let indexTipPoint = indexFingerPoints[.indexTip],
                  let middleTipPoint = middleFingerPoints[.middleTip],
                  let indexPipPoint = indexFingerPoints[.indexPIP],
                  let middlePipPoint = middleFingerPoints[.middlePIP]
            else {
                fingersConfidence = false
                return
            }
            // Ignore low confidence points.
            
            let confidencePoint:Float = 0.5
            // 信頼度の低いポイントは無視する。
            guard thumbTipPoint.confidence > confidencePoint && indexTipPoint.confidence > confidencePoint && middleTipPoint.confidence > confidencePoint && indexPipPoint.confidence > confidencePoint && middlePipPoint.confidence > confidencePoint else {
                print("指の検出が正常ではありません．")
                fingersConfidence = false
                return
            }
            print("指の検出は正常です．")
            fingersConfidence = true
            // Convert points from Vision coordinates to AVFoundation coordinates.
            // ポイントをVision座標からAVFoundation座標に変換します。
            thumbTip = CGPoint(x: thumbTipPoint.location.x, y: 1 - thumbTipPoint.location.y)
            indexTip = CGPoint(x: indexTipPoint.location.x, y: 1 - indexTipPoint.location.y)
            middleTip = CGPoint(x: middleTipPoint.location.x, y: 1 - middleTipPoint.location.y)
            indexPip = CGPoint(x: indexPipPoint.location.x, y: 1 - indexPipPoint.location.y)
            middlePip = CGPoint(x: middlePipPoint.location.x, y: 1 - middlePipPoint.location.y)
            middleTips = middleTip
            indexPips = indexPip
            middlePips = middlePip
            
        } catch {
            //エラー処理
            cameraFeedSession?.stopRunning()
            let error = AppError.visionError(error: error)
            DispatchQueue.main.async {
                error.displayInViewController(self)
            }
        }
    }
}

