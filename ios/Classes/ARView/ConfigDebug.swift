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
    
    init(arQuality: ARQuality?, hasToRefresh: Bool) {
            self.arQuality = arQuality
            self.hasToRefresh = hasToRefresh
        }

    
    // Función para crear el botón de Toggle Info
        func setupUpdateDebugInfo(view: UIView) {
            // Crear el botón
            updateButton = UIButton(type: .system)
            updateButton?.setTitle("Info Debug", for: .normal)
            updateButton?.frame = CGRect(x: 20, y: 20, width: 100, height: 30)
            updateButton?.backgroundColor = .systemBlue
            updateButton?.setTitleColor(.white, for: .normal)
            updateButton?.layer.cornerRadius = 10

            // Añadir la acción del botón
            updateButton?.addTarget(self, action: #selector(toggleInfoDebug), for: .touchUpInside)

            // Añadir el botón a la vista principal
            if let button = updateButton {
                view.addSubview(button)
            }
        }

        // Crear el panel de información y configuración
    func setupInfoPanel(view: UIView) {
 
            infoPanel = UIView(frame: CGRect(x: 10, y: 50, width: view.frame.width - 40, height: 300))
            infoPanel?.backgroundColor = .clear
            infoPanel?.layer.cornerRadius = 10
            infoPanel?.layer.borderWidth = 2
            infoPanel?.layer.borderColor = UIColor.lightGray.cgColor

            infoLabel1 = UILabel(frame: CGRect(x: 10, y: 10, width: infoPanel!.frame.width - 20, height: 20))
            infoLabel1?.textAlignment = .left
            infoLabel1?.textColor = .gray
            infoPanel?.addSubview(infoLabel1!)

            infoLabel2 = UILabel(frame: CGRect(x: 10, y: 30, width: infoPanel!.frame.width - 20, height: 20))
            infoLabel2?.textAlignment = .left
            infoLabel2?.textColor = .gray
            infoPanel?.addSubview(infoLabel2!)

            infoLabel3 = UILabel(frame: CGRect(x: 10, y: 50, width: infoPanel!.frame.width - 20, height: 20))
            infoLabel3?.textAlignment = .left
            infoLabel3?.textColor = .gray
            infoPanel?.addSubview(infoLabel3!)

            infoLabel4 = UILabel(frame: CGRect(x: 10, y: 70, width: infoPanel!.frame.width - 20, height: 20))
            infoLabel4?.textAlignment = .left
            infoLabel4?.textColor = .gray
            infoPanel?.addSubview(infoLabel4!)

            infoLabel5 = UILabel(frame: CGRect(x: 10, y: 90, width: infoPanel!.frame.width - 20, height: 20))
            infoLabel5?.textAlignment = .left
            infoLabel5?.textColor = .gray
            infoPanel?.addSubview(infoLabel5!)

            // Sección de configuración
        
            // Sección de configuración
            let configLabel = UILabel(frame: CGRect(x: 10, y: 120, width: 200, height: 20))
            configLabel.text = "Activar Configuración:"
            configLabel.textColor = .gray
            infoPanel?.addSubview(configLabel)

            let configSwitch = UISwitch(frame: CGRect(x: infoPanel!.frame.width - 70, y: 120, width: 50, height: 30))
            configSwitch.isOn = false
            configSwitch.addTarget(self, action: #selector(configSwitchChanged(_:)), for: .valueChanged)
            infoPanel?.addSubview(configSwitch)

            // Campos de configuración (ocultos inicialmente)
            configTextField1 = UITextField(frame: CGRect(x: 10, y: 150, width: infoPanel!.frame.width - 20, height: 30))
            configTextField1?.placeholder = "Quality decrease"
            configTextField1?.borderStyle = .roundedRect
            configTextField1?.isHidden = true
            configTextField1?.text = String(qualityDecrease)
            configTextField1?.addTarget(self, action: #selector(configTextFieldDidChange(_:)), for: .editingChanged)
            infoPanel?.addSubview(configTextField1!)

            configTextField2 = UITextField(frame: CGRect(x: 10, y: 190, width: infoPanel!.frame.width - 20, height: 30))
            configTextField2?.placeholder = "Threshold decrease"
            configTextField2?.borderStyle = .roundedRect
            configTextField2?.isHidden = true
            configTextField2?.text = String(thresholdDecrease)
            configTextField2?.addTarget(self, action: #selector(configTextFieldDidChange(_:)), for: .editingChanged)
            infoPanel?.addSubview(configTextField2!)
        
            configTextField3 = UITextField(frame: CGRect(x: 10, y: 230, width: infoPanel!.frame.width - 20, height: 30))
            configTextField3?.placeholder = "Camera deph"
            configTextField3?.borderStyle = .roundedRect
            configTextField3?.isHidden = true
            configTextField3?.text = String(cameraDeph)
            configTextField3?.addTarget(self, action: #selector(configTextFieldDidChange(_:)), for: .editingChanged)
            infoPanel?.addSubview(configTextField3!)
            
            configTextField4 = UITextField(frame: CGRect(x: 10, y: 270, width: infoPanel!.frame.width - 20, height: 30))
            configTextField4?.placeholder = "Arrow distance"
            configTextField4?.borderStyle = .roundedRect
            configTextField4?.isHidden = true
            configTextField4?.text = String(arrowDistance)
            configTextField4?.addTarget(self, action: #selector(configTextFieldDidChange(_:)), for: .editingChanged)
            infoPanel?.addSubview(configTextField4!)
            
            if let panel = infoPanel {
                panel.isHidden = true
                view.addSubview(panel)
            }
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



        // Función que se llama cuando se cambia el valor del switch de configuración
    @objc func configSwitchChanged(_ sender: UISwitch) {
            if sender.isOn {
                configTextField1?.isHidden = false
                configTextField2?.isHidden = false
                configTextField3?.isHidden = false
                configTextField4?.isHidden = false
                infoPanel?.frame.size.height = 320
            } else {
                configTextField1?.isHidden = true
                configTextField2?.isHidden = true
                configTextField3?.isHidden = true
                configTextField4?.isHidden = true
                infoPanel?.frame.size.height = 150
            }
        }

        // Función para alternar entre mostrar y ocultar el panel
        @objc func toggleInfoDebug() {
            if let panel = infoPanel {
                panel.isHidden = !panel.isHidden // Alterna la visibilidad
                isInfoVisible.toggle()
            }
        }

        // Función para iniciar el refresco de la información en tiempo real
        func startRefreshingInfo() {
            // Detener cualquier timer existente
            refreshTimer?.invalidate()
            
            // Crear un nuevo Timer que actualice la información cada 1 segundo
            refreshTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateInfoPanel), userInfo: nil, repeats: true)
        }

        // Función que actualiza la información mostrada en el panel
    @objc func updateInfoPanel() {
        
        guard let arQuality = arQuality else {
            print("Error: arQuality es nil")
            return
        }
        
        // Obtener la información actualizada de arQuality
        let infoDebug = arQuality.getInfoParameters()
        
        guard let globalQuality = infoDebug["globalQuality"] as? Double else {
            print("Error: global quality es nil o no es un Double")
            return
        }
        
        let roundedQuality = (globalQuality * 100).rounded() / 100

        // Actualizar las etiquetas con los nuevos valores
        infoLabel1?.text = "HasToRefresh: \(hasToRefresh)"
        infoLabel2?.text = "GlobalQuality: \(roundedQuality)"
        infoLabel3?.text = "DynamicRefreshThreshold: \(infoDebug["DynamicRefreshThreshold"])"
        infoLabel4?.text = "ArConf: \(infoDebug["arConf"])"
        infoLabel5?.text = "SitumConf: \(infoDebug["situmConf"])"
            
            
            
        }

        // Detener el refresco cuando no sea necesario
        func stopRefreshingInfo() {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    
    
}
