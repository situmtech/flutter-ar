import Foundation


class ConfigDebug {
    
    var arQuality: ARQuality?
    var hasToRefresh: Bool
    
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
    
    var configTextField1: UITextField?
    var configTextField2: UITextField?
    var configTextField3: UITextField?
    var configTextField4: UITextField?
    
    var qualityDecrease = 0.005
    var thresholdDecrease = 0.03
    var cameraDeph = 20
    var arrowDistance = 5
    
    var configStackView: UIStackView?
    var infoStackView: UIStackView?
    var mainStackView: UIStackView?
    
    let expandedSpacing: CGFloat = 20
    let collapsedSpacing: CGFloat = -180

    
    init(arQuality: ARQuality?, hasToRefresh: Bool) {
            self.arQuality = arQuality
            self.hasToRefresh = hasToRefresh
        }

    
    // Función para crear el botón de Toggle Info
    func setupUpdateDebugInfo(view: UIView) {
        updateButton = UIButton(type: .system)
        updateButton?.setTitle("Info Debug", for: .normal)
        updateButton?.backgroundColor = .systemBlue
        updateButton?.setTitleColor(.white, for: .normal)
        updateButton?.layer.cornerRadius = 10
        updateButton?.frame = CGRect(x: 20, y: 20, width: 100, height: 30)
        updateButton?.addTarget(self, action: #selector(toggleInfoDebug), for: .touchUpInside)
        
        if let button = updateButton {
            view.addSubview(button)
        }
    }

        // Crear el panel de información y configuración
    func setupInfoPanel(view: UIView) {
         infoPanel = UIView()
         infoPanel?.translatesAutoresizingMaskIntoConstraints = false
         infoPanel?.backgroundColor = .clear
         infoPanel?.layer.cornerRadius = 10
         infoPanel?.layer.borderWidth = 2
         infoPanel?.layer.borderColor = UIColor.lightGray.cgColor
         
         // Crear la vista de configuración
         configTextField1 = createTextField(placeholder: "Quality decrease", value: String(qualityDecrease))
         configTextField2 = createTextField(placeholder: "Threshold decrease", value: String(thresholdDecrease))
         configTextField3 = createTextField(placeholder: "Camera depth", value: String(cameraDeph))
         configTextField4 = createTextField(placeholder: "Arrow distance", value: String(arrowDistance))
         
         // Organizar los campos de configuración en un UIStackView
         configStackView = UIStackView(arrangedSubviews: [configTextField1!, configTextField2!, configTextField3!, configTextField4!])
         configStackView?.axis = .vertical
         configStackView?.spacing = 10
         configStackView?.alignment = .fill
         
         // Crear la parte superior de configuración con un switch
         let configView = UIView()
         let configLabel = UILabel()
         configLabel.text = "Activar Configuración:"
         configLabel.textColor = .black
         
         let configSwitch = UISwitch()
         configSwitch.isOn = false
         configSwitch.addTarget(self, action: #selector(configSwitchChanged(_:)), for: .valueChanged)
         
         let configHeaderStackView = UIStackView(arrangedSubviews: [configLabel, configSwitch])
         configHeaderStackView.axis = .horizontal
         configHeaderStackView.spacing = 10
         configHeaderStackView.alignment = .center
         
         // Agregar la cabecera y campos de configuración al configView
         configView.addSubview(configHeaderStackView)
         configView.addSubview(configStackView!)
         
         // Ajustar el layout con Auto Layout
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
         
         // Ocultar configuración inicialmente
         configStackView?.isHidden = true
         
         // Crear las etiquetas de información
         infoLabel1 = UILabel()
         infoLabel2 = UILabel()
         infoLabel3 = UILabel()
         infoLabel4 = UILabel()
         infoLabel5 = UILabel()
         
         // Configurar las etiquetas
         [infoLabel1, infoLabel2, infoLabel3, infoLabel4, infoLabel5].forEach { label in
             label?.textAlignment = .left
             label?.textColor = .black
         }
         
         // Organizar las etiquetas de información en un UIStackView
         infoStackView = UIStackView(arrangedSubviews: [infoLabel1!, infoLabel2!, infoLabel3!, infoLabel4!, infoLabel5!])
         infoStackView?.axis = .vertical
         infoStackView?.spacing = 5
         infoStackView?.alignment = .fill
         
         // Crear el StackView principal que contiene la configuración y la información
         mainStackView = UIStackView(arrangedSubviews: [configView, infoStackView!])
         mainStackView?.axis = .vertical
         mainStackView?.spacing = collapsedSpacing // Espaciado inicial cuando la configuración está oculta
         mainStackView?.translatesAutoresizingMaskIntoConstraints = false
         
         // Agregar el StackView principal a la vista infoPanel
         infoPanel?.addSubview(mainStackView!)
         
         // Configurar restricciones para el mainStackView
         NSLayoutConstraint.activate([
             mainStackView!.leadingAnchor.constraint(equalTo: infoPanel!.leadingAnchor, constant: 10),
             mainStackView!.trailingAnchor.constraint(equalTo: infoPanel!.trailingAnchor, constant: -10),
             mainStackView!.topAnchor.constraint(equalTo: infoPanel!.topAnchor, constant: 10),
             mainStackView!.bottomAnchor.constraint(equalTo: infoPanel!.bottomAnchor, constant: -10)
         ])
         
         // Agregar infoPanel a la vista principal
         if let panel = infoPanel {
             view.addSubview(panel)
             
             // Configurar restricciones para infoPanel
             NSLayoutConstraint.activate([
                 panel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                 panel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
                 panel.topAnchor.constraint(equalTo: updateButton!.bottomAnchor, constant: 10)
             ])
         }
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
    
    func setParametersUpdated(){
        arQuality?.setQualityDecrease(qualityDecrease: Float(qualityDecrease))
        arQuality?.setThresholdDecrease(thresholdDecrease: Float(thresholdDecrease))
    }
    
    func getConfigParameters() -> [String: Double]{
        
        let configParameters: [String: Double]  = [
            "qualityDecrease: ": qualityDecrease,
            "thresholdDecrease": thresholdDecrease, 
            "cameraDeph": Double(cameraDeph),
            "arrowDistance": Double(arrowDistance)
        ]

        
        return configParameters
        
    }
    
    @objc func configTextFieldDidChange(_ textField: UITextField) {
        if textField == configTextField1 {
            print("Quality decrease: \(textField.text ?? "")")
            if let text = textField.text, let value = Double(text) {
                qualityDecrease = value
            } else {
                print("Error: el valor de qualityDecrease no es un número válido")
            }
            
        } else if textField == configTextField2 {
            print("Threshold decrease: \(textField.text ?? "")")
            if let text = textField.text, let value = Double(text) {
                thresholdDecrease = value
            } else {
                print("Error: el valor de thresholdDecrease no es un número válido")
            }
            
        } else if textField == configTextField3 {
            print("Camera depth: \(textField.text ?? "")")
            if let text = textField.text, let value = Int(text) {
                cameraDeph = value
            } else {
                print("Error: el valor de cameraDeph no es un número válido")
            }
            
        } else if textField == configTextField4 {
            print("Arrow distance: \(textField.text ?? "")")
            // Convertir el texto a Double o el tipo adecuado
            if let text = textField.text, let value = Int(text) {
                arrowDistance = value
            } else {
                print("Error: el valor de arrowDistance no es un número válido")
            }
        }
    }

    @objc func configSwitchChanged(_ sender: UISwitch) {
        configStackView?.isHidden = !sender.isOn
        mainStackView?.spacing = sender.isOn ? expandedSpacing : collapsedSpacing
    }


        // Función que se llama cuando se cambia el valor del switch de configuración
    @objc func toggleInfoDebug() {
            guard let panel = infoPanel else { return }
            panel.isHidden.toggle()
            isInfoVisible.toggle()
        }

        // Función para iniciar el refresco de la información en tiempo real
        func startRefreshingInfo() {
            refreshTimer?.invalidate()
            refreshTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateAll), userInfo: nil, repeats: true)
        }

        @objc func updateAll() {
            setParametersUpdated()
            updateInfoPanel()
        }
        // Función que actualiza la información mostrada en el panel
    @objc func updateInfoPanel() {
        guard let arQuality = arQuality else {
            print("Error: arQuality es nil")
            return
        }
        
        // Obtener la información actualizada de arQuality
        let infoDebug = arQuality.getInfoParameters()
        
        if let globalQuality = infoDebug["globalQuality"] as? Double {
            let roundedQuality = (globalQuality * 100).rounded() / 100
            
            // Actualizar las etiquetas con los nuevos valores, desenvolviendo opcionales
            infoLabel1?.text = "HasToRefresh: \(hasToRefresh)"
            infoLabel2?.text = "GlobalQuality: \(roundedQuality)"
            
            // Asegúrate de desenvolver correctamente las variables opcionales
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
            infoLabel2?.text = "GlobalQuality: N/A"
        }
    }


        // Detener el refresco cuando no sea necesario
        func stopRefreshingInfo() {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    
    
}
