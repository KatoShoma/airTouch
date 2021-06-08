//
//  ContainerViewController.swift
//  HandPose
//
//  Created by 田中海斗 on 2021/04/24.
//  Copyright © 2021 Apple. All rights reserved.
//
import UIKit
import AVFoundation
import Vision
import WebKit
import Foundation

public var webFlag:Int = -1

class ContainerViewController: UIViewController {
    public let cameraViewController = CameraViewController()
    
    @IBAction func backButton(_ sender: Any) {
        webFlag = 0;//戻るボタンフラグ
    }
    @IBAction func goButton(_ sender: Any) {
        webFlag = 1;//進むボタンフラグ
    }
    @IBAction func reloadButton(_ sender: Any) {
        webFlag = 2;//リロードボタンフラグ
    }
    
    @IBOutlet weak var back: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        //背景色を黄色にする
        self.view.backgroundColor = UIColor(red: 255/255, green: 255/255, blue: 190/255, alpha: 1.0)
    }
}
