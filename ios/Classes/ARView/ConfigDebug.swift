import Foundation
import UIKit

class ConfigDebug {
    
    var arQuality: ARQuality?
    var hasToRefresh: Bool
    
    var debugButton: UIButton?
    var updateButton: UIButton?
    var infoPanel: UIView?
    var infoLabel: UILabel?
    var isInfoVisible = false
    var refreshTimer: Timer?
    
    var infoLabel1: UILabel?
    var infoLabel2: UILabel?
    var infoLabel3: UILabel?
    var infoLabel4: UILabel?
    var infoLabel5: UILabel?
    var infoLabel6: UILabel?
    var infoLabel7: UILabel?
    var infoLabel8: UILabel?
    
    var configTextField1: UITextField?
    var configTextField2: UITextField?
    var configTextField3: UITextField?
    var configTextField4: UITextField?
    
    var qualityDecrease = 0.005
    var thresholdDecrease = 0.03
    var cameraDeph = 30
    var arrowDistance = 20
    var configStackView: UIStackView?
    var infoStackView: UIStackView?
    var mainStackView: UIStackView?
    let expandedSpacing: CGFloat = 20
    let collapsedSpacing: CGFloat = -180
    var hasToReset = false
  

    init(arQuality: ARQuality?, hasToRefresh: Bool) {
        self.arQuality = arQuality
        self.hasToRefresh = hasToRefresh
    }
    
    
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        // Execute action only when the gesture starts
        if gesture.state == .began {
            toggleInfoDebug()
        }
    }
    
    // Function to create the Toggle Info button
    func setupUpdateDebugInfo(view: UIView) {
        debugButton = UIButton(type: .system)
        debugButton?.setImage(UIImage(systemName: "gear"), for: .normal)
        debugButton?.tintColor = .clear
        debugButton?.backgroundColor = .clear
        debugButton?.setTitleColor(.white, for: .normal)
        debugButton?.layer.cornerRadius = 10
        debugButton?.frame = CGRect(x: 320, y: 30, width: 40, height: 40)
        debugButton?.layer.borderColor = UIColor.white.cgColor
                
        if let debugButton = debugButton {
            view.addSubview(debugButton)
            
            // Add the long press gesture
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
            longPressGesture.minimumPressDuration = 1.0 //Minimum duration (1 second)
            debugButton.addGestureRecognizer(longPressGesture)
        }
                
        updateButton = UIButton(type: .custom)
        updateButton?.setImage(UIImage(systemName: "gobackward"), for: .normal)
        updateButton?.tintColor = .white
        updateButton?.backgroundColor = .systemGray
        updateButton?.layer.cornerRadius = 10
        updateButton?.frame = CGRect(x: 270, y: 30, width: 40, height: 40)
        updateButton?.addTarget(self, action: #selector(resetARWorld), for: .touchUpInside)
        updateButton?.isHidden = true
        
        // Add whitte border
        updateButton?.layer.borderColor = UIColor.white.cgColor
        updateButton?.layer.borderWidth = 2.0
        

        if let updateButton = updateButton {
            view.addSubview(updateButton)
        }

        // Add a tap gesture to hide the keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }

    // Function to hide the keyboard
    @objc func dismissKeyboard() {
        configTextField1?.resignFirstResponder()
        configTextField2?.resignFirstResponder()
        configTextField3?.resignFirstResponder()
        configTextField4?.resignFirstResponder()
    }

    // Create the information and configuration panel
    func setupInfoPanel(view: UIView) {
        infoPanel = UIView()
        infoPanel?.translatesAutoresizingMaskIntoConstraints = false
        infoPanel?.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        infoPanel?.layer.cornerRadius = 10
        infoPanel?.layer.borderWidth = 2
        infoPanel?.layer.borderColor = UIColor.lightGray.cgColor
        infoPanel?.isHidden = true

        // Create the configuration view with informational labels
        let qualityDecreaseField = createLabeledTextField(labelText: "Quality Decrease:", placeholder: "Decrease in quality", value: String(qualityDecrease))
        let thresholdDecreaseField = createLabeledTextField(labelText: "Threshold Decrease:", placeholder: "Decrease in threshold", value: String(thresholdDecrease))
        let cameraDepthField = createLabeledTextField(labelText: "Camera Depth:", placeholder: "Max camera depth", value: String(cameraDeph))
        let arrowDistanceField = createLabeledTextField(labelText: "Arrow Distance:", placeholder: "Distance for arrow", value: String(arrowDistance))

        // Extract UITextFields from UIStackViews
        configTextField1 = qualityDecreaseField.arrangedSubviews[1] as? UITextField
        configTextField2 = thresholdDecreaseField.arrangedSubviews[1] as? UITextField
        configTextField3 = cameraDepthField.arrangedSubviews[1] as? UITextField
        configTextField4 = arrowDistanceField.arrangedSubviews[1] as? UITextField

        // Arranging configuration fields in a UIStackView
        configStackView = UIStackView(arrangedSubviews: [qualityDecreaseField, thresholdDecreaseField, cameraDepthField, arrowDistanceField])
        configStackView?.axis = .vertical
        configStackView?.spacing = 10
        configStackView?.alignment = .fill

        // Create the configuration top with a switch
        let configView = UIView()
        let configLabel = UILabel()
        configLabel.text = "Activar Configuración:"
        configLabel.textColor = .white

        let configSwitch = UISwitch()
        configSwitch.isOn = false
        configSwitch.addTarget(self, action: #selector(configSwitchChanged(_:)), for: .valueChanged)

        let configHeaderStackView = UIStackView(arrangedSubviews: [configLabel, configSwitch])
        configHeaderStackView.axis = .horizontal
        configHeaderStackView.spacing = 10
        configHeaderStackView.alignment = .center

        // Adding the header and configuration fields to the configView
        configView.addSubview(configHeaderStackView)
        configView.addSubview(configStackView!)

        // Adjusting the layout with Auto Layout
        configHeaderStackView.translatesAutoresizingMaskIntoConstraints = false
        configStackView?.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            configHeaderStackView.topAnchor.constraint(equalTo: configView.topAnchor, constant: 10),
            configHeaderStackView.leadingAnchor.constraint(equalTo: configView.leadingAnchor, constant: 10),
            configHeaderStackView.trailingAnchor.constraint(equalTo: configView.trailingAnchor, constant: -10),

            configStackView!.topAnchor.constraint(equalTo: configHeaderStackView.bottomAnchor, constant: 10),
            configStackView!.leadingAnchor.constraint(equalTo: configView.leadingAnchor, constant: 10),
            configStackView!.trailingAnchor.constraint(equalTo: configView.trailingAnchor, constant: -10),
            configStackView!.bottomAnchor.constraint(equalTo: configView.bottomAnchor, constant: -10)
        ])

        // Hide settings initially
        configStackView?.isHidden = true

        // Create the information labels
        infoLabel1 = UILabel()
        infoLabel2 = UILabel()
        infoLabel3 = UILabel()
        infoLabel4 = UILabel()
        infoLabel5 = UILabel()
        infoLabel6 = UILabel()
        infoLabel7 = UILabel()
        infoLabel8 = UILabel()
        

        // Setting up labels
        [infoLabel1, infoLabel2, infoLabel3, infoLabel4, infoLabel5, infoLabel6, infoLabel7, infoLabel8].forEach { label in
            label?.textAlignment = .left
            label?.textColor = .white
        }

        // Organizing information labels in a UIStackView
        infoStackView = UIStackView(arrangedSubviews: [infoLabel2!, infoLabel3!, infoLabel6!, infoLabel5!, infoLabel7!, infoLabel7!, infoLabel8!, infoLabel1!])
        infoStackView?.axis = .vertical
        infoStackView?.spacing = 5
        infoStackView?.alignment = .fill

        // Create the main StackView that contains the configuration and information
        mainStackView = UIStackView(arrangedSubviews: [configView, infoStackView!])
        mainStackView?.axis = .vertical
        mainStackView?.spacing = collapsedSpacing // Leading spacing when settings are hidden
        mainStackView?.translatesAutoresizingMaskIntoConstraints = false

        // Adding the main StackView to the infoPanel view
        infoPanel?.addSubview(mainStackView!)

        // Setting constraints for the mainStackView
        NSLayoutConstraint.activate([
            mainStackView!.leadingAnchor.constraint(equalTo: infoPanel!.leadingAnchor, constant: 10),
            mainStackView!.trailingAnchor.constraint(equalTo: infoPanel!.trailingAnchor, constant: -10),
            mainStackView!.topAnchor.constraint(equalTo: infoPanel!.topAnchor, constant: 10),
            mainStackView!.bottomAnchor.constraint(equalTo: infoPanel!.bottomAnchor, constant: -10)
        ])

        // Add InfoPanel to Main View
        if let panel = infoPanel {
            view.addSubview(panel)

            // Setting up restrictions for infoPanel
            NSLayoutConstraint.activate([
                panel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                panel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
                panel.topAnchor.constraint(equalTo: debugButton!.bottomAnchor, constant: 10),
                panel.topAnchor.constraint(equalTo: updateButton!.bottomAnchor, constant: 10)
            ])
        }
    }

    // Method to create a labeled text field
    private func createLabeledTextField(labelText: String, placeholder: String, value: String) -> UIStackView {
        let label = UILabel()
        label.text = labelText
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14)
        label.widthAnchor.constraint(equalToConstant: 150).isActive = true

        let textField = UITextField()
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.text = value
        textField.isUserInteractionEnabled = true
        textField.isEnabled = true
        textField.addTarget(self, action: #selector(configTextFieldDidChange(_:)), for: .editingChanged)

        let stackView = UIStackView(arrangedSubviews: [label, textField])
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.alignment = .center

        return stackView
    }

    private func createTextField(placeholder: String, value: String) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.text = value
        textField.isUserInteractionEnabled = true
        textField.isEnabled = true
        textField.addTarget(self, action: #selector(configTextFieldDidChange(_:)), for: .editingChanged)
        return textField
    }
    
    func setParametersUpdated() {
        arQuality?.setQualityDecrease(qualityDecrease: Float(qualityDecrease))
        arQuality?.setThresholdDecrease(thresholdDecrease: Float(thresholdDecrease))
    }
    
    func getConfigParameters() -> [String: Double] {
        let configParameters: [String: Double] = [
            "qualityDecrease: ": qualityDecrease,
            "thresholdDecrease": thresholdDecrease,
            "cameraDeph": Double(cameraDeph),
            "arrowDistance": Double(arrowDistance),
            "HiddenPanelInfo": infoPanel?.isHidden == true ? 1.0 : 0.0
        ]

        return configParameters
    }
    
    @objc func configTextFieldDidChange(_ textField: UITextField) {
        if textField == configTextField1 {
            print("Quality decrease: \(textField.text ?? "")")
            if let text = textField.text, let value = Double(text) {
                qualityDecrease = value
            } else {
                print("Error: the value of qualityDecrease is not a valid number")
            }
            
        } else if textField == configTextField2 {
            print("Threshold decrease: \(textField.text ?? "")")
            if let text = textField.text, let value = Double(text) {
                thresholdDecrease = value
            } else {
                print("Error: the value of thresholdDecrease is not a valida number")
            }
            
        } else if textField == configTextField3 {
            print("Camera depth: \(textField.text ?? "")")
            if let text = textField.text, let value = Int(text) {
                cameraDeph = value
            } else {
                print("Error: the value of cameraDeph is not a valida number")
            }
            
        } else if textField == configTextField4 {
            print("Arrow distance: \(textField.text ?? "")")
            if let text = textField.text, let value = Int(text) {
                arrowDistance = value
            } else {
                print("Error: the value of arrowDistance is not a valida number")
            }
        }
    }

    @objc func configSwitchChanged(_ sender: UISwitch) {
        configStackView?.isHidden = !sender.isOn
        mainStackView?.spacing = sender.isOn ? expandedSpacing : collapsedSpacing
    }

    // Function that is called when the configuration switch value is changed
    @objc func toggleInfoDebug() {
        guard let panel = infoPanel else { return }
        panel.isHidden.toggle()
        isInfoVisible.toggle()
        updateButton?.isHidden = panel.isHidden
    }
    
    @objc func resetARWorld() {
        hasToReset = true
    }
    
    func disableHasToReset() {
        self.hasToReset = false
    }

    // Function to start refreshing information in real time
    func startRefreshingInfo() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateAll), userInfo: nil, repeats: true)
    }

    @objc func updateAll() {
        setParametersUpdated()
        updateInfoPanel()
    }

    // Function that updates the information displayed on the panel
    @objc func updateInfoPanel() {
        guard let arQuality = arQuality else {
            print("Error: arQuality es nil")
            return
        }
        
        // Get the latest information on arQuality
        let infoDebug = arQuality.getInfoParameters()
        
        if let globalQuality = infoDebug["globalQuality"] as? Double {
            let roundedQuality = String(format: "%.2f", globalQuality)
            let odometriesDistanceConf = String(format: "%.2f",arQuality.odometriesDistanceConf)
            let arDisplacementConf = String(format: "%.2f", arQuality.arDisplacementConf)
            let situmDisplacementConf = String(format: "%.2f",arQuality.situmDisplacementConf)

            // Update labels with new values, unwrapping optionals
            infoLabel1?.text = "HasToRefresh: \(arQuality.hasToResetWorld())"
            infoLabel2?.text = "Quality: \(roundedQuality)"
            infoLabel6?.text = "OdometriesDistanceConf: \(odometriesDistanceConf)"
            infoLabel7?.text = "SitumDisplacementConf: \(situmDisplacementConf)"
            infoLabel8?.text = "ArDisplacementConf: \(arDisplacementConf)"
            
            
            // Make sure you unwrap optional variables correctly
            if let dynamicRefreshThreshold = infoDebug["DynamicRefreshThreshold"] {
                infoLabel3?.text = "DynamicRefreshThreshold: \(dynamicRefreshThreshold)"
            } else {
                infoLabel3?.text = "DynamicRefreshThreshold: N/A"
            }
            
            if let arConf = infoDebug["arConf"] {
                infoLabel4?.text = "ArConf: \(arConf)"
            } else {
                infoLabel4?.text = "ArConf: N/A"
            }
            
            if let situmConf = infoDebug["situmConf"] {
                infoLabel5?.text = "SitumConf: \(situmConf)"
            } else {
                infoLabel5?.text = "SitumConf: N/A"
            }
        } else {
            infoLabel2?.text = "Quality: N/A"
        }
        
    }

    // Stop soda when not needed
    func stopRefreshingInfo() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

