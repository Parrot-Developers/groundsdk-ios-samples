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


 /// Sample code to display the active state of a camera, using `mainCamera` and `mainCamera2`
 /// peripherals (respectively Camera1 API and Camera2 API).
 ///
 /// When the camera is inactive, most features are unavailable, like taking pictures,
 /// video recording, zoom control. However, it is possible to configure camera parameters.
class ActiveStateViewController: UIViewController {

    /// Reference to the main camera.
    private var mainCameraRef: Ref<MainCamera>?
    /// Reference to the main camera 2.
    private var mainCamera2Ref: Ref<MainCamera2>?

    /// Active label.
    @IBOutlet weak var activeLabel: UILabel!

    /// Starts camera peripherals monitoring.
    ///
    /// - Parameter drone: drone to monitor
    func startMonitoring(drone: Drone) {
        // Drones: ANAFI_4K, ANAFI_THERMAL, ANAFI_USA
        // Monitor `MainCamera` peripheral, for drones supporting Camera1 API.
        // We keep camera reference as a class property, otherwise change notifications would stop.
        mainCameraRef = drone.getPeripheral(Peripherals.mainCamera) { [weak self] camera in
            // Checks if camera exists
            if let camera = camera {
                // Called when the camera changes, on main thread.
                self?.updateViewCamera1(camera: camera)
            }
        }
        // Drones: ANAFI_2
        // Monitor `camera2.MainCamera` peripheral, for drones supporting Camera2 API.
        // We keep camera reference as a class property, otherwise change notifications would stop.
        mainCamera2Ref = drone.getPeripheral(Peripherals.mainCamera2) { [weak self] camera in
            // Checks if camera exists
            if let camera = camera {
                // Called when the camera changes, on main thread.
                self?.updateViewCamera2(camera: camera)
            }
        }
    }

    /// Stops camera peripherals monitoring.
    func stopMonitoring() {
        // Release `MainCamera` peripheral reference.
        mainCameraRef = nil
        // Release `camera2.MainCamera` peripheral reference.
        mainCamera2Ref = nil

        // Reset active state view
        resetView()
    }

    /// Resets active state display.
    func resetView() {
        self.activeLabel.text = ""
    }

    /// Updates active state display with `mainCamera` peripheral (Camera1 API).
    ///
    /// - Parameter camera: camera peripheral
    func updateViewCamera1(camera: MainCamera) {
        // Display whether the camera is active.
        self.activeLabel.text = camera.isActive.description
    }

    /// Updates active state display with `mainCamera2` peripheral (Camera2 API).
    ///
    /// - Parameter camera: camera peripheral
    func updateViewCamera2(camera: MainCamera2) {
        // Display whether the camera is active.
        self.activeLabel.text = camera.isActive.description
    }
}
