//
//  TrailerPlayerView.swift
//  TrailerPlayer
//
//  Created by Abe Wang on 2021/10/1.
//

import AVFoundation
import UIKit

public protocol TrailerPlayerViewDelegate: AnyObject {
    func trailerPlayerViewDidEndPlaying(_ view: TrailerPlayerView)
    func trailerPlayerView(_ view: TrailerPlayerView, didUpdatePlaybackTime time: TimeInterval)
}

public class TrailerPlayerView: UIView {
    
    public enum Status {
        case playing
        case pause
        case waitingToPlay
        case unknown
    }
    
    public weak var delegate: TrailerPlayerViewDelegate?
    
    public var isMuted: Bool {
        player?.isMuted ?? true
    }
    
    public var canUseFullscreen: Bool {
        currentPlayingItem?.videoUrl != nil
    }
    
    public var duration: TimeInterval {
        guard let time = player?.currentItem?.duration else { return 0.0 }
        return CMTimeGetSeconds(time)
    }
    
    public var status: Status {
        guard let status = player?.timeControlStatus else { return .unknown }
        switch status {
        case .playing: return .playing
        case .paused: return .pause
        case .waitingToPlayAtSpecifiedRate: return .waitingToPlay
        default: return .unknown
        }
    }
    
    @AutoLayout
    public private(set) var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()
    
    @AutoLayout
    public private(set) var thumbnailView: UIImageView = {
        let view = UIImageView()
        view.clipsToBounds = true
        view.backgroundColor = .black
        view.contentMode = .scaleAspectFill
        return view
    }()
    
    @AutoLayout
    public private(set) var playerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.isHidden = true
        return view
    }()
    
    @AutoLayout
    private var loadingIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        view.style = .whiteLarge
        return view
    }()
    
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var currentPlayingItem: TrailerPlayerItem?
    private var shouldResumePlay: Bool = false
    private var periodicTimeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var previousTimeControlStatus: AVPlayer.TimeControlStatus?
    
    deinit {
        reset()
    }
    
    public init() {
        super.init(frame: CGRect.zero)
        setup()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        playerLayer?.frame = CGRect(x: 0.0, y: 0.0, width: containerView.frame.width, height: containerView.frame.height)
    }
}

public extension TrailerPlayerView {
    
    func set(item: TrailerPlayerItem) {
        loadingIndicator.startAnimating()
        
        reset()
        
        currentPlayingItem = item
        
        if let url = item.thumbnailUrl {
            fetchThumbnailImage(url)
        }
        if let url = item.videoUrl {
            setupPlayer(url)
            if item.autoPlay {
                player?.play()
            }
            player?.isMuted = item.mute
        }
    }
    
    func play() {
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
    
    func replay() {
        guard let player = player else { return }
        player.seek(to: CMTime.zero)
        player.play()
        
        playerView.isHidden = false
    }
    
    func seek(to time: TimeInterval) {
        player?.seek(to: CMTimeMakeWithSeconds(time, preferredTimescale: Int32(NSEC_PER_SEC)))
    }
    
    func toggleMute() {
        guard let player = player else { return }
        player.isMuted = !player.isMuted
    }
    
    func fullscreen(enabled: Bool, rotateTo orientation: UIInterfaceOrientation? = nil) {
        guard let window = UIApplication.shared.keyWindow, canUseFullscreen else { return }
        
        containerView.removeFromSuperview()
        layout(view: containerView, into: enabled ? window: self)
        
        if let orientation = orientation {
            UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
        }
    }
}

private extension TrailerPlayerView {
    
    func setup() {
        backgroundColor = .black
        
        layout(view: containerView, into: self, animated: false)
        layout(view: thumbnailView, into: containerView, animated: false)
        layout(view: playerView, into: containerView, animated: false)
        
        containerView.addSubview(loadingIndicator)
        loadingIndicator.centerXAnchor.constraint(equalTo: self.containerView.centerXAnchor).isActive = true
        loadingIndicator.centerYAnchor.constraint(equalTo: self.containerView.centerYAnchor).isActive = true
    }
    
    func fetchThumbnailImage(_ url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard let data = data, error == nil else { return }
                
                if self.currentPlayingItem?.videoUrl == nil {
                    self.loadingIndicator.stopAnimating()
                }
                
                UIView.transition(with: self.thumbnailView, duration: 0.25, options: .transitionCrossDissolve) {
                    self.thumbnailView.image = UIImage(data: data)
                } completion: {_ in }
            }
        }
        .resume()
    }
    
    func setupPlayer(_ url: URL) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        previousTimeControlStatus = player?.timeControlStatus
        
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidEndPlaying), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] _, _ in
            guard let self = self, let item = self.player?.currentItem else { return }
            switch item.status {
            case .readyToPlay:
                print("[TrailerPlayerView] ready to play")
                self.playerView.isHidden = false
            case .failed:
                print("[TrailerPlayerView] item failed")
            default:
                print("[TrailerPlayerView] unknown error")
            }
        }
        
        periodicTimeObserver = player?.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(0.1, preferredTimescale: Int32(NSEC_PER_SEC)), queue: DispatchQueue.main) { [weak self] _ in
            guard
                let self = self,
                let player = self.player,
                player.timeControlStatus == .playing
            else { return }
            
            self.delegate?.trailerPlayerView(self, didUpdatePlaybackTime: CMTimeGetSeconds(player.currentTime()))
        }
        
        timeControlStatusObserver = player?.observe(\.timeControlStatus, options: [.old, .new]) { [weak self] player, _ in
            guard let self = self else { return }
            
            // newValue and oldValue always nil when observing .timeControlStatus
            // https://bugs.swift.org/browse/SR-5872
            let newValue = player.timeControlStatus
            let oldValue = self.previousTimeControlStatus
            self.previousTimeControlStatus = newValue

            switch (oldValue, newValue) {
            case (.waitingToPlayAtSpecifiedRate, _) where newValue != .waitingToPlayAtSpecifiedRate:
                self.loadingIndicator.stopAnimating()
            case (_, .waitingToPlayAtSpecifiedRate) where oldValue != .waitingToPlayAtSpecifiedRate:
                self.loadingIndicator.startAnimating()
            default:
                break
            }
        }
        
        playerLayer = AVPlayerLayer(player: player)
        playerView.layer.addSublayer(playerLayer!)
    }
    
    func reset() {
        NotificationCenter.default.removeObserver(self)
        
        currentPlayingItem = nil
        previousTimeControlStatus = nil
        
        thumbnailView.image = nil
        
        if let observer = periodicTimeObserver {
            player?.removeTimeObserver(observer)
            periodicTimeObserver = nil
        }
        
        statusObserver?.invalidate()
        statusObserver = nil
        
        timeControlStatusObserver?.invalidate()
        timeControlStatusObserver = nil
        
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }
    
    func layout(view: UIView, into: UIView, animated: Bool = true) {
        guard view.superview == nil else { return }
        
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0
        
        into.addSubview(view)
        
        let duration = animated ? 0.25: 0.0
        UIView.animate(withDuration: duration, delay: 0.0, options: .curveEaseOut) {
            view.topAnchor.constraint(equalTo: into.topAnchor).isActive = true
            view.leftAnchor.constraint(equalTo: into.leftAnchor).isActive = true
            view.rightAnchor.constraint(equalTo: into.rightAnchor).isActive = true
            view.bottomAnchor.constraint(equalTo: into.bottomAnchor).isActive = true
            view.alpha = 1
            view.layoutIfNeeded()
        } completion: { _ in }
    }
    
    @objc func playerDidEndPlaying() {
        guard let item = currentPlayingItem else { return }
        
        if item.autoReplay {
            replay()
        } else {
            playerView.isHidden = true
            delegate?.trailerPlayerViewDidEndPlaying(self)
        }
    }
    
    @objc func appWillEnterForeground() {
        if shouldResumePlay {
            shouldResumePlay = false
            play()
        }
    }
    
    @objc func appDidEnterBackground() {
        guard status == .playing || status == .waitingToPlay else { return }
        shouldResumePlay = true
    }
}