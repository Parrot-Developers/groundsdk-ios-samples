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

import UIKit

// Import GroundSdk library.
import GroundSdk

/// GroundSdk Thermal Video Stream Embedded Sample
///
/// This activity allows the application to connect to a drone.
/// It displays the connection state and the thermal video stream
/// with thermal blending embedded on the drone.
/// It allows to use different thermal palettes.
class ViewController: UIViewController {

    /// Ground SDk instance.
    private let groundSdk = GroundSdk()
    /// Reference to auto connection.
    private var autoConnectionRef: Ref<AutoConnection>?

    // Drone:
    /// Current drone instance.
    private var drone: Drone?
    /// Reference to the current drone state.
    private var droneStateRef: Ref<DeviceState>?
    /// Reference to the current drone stream server peripheral.
    private var streamServerRef: Ref<StreamServer>?
    /// Reference to the current drone live stream.
    private var liveStreamRef: Ref<CameraLive>?
    /// Reference to the current drone thermal control  peripheral.
    private var thermalCtrlRef: Ref<ThermalControl>?
    /// Reference to the current drone thermal camera peripheral.
    private var thermalCameraRef: Ref<BlendedThermalCamera>?
    /// `true` if the drone thermal render is initialized.
    private var droneThermalRenderInitialized = false

    // User Interface:
    /// Drone state text view.
    @IBOutlet weak var droneStateTxt: UILabel!
    /// Video thermal stream view.
    @IBOutlet weak var streamView: ThermalStreamView!
    /// Palettes Segment control.
    @IBOutlet weak var palettesSelection: UISegmentedControl!

    // Thermal Processing Part:
    /// Relative thermal palette.
    private var relativePalette : ThermalRelativePalette!
    /// Spot thermal palette.
    private var spotPalette : ThermalSpotPalette!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize local thermal palettes.
        initThermalPalettes()

        // Reset user interface.
        resetUi()

        // Monitor the auto connection facility.
        // Keep the reference to be notified on update.
        autoConnectionRef = groundSdk.getFacility(Facilities.autoConnection) { [weak self] autoConnection in
            // Called when the auto connection facility is available and when it changes.

            if let self = self, let autoConnection = autoConnection {
                // Start auto connection.
                if (autoConnection.state != AutoConnectionState.started) {
                    autoConnection.start()
                }

                // If the drone has changed.
                if (self.drone?.uid != autoConnection.drone?.uid) {
                    if (self.drone != nil) {
                        // Stop to monitor the old drone.
                        self.stopDroneMonitors()

                        // Reset user interface.
                        self.resetUi()
                    }

                    // Monitor the new drone.
                    self.drone = autoConnection.drone
                    if (self.drone != nil) {
                        self.startDroneMonitors()
                    }
                }
            }
        }
    }

    /// Initialize thermal palettes.
    private func initThermalPalettes() {
        // Initialize relative thermal palette
        initRelativeThermalPalette()

        // Initialize spot thermal palette
        initSpotThermalPalette()
    }

    /// Initialize relative thermal palette.
    private func initRelativeThermalPalette() {
        // Create a Relative thermal palette:
        //
        // Palette fully used.
        // The lowest color is associated to the coldest temperature of the scene and
        // the highest color is associated to the hottest temperature of the scene.
        // The temperature association can be locked.
        relativePalette = ThermalRelativePalette(
            // Colors list:
            //     - Blue as color of the lower palette boundary.
            //     - Red as color of the higher palette boundary.
            colors: [ThermalColor(0.0, 0.0, 1.0, 0.0), ThermalColor(1.0, 0.0, 0.0, 1.0)],

            // `locked: true` can be used to lock the association between colors and temperatures.
            // If relativePalette.isLocked is false, the association between colors and temperatures is update
            // at each render to match with the temperature range of the scene rendered.)
            locked: false,

            // Not used when the thermal is blending on drone.
            lowestTemp: 0.0,

            // Not used when the thermal is blending on drone.
            highestTemp: 0.0)
    }
    
    /// Initialize spot thermal palette.
    private func initSpotThermalPalette() {
        // Create a Spot thermal palette:
        //
        // Palette to highlight cold spots or hot spots.
        //
        // The palette is fully used:
        //     The lowest color is associated to the coldest temperature of the scene and
        //     the highest color is associated to the hottest temperature of the scene.
        // Only temperature hotter or colder than the threshold are shown.
        spotPalette = ThermalSpotPalette(
            // Colors list:
            //     - Green as color of the lower palette boundary.
            //     - Orange as color of the higher palette boundary.
            colors: [ThermalColor(0.0, 1.0, 0.0, 0.0), ThermalColor(1.0, 0.5, 0.0, 1.0)],
            
            // Highlight temperature higher than the threshold.
            type: .hot,
            // `type: .cold` to highlight temperature lower than the threshold.

            // Set the threshold at the 60% of the temperature range of the rendered scene.
            threshold: 0.6)
    }
    
    /// Resets  user interface part.
    private func resetUi() {
        // Reset drone user interface views.
        droneStateTxt.text = DeviceState.ConnectionState.disconnected.description

        // Stop rendering the stream
        streamView.setStream(stream: nil)

        // Reset thermal palette selection to relativePalette
        palettesSelection.selectedSegmentIndex = 0
        palettesSelection.sendActions(for: UIControl.Event.valueChanged)
    }

    /// Starts drone monitors.
    private func startDroneMonitors() {
        // Monitor drone state.
        monitorDroneState()

        // To switch from the main camera to the thermal camera:
        //    1) The video stream must be stopped.
        //    2) Set thermal control mode to embedded.
        //    3) Wait for the thermal camera to be active.
        //    4) Start the video stream.

        // Monitor stream server.
        monitorStreamServer()

        // Monitor thermal control peripheral.
        monitorThermalControl()

        // Monitor thermal camera.
        monitorThermalCamera()
    }

    /// Stops drone monitors.
    private func stopDroneMonitors() {
        // Forget references linked to the current drone to stop their monitoring.

        droneStateRef = nil
        streamServerRef = nil
        liveStreamRef = nil
        thermalCtrlRef = nil
        thermalCameraRef = nil

        // Reset drone render initialisation state
        droneThermalRenderInitialized = false
    }

    /// Monitors the stream server.
    private func monitorStreamServer() {
        // Prevent monitoring restart
        guard streamServerRef == nil else {
            return
        }

        // Monitor the stream server.
        streamServerRef = drone?.getPeripheral(Peripherals.streamServer) { [weak self] streamServer in
            // Called when the stream server is available and when it changes.

            if let self = self, let streamServer = streamServer {
                // Enable the stream server only if the thermal camera is active
                streamServer.enabled = self.thermalCameraRef?.value?.isActive ?? false

                // Monitor the live stream
                self.monitorLiveStream(streamServer: streamServer)
            }
        }
    }

    /// Monitors the live stream.
    ///
    /// - Parameter streamServer: the stream server.
    private func monitorLiveStream(streamServer: StreamServer) {
        // Prevent monitoring restart
        guard liveStreamRef == nil else {
            return
        }

        // Monitor the live stream.
        liveStreamRef = streamServer.live { liveStream in
            // Called when the live stream is available and when it changes.

            // Start to play the live stream only if the thermal camera is active.
            if let liveStream = liveStream, self.thermalCameraRef?.value?.isActive == true {
                self.startVideoStream(liveStream)
            }

            // Set the live stream as the stream to be render by the stream view.
            self.streamView.setStream(stream: liveStream)
        }
    }

    /// Monitors the thermal control peripheral.
    private func monitorThermalControl() {
        // Prevent monitoring restart
        guard thermalCameraRef == nil else {
            return
        }

        // Monitor the thermal control peripheral.
        thermalCtrlRef = drone?.getPeripheral(Peripherals.thermalControl) { [weak self] thermalCtrl in
            // Called when the thermal control peripheral is available and when it changes.

            // Active the thermal camera, if not yet done.
            if let thermalSetting = thermalCtrl?.setting, thermalSetting.mode != .blended {
                    thermalSetting.mode = .blended
            }

            // Send thermal render settings.
            if let self = self, let thermalCtrl = thermalCtrl{
                self.sendThermalRenderSettings(thermalCtrl: thermalCtrl)
            }
        }
    }

    /// Monitors the thermal camera.
    private func monitorThermalCamera() {
        // Prevent monitoring restart
        guard thermalCameraRef == nil else {
            return
        }

        // Monitor the thermal blended camera.
        thermalCameraRef = drone?.getPeripheral(Peripherals.blendedThermalCamera) { [weak self] thermalCamera in
            // Called when the thermal camera is available and when it changes.

            // Start the video stream if the thermal camera is active and the stream not playing.
            if let self = self, let liveStream = self.liveStreamRef?.value,
                    thermalCamera?.isActive == true {
                self.startVideoStream(liveStream)
            }
        }
    }

    /// Starts the video stream.
    ///
    /// - Parameter liveStream: the stream to start.
    private func startVideoStream(_ liveStream: CameraLive) {
        // Force the stream server enabling.
        streamServerRef?.value?.enabled = true

        // Set thermal camera model to use according to the drone model.
        self.streamView.thermalCamera = {
            switch drone?.model {
            case .anafiThermal:
                return ThermalProcThermalCamera.lepton
            case .anafiUa, .anafiUsa:
                return ThermalProcThermalCamera.boson
            default:
                return ThermalProcThermalCamera.lepton
            }
        } ()

        // Play the live stream.
        _ = liveStream.play()
    }

    /// Monitor current drone state.
    private func monitorDroneState() {
        // Prevent monitoring restart
        guard droneStateRef == nil else {
            return
        }

        // Monitor current drone state.
        droneStateRef = drone?.getState { [weak self] state in
            // Called at each drone state update.

            if let self = self, let state = state {
                // Update drone state view.
                self.droneStateTxt.text = state.connectionState.description

                // Send thermal render settings.
                if let thermalCtrl = self.thermalCtrlRef?.value{
                    self.sendThermalRenderSettings(thermalCtrl: thermalCtrl)
                }
            }
        }
    }

    /// Sends Thermal palette to the drone according to the selection.
    ///
    /// - Parameter thermalCtrl: thermal control.
    /// - Parameter id: selection palette button checked
    private func sendThermalPalette(thermalCtrl: ThermalControl) {
        // Send the new thermal palette according to the selection.
        switch palettesSelection.selectedSegmentIndex {
        case 0: // relative palette:
            thermalCtrl.sendPalette(relativePalette)
        case 1: // spot palette:
            thermalCtrl.sendPalette(spotPalette)
        default:
            thermalCtrl.sendPalette(relativePalette)
        }
    }

    /// Sends Thermal Render settings to the drone.
    ///
    /// - Parameter thermalCtrl: thermal control.
    private func sendThermalRenderSettings(thermalCtrl: ThermalControl) {
        // To optimize, do not send settings that have not changed.
        // Send thermal rendering and palette only if the drone is connected.
        guard droneThermalRenderInitialized == false && self.droneStateRef?.value?.connectionState == .connected else {
            return
        }

        // Set the rendering as blended at 50% between thermal image and visible image.
        thermalCtrl.sendRendering(rendering: ThermalRendering(mode: .blended, blendingRate: 0.5))
        // mode: `.visible` to render visible images only.
        // mode: `.thermal` to render thermal images only.
        // mode: `.monochrome` to render visible images in monochrome only.

        // Send thermal palette.
        sendThermalPalette(thermalCtrl: thermalCtrl)

        self.droneThermalRenderInitialized = true
    }
    
    /// Called when palette selection changed.
    @IBAction func paletteSelectionChanged(_ sender: Any) {
        // Send the new thermal palette according to the selection.
        if let thermalCtrl = thermalCtrlRef?.value {
            sendThermalPalette(thermalCtrl: thermalCtrl)
        }
    }
}

