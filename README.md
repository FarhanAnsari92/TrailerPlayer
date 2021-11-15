# Trailer Player
iOS video player for trailer. You can customize layout for the control panel.
Support PiP and DRM. 

https://user-images.githubusercontent.com/1064039/136514197-452bfecd-fe68-465d-9621-781056485286.mov

Icons by Icons8 (https://icons8.com)

## Releases
#### v1.4.2
- Support CocoaPods

#### v1.4.1
- Provide debug information

#### v1.3.7
- Fixed some known bugs
- Fixed memory leak

#### v1.3.3
- Fix an incorrect layout issue

#### v1.3.2
- Update access control

#### v1.3.1
- Code refactoring

#### v1.3.0
- Support DRM (FairPlay)

#### v1.2.1
- Code refactoring

#### v1.2.0
- Support control panel
- Support replay panel
- Fixed some known bugs

#### v1.1.0
- Support PIP
- Fixed some known bugs

#### v1.0.0
- [x] 沒有 trailer 的 content，單純顯示 thumbnail。
- [x] 有 trailer 的 content，可以自動播放 trailer，且在播放途中可以隨時暫停播放。
- [x] Preview 功能不會有倍速播放，但是 progress bar 必須要有，且用戶可以自由調整 progress bar 觀看在不同秒數的內容。
- [x] Preview 功能不允許用 AirPlay 投到輸出設備上。
- [x] Preview 功能的聲音部份，預設是 off，但用戶可以點選音量按鈕，以打開聲音。
- [x] 對於同時有 thumbnail 與 trailer 的 content，會先顯示 thumbnail，此時背景會持續 loading trailer。直到 trailer loading 完成、ready to play 的時候，即顯示 trailer 並自動播放，此時縮圖會被隱藏起來。
- [x] Preview 功能可以全螢幕播放。
- [x] Trailer 的顯示 size 會跟 thumbnail 完全一致。
- [x] 當 trailer 播放完畢之後，播放畫面會停止，且正中間會有一個 Replay 按鈕，用戶可以選點此按鈕以重播此 trailer。
- [x] 可以提供 trailer 的倒數秒數，並會隨著播放而逐漸減少秒數。
- [x] 不可背景播放。
- [x] 從背景回到前景時，要繼續播放。
- [x] 當影片 Buffering 的時候要秀 loading。
- [x] trailer 顯示時，要隱藏 thumbnail image。
- [x] 不可在 Remote Control Center 裡顯示資訊。
- [x] Preview 播完後回到 thumbnail。
- [x] 如果用戶的網路，從連網 => 斷網 => 再連網的時候，trailer 會接續播放。
- [x] Support iOS 10~15
- [x] Support SPM

## How to use
#### 建立 TrailerPlayerView
```swift
let playerView = TrailerPlayerView()
let item = TrailerPlayerItem(
            url: URL(string: "..."),
            thumbnailUrl: URL(string: "..."))
playerView.playbackDelegate = self
playerView.set(item: item)
```
#### TrailerPlayerItem 細節設定
```swift
required public init(url: URL? = nil,                // trailer url
                     thumbnailUrl: URL? = nil,       // thumbnail url
                     thumbnailImage: UIImage? = nil, // 若已有 thumbnail 圖片時，可直接提供 
                     autoPlay: Bool = true,          // 自動播放，否則自行呼叫 play()
                     autoReplay: Bool = false,       // 播放完畢後，是否自動重新播放
                     mute: Bool = true,              // 預設播放為靜音
                     isDRMContent: Bool = false)     // 是否為 DRM 內容
```
#### TrailerPlayerPlaybackDelegate
```swift
// 當 player 播放時，可透過此 callback 更新播放時間
func trailerPlayer(_ player: TrailerPlayer, didUpdatePlaybackTime time: TimeInterval)
// 當 player 狀態改變時，可透過此 callback 更新控制面板上的播放狀態
func trailerPlayer(_ player: TrailerPlayer, didChangePlaybackStatus status: TrailerPlayerPlaybackStatus)
// 當 player item 狀態變為 readyToPlay 時觸發
func trailerPlayerPlaybackReady(_ player: TrailerPlayer)
// 當 player 播放發生錯誤時觸發
func trailerPlayer(_ player: TrailerPlayer, playbackDidFailed error: TrailerPlayerPlaybackError)
```
#### [Optional] PiP 支援
```swift
playerView.enablePictureInPicture = true
```
#### [Optional] 面板設置
```swift
let controlPanel: UIView = ... // your custom control panel
playerView.addControlPanel(controlPanel)

let replayPanel: UIView = ... // your custom replay panel
playerView.addReplayPanel(replayPanel)
```
#### [Optional] Debug Info 顯示
![IMG_0007](https://user-images.githubusercontent.com/1064039/140898455-3b3cedd5-2945-49f6-a5f6-2b3ca6a4922a.jpg)
```swift
let playerView = TrailerPlayerView()
playerView.enableDebugView = true
```
#### [Optional] DRM 支援
```swift
let playerView = TrailerPlayerView()
let item = TrailerPlayerItem(
            url: URL(string: "..."),
            thumbnailUrl: URL(string: "..."),
            isDRMContent: true)
playerView.playbackDelegate = self
playerView.DRMDelegate = self
playerView.set(item: item)

// DRM Delegate
extension ViewController: TrailerPlayerDRMDelegate {
    
    func certUrl(for player: TrailerPlayer) -> URL {
        return URL(string: ...) // your certificate url
    }
    
    func ckcUrl(for player: TrailerPlayer) -> URL {
        return URL(string: ...) // your ckc url
    }
}
```
#### TrailerPlayerDRMDelegate
```swift
// CKC(Content Key Context) URL
func ckcUrl(for player: TrailerPlayer) -> URL
// Certificate URL
func certUrl(for player: TrailerPlayer) -> URL
// Optional: content Id for SPC(Server Playback Context) message
func contentId(for player: TrailerPlayer) -> String?
// Optional: HTTP header fields for CKC request
func ckcRequestHeaderFields(for player: TrailerPlayer) -> [(headerField: String, value: String)]?
```
#### 操作細節可參考 Sample code
