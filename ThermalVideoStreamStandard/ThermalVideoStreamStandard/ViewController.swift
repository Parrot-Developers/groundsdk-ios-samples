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

/// GroundSdk Thermal Video Stream Standard Sample.
///
/// This activity allows the application to connect to a drone.
/// It displays the connection state, thermal video stream and temperature info with thermal blending
/// `standard` make by the application.
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
    private var thermalCameraRef: Ref<ThermalCamera>?
    /// `true` if the drone thermal render is initialized.
    private var droneThermalRenderInitialized = false

    // User Interface:
    /// Drone state text view.
    @IBOutlet weak var droneStateTxt: UILabel!
    /// Video thermal stream view.
    @IBOutlet weak var streamView: ThermalStreamView!
    /// Text view to display the current lowest temperature rendered.
    @IBOutlet weak var lowTmpTxt: UILabel!
    /// Text view to display the current highest temperature rendered.
    @IBOutlet weak var hightTmpTxt: UILabel!
    /// Text view to display the current  temperature rendered at the thermal probe location.
    @IBOutlet weak var probeTmpTxt: UILabel!
    /// Text view to display the current  thermal probe location X.
    @IBOutlet weak var probeXTxt: UILabel!
    /// Text view to display the current  thermal probe location Y.
    @IBOutlet weak var probeYTxt: UILabel!
    /// Palettes Segment control.
    @IBOutlet weak var palettesSelection: UISegmentedControl!

    // Local Thermal Processing Part:
    /// Thermal video processing.
    private var tproc = ThermalProcVideo()
    /// Relative thermal palette.
    private var relativePalette : ThermalProcRelativePalette!
    /// Absolute thermal palette.
    private var absolutePalette : ThermalProcAbsolutePalette!
    /// Spot thermal palette.
    private var spotPalette : ThermalProcSpotPalette!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize local thermal palettes.
        initThermalPalettes()

        // Initialize local thermal processing.
        initThermalProc()

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

        // Initialize absolute thermal palette
        initAbsoluteThermalPalette()

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
        relativePalette = ThermalProcPaletteFactory.createRelativePalette(
            // Colors list:
            //     - Blue as color of the lower palette boundary.
            //     - Red as color of the higher palette boundary.
            [ThermalProcColor.init(red: Float(0.0), green: Float(0.0), blue: Float(1.0), position: Float(0.0)),
             ThermalProcColor.init(red: Float(1.0), green: Float(0.0), blue: Float(0.0), position: Float(1.0))],
            boundariesUpdate: {
                // Called when the temperatures associated to the palette boundaries change.

                print("Blue is associated to \(self.relativePalette.lowestTemperature) kelvin.")
                print("Red is associated to \(self.relativePalette.highestTemperature) kelvin.")
        })

        //`relativePalette.isLocked = true` can be used to lock the association between colors and temperatures.
        // If relativePalette.isLocked is false, the association between colors and temperatures is update
        // at each render to match with the temperature range of the scene rendered.
    }

    /// Initialize absolute thermal palette.
    private func initAbsoluteThermalPalette() {
        // Create a Absolute thermal palette:
        //
        // Palette used between temperature range set.
        // The palette can be limited or extended for out of range temperatures.
        absolutePalette = ThermalProcPaletteFactory.createAbsolutePalette(
            // Colors list:
            //     - Brown as color of the lower palette boundary.
            //     - Purple as the middle color of the palette.
            //     - Yellow as color of the higher palette boundary.
            [ThermalProcColor.init(red: Float(0.34), green: Float(0.16), blue: Float(0.0), position: Float(0.0)),
             ThermalProcColor.init(red: Float(0.40), green: Float(0.0), blue: Float(0.60), position: Float(0.5)),
             ThermalProcColor.init(red: Float(1.0), green: Float(1.0), blue: Float(0.0), position: Float(1.0))]
        )

        // Set a range between 300.0 Kelvin and 310.0 Kelvin.
        // Brown will be associated with 300.0 Kelvin.
        // Yellow will be associated with 310.0 Kelvin.
        // Purple will be associated with the middle range therefore 305.0 Kelvin.
        absolutePalette.lowestTemperature = 300.0
        absolutePalette.highestTemperature = 310.0

        // Limit the palette, to render in black color temperatures out of range.
        absolutePalette.isLimited = true
        // If the palette is not limited:
        //    - temperatures lower than `lowestTemperature` are render with the lower palette boundary color.
        //    - temperatures higher than `highestTemperature` are render with the higher palette boundary color.
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
        spotPalette = ThermalProcPaletteFactory.createSpotPalette(
            // Colors list:
            //     - Green as color of the lower palette boundary.
            //     - Orange as color of the higher palette boundary.
            [ThermalProcColor.init(red: Float(0.0), green: Float(1.0), blue: Float(0.0), position: Float(0.0)),
             ThermalProcColor.init(red: Float(1.0), green: Float(0.5), blue: Float(0.0), position: Float(1.0))],
             boundariesUpdate: {
                // Called when the temperatures associated to the palette boundaries change.

                print("Green is associated to \(self.spotPalette.lowestTemperature) kelvin.")
                print("Orange is associated to \(self.spotPalette.highestTemperature) kelvin.")
        })

        // Highlight temperature higher than the threshold.
        spotPalette.temperatureType = .hot
        // `spotPalette.temperatureType = .cold` to highlight temperature lower than the threshold.

        // Set the threshold at the 60% of the temperature range of the rendered scene.
        spotPalette.threshold = 0.6
    }

    /// Initialize local thermal processing.
    private func initThermalProc() {
        // Set the rendering as blended at 50% between thermal image and visible image.
        tproc.renderingMode = .blended
        tproc.blendingRate = 0.5
        // `tproc.renderingMode = .visible` to render visible images only.
        // `tproc.renderingMode = .thermal` to render thermal images only.
        // `tproc.renderingMode = .monochrome` to render visible images in monochrome only.

        // Set the thermal probe position at the center of the render.
        //
        // The Origin point [0;0] is at the render top left and the point [1;1] is at the at render bottom right.
        tproc.probePosition.x = 0.5
        tproc.probePosition.y = 0.5

        // Use the relative palette
        tproc.palette = relativePalette

        // Set the thermal processing instance to use to the thermal stream view.
        streamView.thermalProc = tproc
        // Set the block to call for each render status.
        streamView.renderStatusBlock = { [weak self]
                (lowest: ThermalProcSpot?, hightest: ThermalProcSpot?, probe: ThermalProcSpot?) -> Void in
            // Called for each thermal processing status.

            // Update user interface according to thermal processing status.
            if let lowest = lowest {
                self?.lowTmpTxt.text = Int(lowest.temperature).description
            }

            if let hightest = hightest {
                self?.hightTmpTxt.text = Int(hightest.temperature).description
            }

            if let probe = probe {
                self?.probeTmpTxt.text = Int(probe.temperature).description
                self?.probeXTxt.text = String(format: "%.2f", probe.position.x)
                self?.probeYTxt.text = String(format: "%.2f", probe.position.y)
            }
        }
    }

    /// Resets  user interface part.
    private func resetUi() {
        // Reset drone user interface views.
        droneStateTxt.text = DeviceState.ConnectionState.disconnected.description

        // Stop rendering the stream
        streamView.setStream(stream: nil)

        // Reset thermal user interface views.
        lowTmpTxt.text = ""
        hightTmpTxt.text = ""
        probeTmpTxt.text = ""
        probeXTxt.text = ""
        probeYTxt.text = ""
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
        //    2) Set thermal control mode to standard.
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
            if let thermalSetting = thermalCtrl?.setting, thermalSetting.mode != .standard {
                    thermalSetting.mode = .standard
            }

            // Warning: 'ThermalProc' and 'ThermalStreamView' should not be used in 'blended' mode,
            // In blended mode the stream should be displayed directly by a 'StreamView'.

            // In order to the drone video recording look like the local render,
            // send a thermal render settings.
            if let self = self, let thermalCtrl = thermalCtrl {
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

        // Monitor the thermal camera.
        thermalCameraRef = drone?.getPeripheral(Peripherals.thermalCamera) { [weak self] thermalCamera in
            // Called when the thermal camera is available and when it changes.

            // Start the video stream if the thermal camera is active.
            if let self = self, let liveStream = self.liveStreamRef?.value, thermalCamera?.isActive == true {
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

    /// Called when palette selection changed.
    @IBAction func paletteSelectionChanged(_ sender: Any) {
        // Use thermal palette according to the selection.
        switch palettesSelection.selectedSegmentIndex {
        case 0: // relative palette:
            tproc.palette = relativePalette
        case 1: // absolute palette:
            tproc.palette = absolutePalette
        case 2: // spot palette:
            tproc.palette = spotPalette
        default:
            tproc.palette = relativePalette
        }

        // Send the new thermal settings to use in the drone recording video.
        if let thermalCtrl = thermalCtrlRef?.value {
            sendThermalRenderSettings(thermalCtrl: thermalCtrl)
        }
    }

    // Thermal processing is local only.
    // If you want that the thermal video recorded on the drone look like the local render,
    // you should send thermal rendering settings to the drone.

    /// Sends Thermal Render settings to the drone.
    ///
    /// - Parameter thermalCtrl: thermal control
    private func sendThermalRenderSettings(thermalCtrl: ThermalControl) {
        // To optimize, do not send settings that have not changed.
        // Send thermal rendering and palette only if the drone is connected.
        guard droneThermalRenderInitialized == false && self.droneStateRef?.value?.connectionState == .connected else {
            return
        }

        // Send rendering mode.
        thermalCtrl.sendRendering(rendering: thermalRenderingModeGsdk())

        // Send emissivity .
        thermalCtrl.sendEmissivity(tproc.emissivity)

        // Send Background Temperature.
        thermalCtrl.sendBackgroundTemperature(tproc.backgroundTemp)

        // Send thermal palette.
        if let gsdkThermalPalette = thermalPaletteGsdk() {
            thermalCtrl.sendPalette(gsdkThermalPalette)
        }

        self.droneThermalRenderInitialized = true
    }

    /// Retrieves GroundSdk palette to send to the drone according to the current thermal processing palette.
    ///
    /// - Returns: GroundSdk palette  according to the current thermal processing palette.
    private func thermalPaletteGsdk() -> ThermalPalette? {
        // Convert thermal processing colors to GroundSdk thermal colors.
        var gsdkColors : [ThermalColor] = []
        for color in tproc.palette.colors as! [ThermalProcColor] {
            gsdkColors.append(ThermalColor(Double(color.red), Double(color.green), Double(color.blue), Double(color.position)))
        }

        // Convert thermal processing palette to GroundSdk thermal palette.
        var gsdkPalette: ThermalPalette?
        if let relativePalette = tproc.palette as? ThermalProcRelativePalette {
            gsdkPalette = ThermalRelativePalette(colors: gsdkColors, locked: relativePalette.isLocked,
                                                lowestTemp: relativePalette.lowestTemperature,
                                                highestTemp: relativePalette.highestTemperature)
        } else if let absolutePalette = tproc.palette as? ThermalProcAbsolutePalette {
            gsdkPalette = ThermalAbsolutePalette(colors: gsdkColors,
                                                lowestTemp: absolutePalette.lowestTemperature,
                                                highestTemp: absolutePalette.highestTemperature,
                                                outsideColorization: absolutePalette.isLimited ? .limited : .extended)
        } else if let spotPalette = tproc.palette as? ThermalProcSpotPalette {
            gsdkPalette = ThermalSpotPalette(colors: gsdkColors,
                                            type: spotPalette.temperatureType == .hot ? .hot: .cold,
                                            threshold: spotPalette.threshold)
        }

        return gsdkPalette
    }

    /// Retrieves GroundSdk rendering mode to send to the drone according to the current thermal processing.
    ///
    /// - Returns: GroundSdk rendering mode according to the current thermal processing.
    private func thermalRenderingModeGsdk() -> ThermalRendering {
        let renderingMode: ThermalRenderingMode
        // Send rendering mode.
        switch (tproc.renderingMode) {
        case .visible:
            renderingMode = .visible
        case .thermal:
            renderingMode = .thermal
        case .blended:
            renderingMode = .blended
        case .monochrome:
            renderingMode = .monochrome
        default:
            renderingMode = .blended
        }

        return ThermalRendering.init(mode: renderingMode, blendingRate: tproc.blendingRate)
    }
}


