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

/// GroundSdk Thermal Video Local Sample.
///
/// This view controller allows to display a thermal video local and temperature info.
/// It allows to use different thermal palettes.
class ViewController: UIViewController {

    /// Ground SDk instance.
    private let groundSdk = GroundSdk()

    /// Reference to the video replay.
    private var replayRef: Ref<FileReplay>?
    /// Timer to restart video.
    private var timer: Timer?

    // User Interface:
    /// Video thermal  view.
    @IBOutlet weak var videoView: ThermalStreamView!
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
    }

    override func viewDidAppear(_ animated: Bool) {
        let videoURL = Bundle.main.url(forResource: "thermal_video", withExtension: "MP4")
        if let videoURL = videoURL {
            // To allow to change the thermal blending at runtime,
            // use the unblended track of the thermal video as source.
            let source = FileReplayFactory.videoTrackOf(file: videoURL, track: MediaItem.Track.thermalUnblended)
            // Monitor the video replay.
            replayRef = groundSdk.replay(source: source) { [weak self] replay in
                // Called when the replay is available and when it changes.

                if let self = self {
                    // Set the replay as stream to render by the video view.
                    self.videoView.setStream(stream: replay)

                    if let replay = replay, self.timer == nil {
                        // Start a timer to restart video.
                        self.timer = Timer.scheduledTimer(withTimeInterval: replay.duration,
                                                          repeats: true) { [weak self] _ in
                            if let self = self, let replay = self.replayRef?.value {
                                // Back to the start of the video if it is ended.
                                if (replay.position >= replay.duration) {
                                    _ = replay.seekTo(position: 0)
                                }

                                // Play the video.
                                if (replay.playState != .playing) {
                                    _ = replay.play()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        // Stop to monitor the replay reference.
        replayRef = nil

        // Stop restart video timer.
        timer?.invalidate()
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

        // Set the thermal processing instance to use to the thermal video view.
        videoView.thermalProc = tproc
        // Set the block to call for each render status.
        videoView.renderStatusBlock = { [weak self]
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
        // Stop rendering the stream
        videoView.setStream(stream: nil)

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
    }
}

