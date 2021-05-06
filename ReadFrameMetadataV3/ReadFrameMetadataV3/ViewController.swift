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

// import GroundSdk library.
import GroundSdk

/// GroundSdk Read Frame metadataV3 Sample.
///
/// This view controller allows the application to connect to a drone.
/// It displays the connection state, the video stream and
/// reads the drone quaternion from frame metadataV3 received from the overlayer.
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
    /// Reference to the current drone stream server Peripheral.
    private var streamServerRef: Ref<StreamServer>?
    /// Reference to the current drone live stream.
    private var liveStreamRef: Ref<CameraLive>?

    // User Interface:
    /// Video stream view.
    @IBOutlet weak var streamView: StreamView!
    /// Drone state text view.
    @IBOutlet weak var droneStateTxt: UILabel!
    /// Drone quaternion text view.
    @IBOutlet weak var droneQuatTxt: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set stream view overlayer.
        streamView.overlayer2 = self

        // Reset user interface
        resetDroneUi()

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

                        // Reset user interface drone part.
                        self.resetDroneUi()
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

    /// Resets drone user interface part.
    private func resetDroneUi() {
        // Reset drone user interface views.
        droneStateTxt.text = DeviceState.ConnectionState.disconnected.description
        self.droneQuatTxt.text = ""
        // Stop rendering the stream
        streamView.setStream(stream: nil)
    }

    /// Starts drone monitors.
    private func startDroneMonitors() {
        // Monitor drone state.
        monitorDroneState()

        // Start video stream.
        startVideoStream()
    }

    /// Stops drone monitors.
    private func stopDroneMonitors() {
        // Forget references linked to the current drone to stop their monitoring.

        droneStateRef = nil
        liveStreamRef = nil
        streamServerRef = nil
    }

    /// Starts the video stream.
    private func startVideoStream() {
        // Monitor the stream server.
        streamServerRef = drone?.getPeripheral(Peripherals.streamServer) { [weak self] streamServer in
            // Called when the stream server is available and when it changes.

            if let self = self, let streamServer = streamServer {
                // Enable Streaming
                streamServer.enabled = true
                self.liveStreamRef = streamServer.live { liveStream in
                    // Called when the live stream is available and when it changes.

                    if let liveStream = liveStream {
                        // Set the live stream as the stream to be render by the stream view.
                        self.streamView.setStream(stream: liveStream)
                        // Play the live stream.
                        _ = liveStream.play()
                    }
                }
            }
        }
    }

    /// Monitor current drone state.
    private func monitorDroneState() {
        // Monitor current drone state.
        droneStateRef = drone?.getState { [weak self] state in
            // Called at each drone state update.

            if let self = self, let state = state {
                // Update drone state view.
                self.droneStateTxt.text = state.connectionState.description
            }
        }
    }
}

// Overlayer extention
extension ViewController: Overlayer2 {
    func overlay(overlayContext: OverlayContext) {
        // Called at each frame rendering.

        // Read drone quaternion from metadata native pointer.
        let quat = FrameMetadataReader.readFrameMetadataDroneQuat(
            overlayContext.frameMetadataHandle) as! [Float]

        // Display quaternion values.
        DispatchQueue.main.async {
            self.droneQuatTxt.text = String(format: "x: %.2f y: %.2f z: %.2f w: %.2f",
                                            quat[0], quat[1], quat[2], quat[3])
        }
    }
}
