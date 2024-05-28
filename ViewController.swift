//
//  ViewController.swift
//  AudioEngineDemo
//
//  Created by Miles Vinson on 5/28/24.
//

import UIKit

class ViewController: UIViewController {
    
    private let audioPlayer = AudioPlayer()
    
    private let togglePlaybackButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let url = Bundle.main.url(forResource: "click", withExtension: "m4a")!
        audioPlayer.setAudioFiles(urls: [url, url, url])
        
        togglePlaybackButton.addAction(UIAction(handler: { [weak self] _ in
            if self?.audioPlayer.isPlaying == true {
                self?.audioPlayer.pause()
            } else {
                self?.audioPlayer.play()
            }
            self?.reloadPlaybackButton()
        }), for: .primaryActionTriggered)
        view.addSubview(togglePlaybackButton)
        
        reloadPlaybackButton()
    }
    
    private func reloadPlaybackButton() {
        if audioPlayer.isPlaying {
            togglePlaybackButton.setTitle("Pause", for: .normal)
        }
        else {
            togglePlaybackButton.setTitle("Play", for: .normal)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        togglePlaybackButton.bounds.size = CGSize(width: 100, height: 50)
        togglePlaybackButton.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
    }

}

