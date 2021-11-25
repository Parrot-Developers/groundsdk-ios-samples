// Copyright (C) 2021 Parrot Drones SAS
//
//    Redistribution and use in source and binary forms, with or without
//    modification, are permitted provided that the following conditions
//    are met:
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in
//      the documentation and/or other materials provided with the
//      distribution.
//    * Neither the name of the Parrot Company nor the names
//      of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written
//      permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//    PARROT COMPANY BE LIABLE FOR ANY DIRECT, INDIRECT,
//    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
//    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

import Foundation
import UIKit
// import GroundSdk library.
import GroundSdk

/// Protocol for white balance
protocol WhiteBalanceDelegate: class {
    func hideWhiteBalance()
}

/// Sample code to display and change custom white balance temperature, using `mainCamera` and
/// `mainCamera2` peripherals (respectively Camera1 API and Camera2 API).
class WhiteBalanceController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    /// Reference to the main camera.
    private var mainCameraRef: Ref<MainCamera>?
    /// Reference to the main camera 2.
    private var mainCamera2Ref: Ref<MainCamera2>?

    /// White balance picker data source.
    private var dataSource = [CustomStringConvertible]()
    /// White balance picker view
    @IBOutlet weak var whiteBalancePicker: UIPickerView!
    /// Dismiss white balance picker button.
    @IBOutlet weak var dismissPickerButton: UIButton!
    /// White balance temperature  button.
    public var whiteBalanceValueButton: UIButton?
    /// White balance delegate.
    weak var delegate: WhiteBalanceDelegate?

    /// View did load
    override func viewDidLoad() {
        super.viewDidLoad()
        whiteBalancePicker.delegate = self
        dismissPickerButton.layer.cornerRadius = 15
        dismissPickerButton.layer.borderWidth = 1
        dismissPickerButton.layer.borderColor = UIColor.white.cgColor
    }

     /// Starts camera peripherals monitoring.
     ///
     /// - Parameter drone: drone to monitor
    func startMonitoring(drone: Drone) {
        // Drones: ANAFI_4K, ANAFI_THERMAL, ANAFI_USA
        // Monitor `mainCamera` peripheral, for drones supporting Camera1 API.
        // We keep camera reference as a class property, otherwise change notifications would stop.
        mainCameraRef = drone.getPeripheral(Peripherals.mainCamera) { [weak self] camera in
            // Called when the camera changes, on main thread.
            if let camera = camera {
                self?.updateWhiteBalanceCamera1(camera: camera)
            }
        }
        // Drones: ANAFI_2
        // Monitor `mainCamera2` peripheral, for drones supporting Camera2 API.
        // We keep camera reference as a class property, otherwise change notifications would stop.
        mainCamera2Ref = drone.getPeripheral(Peripherals.mainCamera2) { [weak self] camera in
            // Called when the camera changes, on main thread.
            if let camera = camera {
                self?.updateWhiteBalanceCamera2(camera: camera)
            }
        }
    }

    /// Stops camera peripherals monitoring.
    func stopMonitoring() {
        // Release `mainCamera` peripheral reference.
        mainCameraRef = nil
        // Release `mainCamera2` peripheral reference.
        mainCamera2Ref = nil

        resetView()
    }

    /// Resets display.
    func resetView() {
        // Hide white balance picker view.
        delegate?.hideWhiteBalance()
    }

    /// Updates custom white balance temperature display with `mainCamera` peripheral (Camera1 API)
    ///
    /// - Parameter camera: camera peripheral
    func updateWhiteBalanceCamera1(camera: MainCamera) {
        // Get the set of supported white balance temperatures
        let supportedCustomTemperatures = camera.whiteBalanceSettings.supporteCustomTemperature
        dataSource = [CameraWhiteBalanceTemperature](supportedCustomTemperatures.sorted{ $0.rawValue < $1.rawValue })
        // Fill picker data source with supported custom temperature.
        whiteBalancePicker.dataSource = dataSource as? UIPickerViewDataSource
        // Set the current custom white balance temperature.
        whiteBalanceValueButton?.setTitle(camera.whiteBalanceSettings.customTemperature.description,
                                        for: .normal)
    }

     /// Updates custom white balance temperature display with `camera2.MainCamera` peripheral (Camera2 API).
     ///
     /// - Parameter camera: camera peripheral
    func updateWhiteBalanceCamera2(camera: MainCamera2) {
        // Set the current custom white balance temperature.
        if let customTemperature = camera.config[Camera2Params.whiteBalanceTemperature]?.value {
            whiteBalanceValueButton?.setTitle(customTemperature.description,
                                         for: .normal)
        }
        if let supportedCustomTemperatures = camera.config[Camera2Params.whiteBalanceTemperature]?.overallSupportedValues {
            let data = supportedCustomTemperatures.sorted(by: { $0.rawValue < $1.rawValue })
            // Get the set of supported white balance temperatures
            self.dataSource = [Camera2WhiteBalanceTemperature](data)
            // Fill picker data source with supported custom temperature.
            self.whiteBalancePicker.dataSource = self.dataSource as? UIPickerViewDataSource
        }
    }

    /// Value changed for segmented control mode.
    @IBAction func dismissPicker(_ sender: Any) {
        whiteBalancePicker.isHidden = true
        dismissPickerButton.isHidden = true
    }

    /// PickerView: number of components
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
       return 1
    }

    /// PickerView: number of rows
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return dataSource.count
    }

    /// PickerView: title for row
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        // Get `mainCamera` peripheral from its reference, if available.
        if let camera = mainCameraRef?.value {
            // Checks if white balance temperature row corresponds to current white balance temperature
            if dataSource[row].description == camera.whiteBalanceSettings.customTemperature.description {
                // Sets selected white balance temperature on picker
                whiteBalancePicker.selectRow(row, inComponent: component, animated: false)
            }
        }
        // Otherwise, get `mainCamera2` peripheral from its reference, if available.
        if let camera = mainCamera2Ref?.value {
            // Checks if white balance temperature row corresponds to current white balance temperature
            if dataSource[row].description ==
                camera.config[Camera2Params.whiteBalanceTemperature]?
                      .currentSupportedValues.description {
                // Sets selected white balance temperature on picker
                whiteBalancePicker.selectRow(row, inComponent: component, animated: false)
            }
        }
        // Set temperature for row
        return dataSource[row].description
    }

    /// PickerView: did select row
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // Get `mainCamera` peripheral from its reference, if available.
        if let camera = mainCameraRef?.value {
            // Get white balance temperature selected by user.
            let temperature = dataSource[row] as? CameraWhiteBalanceTemperature
            // Set white balance temperature.
            setWhiteBalanceTemperatureCamera1(camera: camera, temperature: temperature!)
        }
        // Otherwise, get `mainCamera2` peripheral from its reference, if available.
        if let camera = mainCamera2Ref?.value {
            // Get white balance temperature selected by user.
            let temperature = dataSource[row] as? Camera2WhiteBalanceTemperature
            // Set white balance temperature.
            setWhiteBalanceTemperatureCamera2(camera: camera, temperature: temperature!)
        }
        // hide white balance container view.
        delegate?.hideWhiteBalance()
    }

     /// Sets custom white balance temperature with `mainCamera` peripheral (Camera1 API).
     ///
     /// - Parameters:
     ///    - camera: camera peripheral
     ///    - temperature: new custom white balance temperature
    func setWhiteBalanceTemperatureCamera1(camera: MainCamera, temperature: CameraWhiteBalanceTemperature) {
        // Set mode to `custom`, to allow definition of a custom temperature.
        camera.whiteBalanceSettings.mode = .custom
        // Get white balance setting and set the custom temperature.
        // This will send immediately this value to the drone, if connected.
        camera.whiteBalanceSettings.customTemperature = temperature
    }

    /// Sets custom white balance temperature with `mainCamera2` peripheral (Camera2 API).
    ///
    /// - Parameters:
    ///     - camera: camera peripheral
    ///     - temperature: new custom white balance temperature
    func setWhiteBalanceTemperatureCamera2(camera: MainCamera2, temperature: Camera2WhiteBalanceTemperature) {
        let editor = camera.config.edit(fromScratch: false)
        // To change custom white balance temperature with `camera2.mainCamera` peripheral,
        // we use the configuration editor.
        // Create a configuration editor, starting from current configuration.
        editor[Camera2Params.whiteBalanceMode]?.value = .custom
        // Set white balance mode to `custom`, to allow definition of a custom temperature.
        // And set the custom white balance temperature.
        // Note: In case of conflicts with other parameters, the editor may automatically unset the
        // other conflicting parameters, so that the configuration remains consistent.
        editor[Camera2Params.whiteBalanceTemperature]?.value = temperature
        // Automatically complete the edited configuration, to ensure that all parameters are set.
        editor.autoComplete()
        // Apply and send the new configuration to the drone, if the drone is connected.
        _ = editor.commit()
    }
}

