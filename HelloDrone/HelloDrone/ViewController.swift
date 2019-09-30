// Copyright (C) 2019 Parrot Drones SAS
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

/// GroundSdk Hello Drone Sample
///
/// This activity allows the application to connect to a drone and/or a remote control.
/// It displays the connection state, battery level and video stream.
/// It allows to take off and land by button click.
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
    /// Reference to the current drone battery info instrument.
    private var droneBatteryInfoRef: Ref<BatteryInfo>?
    /// Reference to a current drone piloting interface.
    private var pilotingItfRef: Ref<ManualCopterPilotingItf>?
    /// Reference to the current drone stream server Peripheral.
    private var streamServerRef: Ref<StreamServer>?
    /// Reference to the current drone live stream.
    private var liveStreamRef: Ref<CameraLive>?

    // Remote control:
    /// Current remote control instance.
    private var remote: RemoteControl?
    /// Reference to the current remote control state.
    private var remoteStateRef: Ref<DeviceState>?
    /// Reference to the current remote control battery info instrument.
    private var remoteBatteryInfoRef: Ref<BatteryInfo>?

    // User Interface:
    /// Video stream view.
    @IBOutlet weak var streamView: StreamView!
    /// Drone state text view.
    @IBOutlet weak var droneStateTxt: UILabel!
    /// Drone battery level text view.
    @IBOutlet weak var droneBatteryTxt: UILabel!
    /// Remote state level text view.
    @IBOutlet weak var remoteStateTxt: UILabel!
    /// Remote battery level text view.
    @IBOutlet weak var remoteBatteryTxt: UILabel!
    /// Takeoff / land button.
    @IBOutlet weak var takeOffLandBt: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Reset user interface
        resetDroneUi()
        resetRemoteUi()

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

                // If the remote control has changed.
                if (self.remote?.uid != autoConnection.remoteControl?.uid) {
                    if (self.remote != nil) {
                        // Reset user interface Remote part.
                        self.resetRemoteUi()

                        // Stop to monitor the old remote.
                        self.stopRemoteMonitors()
                    }

                    // Monitor the new remote.
                    self.remote = autoConnection.remoteControl
                    if (self.remote != nil) {
                        self.startRemoteMonitors()
                    }
                }
            }
        }
    }

    /// Resets drone user interface part.
    private func resetDroneUi() {
        // Reset drone user interface views.
        droneStateTxt.text = DeviceState.ConnectionState.disconnected.description
        droneBatteryTxt.text = ""
        takeOffLandBt.isEnabled = false
        // Stop rendering the stream
        streamView.setStream(stream: nil)
    }

    /// Starts drone monitors.
    private func startDroneMonitors() {
        // Monitor drone state.
        monitorDroneState()

        // Monitor drone battery level.
        monitorDroneBatteryLevel()

        // Monitor piloting interface.
        monitorPilotingInterface()

        // Start video stream.
        startVideoStream()
    }

    /// Stops drone monitors.
    private func stopDroneMonitors() {
        // Forget references linked to the current drone to stop their monitoring.

        droneStateRef = nil
        droneBatteryInfoRef = nil
        pilotingItfRef = nil
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

    /// Monitors current drone battery level.
    private func monitorDroneBatteryLevel() {
        // Monitor the battery info instrument.
        droneBatteryInfoRef = drone?.getInstrument(Instruments.batteryInfo) { [weak self] batteryInfo in
            // Called when the battery info instrument is available and when it changes.

            if let self = self, let batteryInfo = batteryInfo {
                // Update drone battery level view.
                self.droneBatteryTxt.text = "\(batteryInfo.batteryLevel)%"
            }
        }
    }

    /// Monitors current drone piloting interface.
    private func monitorPilotingInterface() {
        // Monitor a piloting interface.
        pilotingItfRef = drone?.getPilotingItf(PilotingItfs.manualCopter) { [weak self] itf in
            // Called when the manual copter piloting Interface is available and when it changes.

            if let itf = itf {
                self?.managePilotingItfState(itf: itf)
            } else {
                // Disable the button if the piloting interface is not available.
                self?.takeOffLandBt.isEnabled = false
            }
        }
    }

    /// Manage piloting interface state
    ///
    /// - Parameter itf: the piloting interface
    private func managePilotingItfState(itf: ManualCopterPilotingItf) {
        switch itf.state {
        case ActivablePilotingItfState.unavailable:
            // Piloting interface is unavailable.
            takeOffLandBt.isEnabled = false

        case ActivablePilotingItfState.idle:
            // Piloting interface is idle.
            takeOffLandBt.isEnabled = false

            // Activate the interface.
            _ = itf.activate()

        case ActivablePilotingItfState.active:
            // Piloting interface is active.

            if itf.canTakeOff {
                // Drone can takeOff.
                takeOffLandBt.isEnabled = true
                takeOffLandBt.setTitle("TakeOff", for: .normal)
            } else if itf.canLand {
                // Drone can land.
                takeOffLandBt.isEnabled = true
                takeOffLandBt.setTitle("Land", for: .normal)
            } else {
                // Disable the button.
                takeOffLandBt.isEnabled = false
            }
        }
    }

    /// Called on takeOff/land button click.
    @IBAction func takeOffLandBtAction(_ sender: Any) {
        // Get the piloting interface from its reference.
        if let itf = pilotingItfRef?.value {
            // Do the action according to the interface capabilities
            if itf.canTakeOff {
                // Takeoff
                itf.takeOff()
            } else if itf.canLand {
                // Land
                itf.land()
            }
        }
    }

    /// Resets remote user interface part.
    private func resetRemoteUi() {
        // Reset remote control user interface views.
        remoteStateTxt.text = DeviceState.ConnectionState.disconnected.description
        remoteBatteryTxt.text = ""
    }

    /// Starts remote control monitors.
    private func startRemoteMonitors() {
        // Monitor remote state
        monitorRemoteState()

        // Monitor remote battery level
        monitorRemoteBatteryLevel()
    }

    /// Stops remote control monitors.
    private func stopRemoteMonitors() {
        // Forget all references linked to the current remote to stop their monitoring.

        remoteStateRef = nil
        remoteBatteryInfoRef = nil
    }

    /// Monitor current remote control state.
    private func monitorRemoteState() {
        // Monitor current drone state.
        remoteStateRef = remote?.getState { [weak self] state in
            // Called at each remote state update.

            if let self = self, let state = state {
                // Update remote state view.
                self.remoteStateTxt.text = state.connectionState.description
            }
        }
    }

    /// Monitors current remote control battery level.
    private func monitorRemoteBatteryLevel() {
        // Monitor the battery info instrument.
        remoteBatteryInfoRef = remote?.getInstrument(Instruments.batteryInfo) { [weak self] batteryInfo in
            // Called when the battery info instrument is available and when it changes.

            if let self = self, let batteryInfo = batteryInfo {
                // Update drone battery level view.
                self.remoteBatteryTxt.text = "\(batteryInfo.batteryLevel)%"
            }
        }
    }
}

