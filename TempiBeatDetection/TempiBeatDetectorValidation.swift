//
//  TempiBeatDetectorValidation.swift
//  TempiBeatDetection
//
//  Created by John Scalo on 5/1/16.
//  Copyright © 2016 John Scalo. See accompanying License.txt for terms.

import Foundation
import AVFoundation
import Accelerate

extension TempiBeatDetector {
    
    func validationStart() {
        
        // File-based beat detection runs asynchronously so in order for the unit test to not end prematurely we need to use a semaphore.
        self.validationSemaphore = DispatchSemaphore(value: 0)
        
        self.testSets = [
            { self.validateStudioSet1() }
            , { self.validateHomeSet1() }
            , {self.validateUtilitySet1() }
            , { self.validateThreesSet1() }
//            { self.oneOffTest() }
            ]
        
        self.testSetNext()
        
        _ = self.validationSemaphore.wait(timeout: DispatchTime.distantFuture)
    }
    
    private func projectURL() -> URL {
        let projectPath = "/Users/jscalo/Developer/Tempi/com.github/TempiBeatDetection"
        return URL(fileURLWithPath: projectPath)
    }

    private func validationSetup() {
        if self.savePlotData {
            let projectURL: URL = self.projectURL()
            
            var plotFluxValuesURL = projectURL.appendingPathComponent("Plots")
            plotFluxValuesURL = plotFluxValuesURL.appendingPathComponent("\(self.currentTestName)-fluxValues.txt")
            
            var plotMedianFluxValuesWithTimeStamplsURL = projectURL.appendingPathComponent("Plots")
            plotMedianFluxValuesWithTimeStamplsURL = plotMedianFluxValuesWithTimeStamplsURL.appendingPathComponent("\(self.currentTestName)-fluxValuesWithTimeStamps.txt")
            
            var plotFullBandFluxValuesWithTimeStamplsURL = projectURL.appendingPathComponent("Plots")
            plotFullBandFluxValuesWithTimeStamplsURL = plotFullBandFluxValuesWithTimeStamplsURL.appendingPathComponent("\(self.currentTestName)-fluxFullBandValuesWithTimeStamps.txt")

            do {
                try FileManager.default.removeItem(at: plotFluxValuesURL)
                try FileManager.default.removeItem(at: plotMedianFluxValuesWithTimeStamplsURL)
                try FileManager.default.removeItem(at: plotFullBandFluxValuesWithTimeStamplsURL)
            } catch _ { /* normal if file not yet created */ }
            
            self.plotFluxValuesDataFile = fopen((plotFluxValuesURL as NSURL).fileSystemRepresentation, "w")
            self.plotMedianFluxValuesWithTimeStampsDataFile = fopen((plotMedianFluxValuesWithTimeStamplsURL as NSURL).fileSystemRepresentation, "w")
            self.plotFullBandFluxValuesWithTimeStampsDataFile = fopen((plotFullBandFluxValuesWithTimeStamplsURL as NSURL).fileSystemRepresentation, "w")
        }
        
        self.testTotal = 0
        self.testCorrect = 0
    }
    
    private func validationFinish() {
        if self.savePlotData {
            fclose(self.plotFluxValuesDataFile)
            fclose(self.plotMedianFluxValuesWithTimeStampsDataFile)
            fclose(self.plotFullBandFluxValuesWithTimeStampsDataFile)
        }

        let result = 100.0 * Float(self.testCorrect) / Float(self.testTotal)
        print(String(format:"[%@] accuracy: %.01f%%\n", self.currentTestName, result))
        self.testSetResults.append(result)
        
        print("Finished testing: \(self.mediaPath)\n")
        
        self.testNext()
    }
    
    private func testAudio(_ path: String,
                           label: String,
                           actualTempo: Float,
                           startTime: Double = 0.0, endTime: Double = 0.0,
                           minTempo: Float = 40.0, maxTempo: Float = 240.0,
                           variance: Float = 2.0) {
        
        let projectURL: URL = self.projectURL()
        let songURL = projectURL.appendingPathComponent("Test Media/\(path)")
        
        print("Start testing: \(path); actual bpm: \(actualTempo)")

        self.validationSetup()

        self.currentTestName = label
        self.mediaStartTime = startTime
        self.mediaEndTime = endTime
        self.minTempo = minTempo
        self.maxTempo = maxTempo
        self.allowedTempoVariance = variance
        self.testActualTempo = actualTempo
        self.fileAnalysisCompletionHandler = {(bpms: [(timeStamp: Double, bpm: Float)], mean: Float, median: Float, mode: Float) in self.validationFinish()}

        self.startFromFile(url: songURL)
    }
    
    private func testSetSetupForSetName(_ setName: String) {
        print("Starting validation set \(setName)")
        self.currentTestSetName = setName
        self.testSetResults = [Float]()
    }
    
    // If there's another test, run it. Otherwise move on to the next test set.
    private func testNext() {
        if self.tests.isEmpty {
            self.testSetFinish()
            self.testSetNext()
        } else {
            let test = self.tests.removeFirst()
            test()
        }
    }
    
    // If there's another test set, start it. Otherwise signal the semaphore so validation can end.
    private func testSetNext() {
        if self.testSets.isEmpty {
            self.validationSemaphore.signal()
        } else {
            let testSet = self.testSets.removeFirst()
            testSet()
        }
    }
    
    private func testSetFinish() {
        let mean: Float = tempi_mean(self.testSetResults)
        print(String(format:"--- Validation set [%@] accuracy: %.01f%%\n", self.currentTestSetName, mean))
    }
    
    private func oneOffTest() {
        self.testSetSetupForSetName("oneOff")

        self.tests = [{
            self.testAudio("Threes/Brahms Lullaby.mp3",
                label: "brahms-lullaby",
                actualTempo: 68,
                startTime: 0, endTime: 15,
                minTempo: 60, maxTempo: 120,
                variance: 2)
            }]
        
        self.testNext()
    }
        
    private func validateStudioSet1 () {
        self.testSetSetupForSetName("studioSet1")
        
        self.tests = [{
                self.testAudio("Studio/Skinny Sweaty Man.mp3",
                    label: "skinny-sweaty-man",
                    actualTempo: 144,
                    startTime: 0, endTime: 15,
                    minTempo: 80, maxTempo: 160,
                    variance: 3)
            }, {
                self.testAudio("Studio/Satisfaction.mp3",
                    label: "satisfaction",
                    actualTempo: 137,
                    startTime: 0, endTime: 20,
                    minTempo: 80, maxTempo: 160,
                    variance: 2.5)
            }, {
                self.testAudio("Studio/Louie, Louie.mp3",
                    label: "louie-louie",
                    actualTempo: 120,
                    startTime: 0, endTime: 15,
                    minTempo: 80, maxTempo: 160,
                    variance: 3)
            }, {
                self.testAudio("Studio/Learn To Fly.mp3",
                    label: "learn-to-fly",
                    actualTempo: 136,
                    startTime: 0, endTime: 15,
                    minTempo: 80, maxTempo: 160,
                    variance: 2)
            }, {
                self.testAudio("Studio/HBFS.mp3",
                    label: "harder-better-faster-stronger",
                    actualTempo: 123,
                    startTime: 0, endTime: 15,
                    minTempo: 80, maxTempo: 160,
                    variance: 2)
            }, {
                self.testAudio("Studio/Waving Flag.mp3",
                    label: "waving-flag",
                    actualTempo: 76,
                    startTime: 0, endTime: 15,
                    minTempo: 60, maxTempo: 120,
                    variance: 2)
            }, {
                self.testAudio("Studio/Back in Black.mp3",
                    label: "back-in-black",
                    actualTempo: 90,
                    startTime: 0, endTime: 15,
                    minTempo: 60, maxTempo: 120,
                    variance: 2)
            }]
        
        self.testNext()
    }
    
    private func validateHomeSet1 () {
        self.testSetSetupForSetName("homeSet1")
        
        self.tests = [{
                self.testAudio("Home/AG-Blackbird-1.mp3",
                    label: "ag-blackbird1",
                    actualTempo: 94,
                    minTempo: 60, maxTempo: 120,
                    variance: 3)
            }, {
                self.testAudio("Home/AG-Blackbird-2.mp3",
                    label: "ag-blackbird2",
                    actualTempo: 96,
                    minTempo: 60, maxTempo: 120,
                    variance: 3)
            }, {
                self.testAudio("Home/AG-Sunset Road-116-1.mp3",
                    label: "ag-sunsetroad1",
                    actualTempo: 116,
                    minTempo: 80, maxTempo: 160,
                    variance: 2)
            }, {
                self.testAudio("Home/AG-Sunset Road-116-2.mp3",
                    label: "ag-sunsetroad2",
                    actualTempo: 115,
                    minTempo: 80, maxTempo: 160,
                    variance: 2)
            }, {
                self.testAudio("Home/Possum-1.mp3",
                    label: "possum1",
                    actualTempo: 79,
                    minTempo: 60, maxTempo: 120,
                    variance: 2)
            }, {
                self.testAudio("Home/Possum-2.mp3",
                    label: "possum2",
                    actualTempo: 81,
                    minTempo: 60, maxTempo: 120,
                    variance: 3)
            }, {
                self.testAudio("Home/Hard Top-1.mp3",
                    label: "hard-top1",
                    actualTempo: 140,
                    minTempo: 80, maxTempo: 160,
                    variance: 2)
            }, {
                self.testAudio("Home/Hard Top-2.mp3",
                    label: "hard-top2",
                    actualTempo: 151,
                    minTempo: 80, maxTempo: 160,
                    variance: 2)
            }, {
                self.testAudio("Home/Definitely Delicate-1.mp3",
                    label: "delicate1",
                    actualTempo: 75,
                    minTempo: 60, maxTempo: 120,
                    variance: 3)
            }, {
                self.testAudio("Home/Wildwood Flower-1.mp3",
                    label: "wildwood1",
                    actualTempo: 95,
                    minTempo: 80, maxTempo: 160,
                    variance: 3)
            }, {
                self.testAudio("Home/Wildwood Flower-2.mp3",
                    label: "wildwood2",
                    actualTempo: 148,
                    minTempo: 80, maxTempo: 160,
                    variance: 3)
            }]

        self.testNext()
}
    
    private func validateThreesSet1 () {
        self.testSetSetupForSetName("threesSet1")

        self.tests = [{
                self.testAudio("Threes/Norwegian Wood.mp3",
                    label: "norwegian-wood",
                    actualTempo: 182,
                    startTime: 0, endTime: 0,
                    minTempo: 100, maxTempo: 200,
                    variance: 3)
            }, {
                self.testAudio("Threes/Drive In Drive Out.mp3",
                    label: "drive-in-drive-out",
                    actualTempo: 81,
                    startTime: 0, endTime: 0,
                    minTempo: 60, maxTempo: 120,
                    variance: 2)
            }, {
                self.testAudio("Threes/Oh How We Danced.mp3",
                    label: "oh-how-we-danced",
                    actualTempo: 179,
                    startTime: 0, endTime: 20,
                    minTempo: 100, maxTempo: 200,
                    variance: 3)
            }, {
                self.testAudio("Threes/Texas Flood.mp3",
                    label: "texas-flood",
                    actualTempo: 58, // Or should it be 175? There's disagreement about what a 'beat' is with 6/8 or 12/8 music.
                    startTime: 0, endTime: 20,
                    minTempo: 40, maxTempo: 80,
                    variance: 2)
            }, {
                // Brahms Lullaby currently scores horribly (8%). Two simple tweaks bring it to 83%:
                // 1. Lowering the correlation threshold to .09. The accurate periods have corr values just above .09.
                // 2. Using tempi_custom_mode instead of tempi_mode.
                // Unfortunately those tweaks also substantially lower the accuracy of the studio and home sets so
                // it's hard to justify for only this one song.
                self.testAudio("Threes/Brahms Lullaby.mp3",
                    label: "brahms-lullaby",
                    actualTempo: 68,
                    startTime: 0, endTime: 15,
                    minTempo: 60, maxTempo: 120,
                    variance: 2)
            }, {
                self.testAudio("Threes/metronome-3-88.mp3",
                    label: "metronome-3-88",
                    actualTempo: 88,
                    startTime: 0, endTime: 10,
                    minTempo: 60, maxTempo: 120,
                    variance: 1)
            }, {
                self.testAudio("Threes/metronome-3-126.mp3",
                    label: "metronome-3-126",
                    actualTempo: 126,
                    startTime: 0, endTime: 15,
                    minTempo: 80, maxTempo: 160,
                    variance: 1)
            }]
        
        self.testNext()
    }
    
    private func validateUtilitySet1 () {
        self.testSetSetupForSetName("utilitySet1")

        self.tests = [{
                self.testAudio("Utility/half-clave-115.mp3",
                    label: "half-clave-115",
                    actualTempo: 115,
                    minTempo: 60, maxTempo: 120,
                    variance: 1)
            }, {
                self.testAudio("Utility/half-clave-220.mp3",
                    label: "half-clave-220",
                    actualTempo: 220,
                    minTempo: 120, maxTempo: 240,
                    variance: 1)
            }, {
                self.testAudio("Utility/half-clave-80.mp3",
                    label: "half-clave-80",
                    actualTempo: 80,
                    minTempo: 60, maxTempo: 120,
                    variance: 1)
            }, {
                self.testAudio("Utility/full-clave-105.mp3",
                    label: "full-clave-105",
                    actualTempo: 105,
                    minTempo: 60, maxTempo: 120,
                    variance: 1)
            }, {
                self.testAudio("Utility/full-clave-135.mp3",
                    label: "full-clave-135",
                    actualTempo: 135,
                    minTempo: 80, maxTempo: 160,
                    variance: 1)
            }, {
                self.testAudio("Utility/full-clave-65.mp3",
                    label: "full-clave-65",
                    actualTempo: 65,
                    minTempo: 60, maxTempo: 120,
                    variance: 1)
            }, {
                self.testAudio("Utility/metronome-4-88.mp3",
                    label: "metronome-4-88",
                    actualTempo: 88,
                    startTime: 0, endTime: 10,
                    minTempo: 60, maxTempo: 120,
                    variance: 1)
            }, {
                self.testAudio("Utility/metronome-4-126.mp3",
                    label: "metronome-4-126",
                    actualTempo: 126,
                    startTime: 0, endTime: 15,
                    minTempo: 80, maxTempo: 160,
                    variance: 1)
            }]
        
        self.testNext()
    }
}
