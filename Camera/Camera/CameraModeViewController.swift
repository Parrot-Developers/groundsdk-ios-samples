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


/// Sample code to display and change camera mode, using `mainCamera` and `mainCamera2`
/// peripherals (respectively Camera1 API and Camera2 API).
///
/// Camera mode indicates if the camera is configured either to take photos or to record videos.
class CameraModeViewController: UIViewController {

    /// Reference to the main camera.
    private var mainCameraRef: Ref<MainCamera>?
    /// Reference to the main camera 2.
    private var mainCamera2Ref: Ref<MainCamera2>?

    /// Photo / recording button.
    public var photoRecordingButton: UIButton?
    /// Camera Mode segmented control.
    @IBOutlet weak var segmentedMode: UISegmentedControl!

    /// Display texts for photo / recording button.
    private let startRecordText = "Start recording"
    private let stopRecordText = "Stop recording"
    private let startPhotoCaptureText = "Start photo capture"
    private let stopPhotoCaptureText = "Stop photo capture"


     /// Starts camera peripherals monitoring.
     ///
     /// - Parameter drone: drone to monitor
    func startMonitoring(drone: Drone) {
        // Drones: ANAFI_4K, ANAFI_THERMAL, ANAFI_USA
        // Monitor `mainCamera` peripheral, for drones supporting Camera1 API.
        // We keep camera reference as a class property, otherwise change notifications would stop.
        mainCameraRef = drone.getPeripheral(Peripherals.mainCamera) { [weak self] camera in
            if let camera = camera {
                // Called when the camera changes, on main thread.
                self?.updateViewCamera1(camera: camera)
            }
        }
        // Drones: ANAFI_2
        // Monitor `mainCamera2` peripheral, for drones supporting Camera2 API.
        // We keep camera reference as a class property, otherwise change notifications would stop.
        mainCamera2Ref = drone.getPeripheral(Peripherals.mainCamera2) { [weak self] camera in
            if let camera = camera {
                // Called when the camera changes, on main thread.
                self?.updateViewCamera2(camera: camera)
            }
        }
    }

    // Stops camera peripherals monitoring.
    func stopMonitoring() {
        // Release `mainCamera` peripheral reference.
        mainCameraRef = nil
        // Release `mainCamera2` peripheral reference.
        mainCamera2Ref = nil

        resetView()
    }

    /// Resets display.
    func resetView() {
        photoRecordingButton?.isEnabled = false
        segmentedMode.isEnabled = false
    }

    /// Updates camera mode display with `mainCamera` peripheral (Camera1 API).
    ///
    /// - Parameter camera: camera peripheral
    func updateViewCamera1(camera: MainCamera) {
        // Enable camera mode buttons if mode is not currently changing.
        photoRecordingButton?.isEnabled = !camera.modeSetting.updating
        segmentedMode.isEnabled = !camera.modeSetting.updating
        if let photoRecordingButton = photoRecordingButton {

            // Update photo/recording mode radio button based on current camera mode setting.
            self.segmentedMode.selectedSegmentIndex = camera.modeSetting.mode == .recording ? 1 : 0
            // Enable capture button only if camera is active.
            photoRecordingButton.isEnabled = camera.isActive
            // update title of photoRecordingButton depending on photo or video state.
            if camera.isActive {
                if camera.canStartPhotoCapture {
                    photoRecordingButton.setTitle(self.startPhotoCaptureText, for: .normal)
                } else if camera.canStopPhotoCapture {
                    photoRecordingButton.setTitle(self.stopPhotoCaptureText, for: .normal)
                } else if camera.canStartRecord {
                    photoRecordingButton.setTitle(self.startRecordText, for: .normal)
                } else if camera.canStopRecord {
                    photoRecordingButton.setTitle(self.stopRecordText, for: .normal)
                }
            }
        }
    }

    /// Updates camera mode display with `mainCamera2` peripheral (Camera1 API).
    ///
    /// - Parameter camera: camera peripheral
    func updateViewCamera2(camera: MainCamera2) {
        photoRecordingButton?.isEnabled = !camera.config.updating
        segmentedMode.isEnabled = !camera.config.updating

        /// Update active label  to know if camera is active or not
        if let photoRecordingButton = photoRecordingButton {
            if let mode = camera.config[Camera2Params.mode]?.value {
                self.segmentedMode.selectedSegmentIndex = mode == .recording ? 1 : 0
            }

            // update title of photoRecording button depending on recording state.
            if let recording = camera.getComponent(Camera2Components.recording) {
                if recording.state.canStart {
                    photoRecordingButton.setTitle(self.startRecordText, for: .normal)
                } else if recording.state.canStop {
                    photoRecordingButton.setTitle(self.stopRecordText, for: .normal)
                }
            }

            // update title of photoRecording button depending on photoCapture state.
            if let photoCapture = camera.getComponent(Camera2Components.photoCapture) {
                if photoCapture.state.canStart {
                    photoRecordingButton.setTitle(self.startPhotoCaptureText, for: .normal)
                } else if photoCapture.state.canStop {
                    photoRecordingButton.setTitle(self.stopPhotoCaptureText, for: .normal)
                }
            }
        }
    }

    /// Called when segmented mode value changed.
    @IBAction func segmentedModeChanged(_ sender: Any) {
        // Get `mainCamera` peripheral from its reference, if available.
        if let camera = mainCameraRef?.value {
            setModeCamera1(camera: camera, mode: segmentedMode.selectedSegmentIndex == 0 ? .photo : .recording)
        }
        // Get `mainCamera2` peripheral from its reference, if available.
        if let camera = mainCamera2Ref?.value {
            setModeCamera2(camera: camera, mode: segmentedMode.selectedSegmentIndex == 0 ? .photo : .recording)
        }
    }

    /// Sets camera mode with `mainCamera` peripheral (Camera1 API).
    ///
    /// - Parameters:
    ///    - camera: camera peripheral
    ///    - mode: new camera mode
    func setModeCamera1(camera: MainCamera, mode: CameraMode) {
        // To change camera mode with `MainCamera` peripheral, we first get the `mode` setting.
        // Then we set the new setting value.
        // If the drone is connected, this will immediately send this new setting value to the
        // drone.
        camera.modeSetting.mode = mode
    }

     /// Sets camera mode with `mainCamera2` peripheral (Camera2 API).
     ///
     /// - Parameters:
     ///    - camera: camera peripheral
     ///    - mode: new camera mode
    func setModeCamera2(camera: MainCamera2, mode: Camera2Mode) {
        // To change camera mode with `camera2.MainCamera` peripheral, we use the configuration editor.
        // Create a configuration editor, starting from current configuration.
        let editor = camera.config.edit(fromScratch: false)
        if let configParam = editor[Camera2Params.mode] {
            // Set the value of the camera mode parameter.
            // Note: In case of conflicts with other parameters, the editor may automatically unset the
            // other conflicting parameters, so that the configuration remains consistent.
            configParam.value = mode
            // Automatically complete the edited configuration, to ensure that all parameters are set.
            _ = editor.autoComplete()
            // Apply and send the new configuration to the drone, if the drone is connected.
            _ = editor.commit()
        }
    }

    /// Called when start / stop photo / recording button is pressed
    func startStop() {
        // Get `mainCamera` peripheral from its reference, if available.
        if let camera = mainCameraRef?.value {
            if camera.canStartRecord == true {
                // If can start recording is available, called startRecording
                camera.startRecording()
            } else if camera.canStopRecord == true {
                // If can stop recording is available, called stopRecording
                camera.stopRecording()
            } else if camera.canStartPhotoCapture == true {
                // If can start recording is available, called startPhotoCapture
                camera.startPhotoCapture()
            } else if camera.canStopPhotoCapture == true {
                // If can stop recording is available, called stopPhotoCapture
                camera.stopPhotoCapture()
            }
        }
        // Get `mainCamera2` peripheral from its reference, if available.
        if let camera = mainCamera2Ref?.value {
            // Get recording component.
            if let recording = camera.getComponent(Camera2Components.recording) {
                // If can stop is available, called stop
                if recording.state.canStop {
                    recording.stop()
                }
                // If can start is available, called start
                if recording.state.canStart {
                    recording.start()
                }
            }
            // Get photoCapture component.
            if let photoCapture = camera.getComponent(Camera2Components.photoCapture) {
                // If can stop is available, called stop
                if photoCapture.state.canStop {
                    photoCapture.stop()
                }
                // If can start is available, called start
                if photoCapture.state.canStart {
                    photoCapture.start()
                }
            }
        }
    }
}
