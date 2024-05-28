//
//  AudioPlayer.swift
//  AudioEngineDemo
//
//  Created by Miles Vinson on 5/28/24.
//

import Foundation
import AVFoundation

class AudioPlayer {
    
    private let engine = AVAudioEngine()
    private let mixerNode = AVAudioMixerNode()
    private var players: [Player] = []
    
    struct Player {
        let player = AVAudioPlayerNode()
        let file: AVAudioFile
    }
    
    var isPlaying: Bool {
        return engine.isRunning
    }
    
    
    // MARK: init
    
    init() {
        engine.attach(mixerNode)
    }
    
    
    // MARK: Set files
    
    func setAudioFiles(urls: [URL]) {
        // Cleanup if needed
        engine.stop()
        for player in players {
            player.player.stop()
            engine.disconnectNodeInput(player.player)
        }
        players.removeAll()
        
        let files = urls.compactMap { try? AVAudioFile(forReading: $0) }
        
        // The file to use for processingFormat. Not sure if this is correct,
        // but unsure how else to get a format to pass for the mixerNode -> engine
        guard let referenceFile = files.first else { return }
        
        // Connect the mixer. This is necessary because in actual usage I have a time pitch unit
        // in between the mixer and engine.
        engine.connect(mixerNode, to: engine.mainMixerNode, format: referenceFile.processingFormat)
        
        // Create and connect the players
        for file in files {
            let player = Player(file: file)
            players.append(player)
            
            engine.attach(player.player)
            engine.connect(player.player, to: mixerNode, format: player.file.processingFormat)
        }
        
        // Schedule the files
        seek(to: 0)
    }
    
    
    // MARK: Play
    
    private var playTimer: Timer?
    private var pauseRenderTime: AVAudioTime?
    private var cachedCurrentTime: TimeInterval = 0
    
    func play() {
        print("\nPlay")
        
        playTimer?.invalidate()
        
        // Start the engine
        if engine.isRunning == false {
            do {
                setupAudioSession()
                try self.engine.start()
            } catch {
                print(error)
                return
            }
        }
        
        // Uncomment this line to hear how it sounds without ensuring we get a lastRenderTime:
//        startPlayers(shouldCalculateStartTime: false); return ();
        
        
        // Repeatedly try to get a valid lastRenderTime
        var reloadCount = 0
        
        // Used to compare to ensure the lastRenderTime is reporting a current render time,
        // not just its render time when it was paused.
        let pauseRenderTime = self.pauseRenderTime
        
        // Test to see if it's valid. Ideally this would *always* be valid.
        // It's always valid the first time pressing play, and then after
        // pausing and playing it won't work the first time.
        if isLastRenderTimeValid(players.first?.player.lastRenderTime, pauseRenderTime: pauseRenderTime) {
            print("Got a valid render time at attempt 0")
            self.startPlayers(shouldCalculateStartTime: true)
            
            return
        }
        
        // The question is: how to avoid this retry loop while still stopping the engine on pause?

        playTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true, block: { [weak self] _ in
            guard let self else { return }
            
            reloadCount += 1
            
            guard reloadCount < 30 else {
                print("Giving up")
                self.startPlayers(shouldCalculateStartTime: false)
                
                return
            }
            
            let lastRenderTime = self.players.first?.player.lastRenderTime
            
            if isLastRenderTimeValid(lastRenderTime, pauseRenderTime: pauseRenderTime) {
                print("Got a valid render time at attempt \(reloadCount)")
                self.startPlayers(shouldCalculateStartTime: true)
            }
        })
    }
    
    private func isLastRenderTimeValid(_ lastRenderTime: AVAudioTime?, pauseRenderTime: AVAudioTime?) -> Bool {
        guard let lastRenderTime else { return false }
        
        return lastRenderTime.sampleTime != pauseRenderTime?.sampleTime
    }
    
    private func startPlayers(shouldCalculateStartTime: Bool) {
        playTimer?.invalidate()
        playTimer = nil
        
        guard shouldCalculateStartTime else {
            print("Using nil start time")
            
            for player in players {
                player.player.play(at: nil)
            }
            
            return
        }
        
        
        // Get the lastRenderTime of the first player to use as a synchronized start time
        let startTime: AVAudioTime? = {
            guard let reference = players.first else { return nil }
            
            guard let renderTime = reference.player.lastRenderTime, renderTime.isSampleTimeValid else {
                return nil
            }
            
            let sampleRate = reference.file.processingFormat.sampleRate
            return AVAudioTime(sampleTime: renderTime.sampleTime, atRate: sampleRate)
        }()
        
        if startTime != nil {
            print("Using synchronized start time")
        } else {
            print("Using nil start time")
        }
        
        for player in players {
            // Play at the reference start time.
            // Not sure how to handle if files are different sample rates?
            player.player.play(at: startTime)
        }
    }
    
    
    // MARK: Pause
    
    func pause() {
        playTimer?.invalidate()
        playTimer = nil
        
        //self.cachedCurrentTime = self.getCurrentPlaybackTime()
        
        pauseRenderTime = players.first?.player.lastRenderTime
        
        engine.pause()
        engine.reset()
        
        players.forEach { $0.player.pause() }
    }
    
    
    // MARK: Seek
    
    func seek(to time: TimeInterval) {
        for player in players {
            let file = player.file
            let player = player.player
            let sampleRate = file.processingFormat.sampleRate
            
            player.stop()

            let startFrame = AVAudioFramePosition(time * sampleRate)
            let frameCount = AVAudioFrameCount(file.length - startFrame)
            
            // Start immediately
            let startTime = AVAudioTime(sampleTime: 0, atRate: sampleRate)
            
            player.scheduleSegment(
                file,
                startingFrame: startFrame,
                frameCount: frameCount,
                at: startTime
            )
        }
    }
    
    
    // MARK: Audio Session
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default , policy: .longFormAudio, options: [])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print(error)
        }
    }

    private func endAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print(error)
        }
    }
    
    
}
