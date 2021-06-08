//
//  Config.swift
//  HandPose
//
//  Created by 正村真悟 on 2021/04/24.
//  Copyright © 2021 Apple. All rights reserved.
//

import UIKit

class Config: UIViewController {
    
    @IBOutlet weak var mode: UILabel!
    @IBOutlet weak var Switch2: UISwitch!
    
    
    @IBOutlet weak var sensitivityLabel: UILabel!
    @IBOutlet weak var sensitivityValue: UILabel!
    @IBOutlet weak var sensitivitySlider: UISlider!
    
    
    @IBOutlet weak var cursorColor: UILabel!
    @IBOutlet weak var cursorColorSegment: UISegmentedControl!
    
    
    @IBOutlet weak var isPressedLabel: UILabel!
    @IBOutlet weak var PressedTimeStepper: UIStepper!
    @IBOutlet weak var pressedTimeValue: UILabel!
    
    
    var modeOnOff = 1
    var scrollSensitivity = 3
    var cursorColors = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if(configList[0] == 0){
            Switch2.setOn(false, animated: false)
        } else if(configList[0] == 1){
            Switch2.setOn(true, animated: false)
        }
        
        sensitivitySlider.setValue(Float(configList[1]), animated: false)
        sensitivityValue.text = String(Int(configList[1]))
        
        cursorColorSegment.selectedSegmentIndex = configList[2]
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        slideFlag = false // 後ろでスライドを停止
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        slideFlag = true // スライドを開始
    }
    
    @IBAction func changeModeStatus(_ sender: UISwitch) {
        if(sender.isOn){
            modeOnOff = 1
        } else {
            modeOnOff = 0
        }
        print(modeOnOff)
        configList[0] = modeOnOff
        
    }

    @IBAction func changeScrollValue(_ sender: UISlider) {
        scrollSensitivity = Int(sender.value)
        sensitivityValue.text = String(scrollSensitivity)
        configList[1] = scrollSensitivity
    }
    
    
    @IBAction func changeColor(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
                case 0:
                    cursorColors = 0
                    print(cursorColors)
                    configList[2] = cursorColors
                    break
                case 1:
                    cursorColors = 1
                    print(cursorColors)
                    configList[2] = cursorColors
                    break
                case 2:
                    cursorColors = 2
                    print(cursorColors)
                    configList[2] = cursorColors
                    break
                default:
                    break
                }
    }
}
