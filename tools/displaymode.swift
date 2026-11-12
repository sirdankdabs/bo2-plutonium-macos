// displaymode <width> <height> <pid>: while <pid> runs, keep the main display
// in a 1x mode of <width>x<height> (pixels = points) at its highest refresh
// rate; when <pid> ends, put back the mode the desktop had at the start.
// displaymode current: print the desktop's size in points and its refresh
// rate, e.g. "2560 1440 160".
// displaymode set <width> <height> <hz>: switch to that 1x mode for the
// login session.
//
// Why: on a HiDPI-scaled desktop (e.g. "looks like 2560x1440" on a 4K panel,
// drawn at 5120x2880), a fullscreen game at that same size leaves the display
// in the scaled mode, and macOS composes every frame at 5K: BO1 waited ~10 ms
// per frame for a drawable and ran at ~75 FPS. In the 1x mode, 153-166 FPS.
// Wine also changes the display's mode for fullscreen games and does not put
// it back when its processes are killed (a crash, "Close BO1"), which left a
// 320 Hz monitor at 60 Hz: the restore at the end covers that.
import CoreGraphics
import Foundation

let args = CommandLine.arguments
let display = CGMainDisplayID()
guard let original = CGDisplayCopyDisplayMode(display) else { exit(1) }
let allOpts = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
let allModes = CGDisplayCopyAllDisplayModes(display, allOpts) as? [CGDisplayMode] ?? []

func say(_ s: String) { print("displaymode: \(s)"); fflush(stdout) }
func apply(_ mode: CGDisplayMode, _ option: CGConfigureOption) -> Bool {
  var config: CGDisplayConfigRef?
  guard CGBeginDisplayConfiguration(&config) == .success else { return false }
  CGConfigureDisplayWithDisplayMode(config, display, mode, nil)
  return CGCompleteDisplayConfiguration(config, option) == .success
}
func oneX(_ w: Int, _ h: Int) -> [CGDisplayMode] {
  allModes.filter { $0.width == w && $0.height == h && $0.pixelWidth == w && $0.pixelHeight == h }
}

if args.count == 2 && args[1] == "current" {
  print("\(original.width) \(original.height) \(Int(original.refreshRate.rounded()))")
  exit(0)
}
if args.count == 5 && args[1] == "set", let w = Int(args[2]), let h = Int(args[3]), let hz = Double(args[4]) {
  guard let mode = oneX(w, h).min(by: { abs($0.refreshRate - hz) < abs($1.refreshRate - hz) }) else {
    say("no 1x \(w)x\(h) mode"); exit(1)
  }
  guard apply(mode, .forSession) else { say("could not switch mode"); exit(1) }
  say("set \(w)x\(h) at 1x, \(Int(mode.refreshRate)) Hz"); exit(0)
}
guard args.count == 4, let w = Int(args[1]), let h = Int(args[2]), let pid = Int32(args[3]) else {
  FileHandle.standardError.write(
    "usage: displaymode <width> <height> <pid> | current | set <width> <height> <hz>\n".data(using: .utf8)!)
  exit(2)
}

// Put the desktop's mode back if the game (Wine) left another one.
func restore() {
  guard let now = CGDisplayCopyDisplayMode(display) else { return }
  if now.ioDisplayModeID != original.ioDisplayModeID || now.refreshRate != original.refreshRate {
    let ok = apply(original, .forSession)
    say("restored \(original.width)x\(original.height) \(Int(original.refreshRate)) Hz" + (ok ? "" : " FAILED"))
  }
}
var sources: [DispatchSourceSignal] = []
for sig in [SIGTERM, SIGINT] {
  signal(sig, SIG_IGN)
  let s = DispatchSource.makeSignalSource(signal: sig, queue: .main)
  s.setEventHandler { restore(); exit(0) }
  s.resume()
  sources.append(s)
}

if original.pixelWidth == w && original.pixelHeight == h {
  say("already \(w)x\(h) at 1x (\(Int(original.refreshRate)) Hz); watching pid \(pid)")
} else if let mode = oneX(w, h).max(by: { $0.refreshRate < $1.refreshRate }) {
  if apply(mode, .forAppOnly) {
    say("\(w)x\(h) at 1x, \(Int(mode.refreshRate)) Hz, until pid \(pid) ends")
  } else {
    say("could not switch mode")
  }
} else {
  say("no 1x \(w)x\(h) mode; watching pid \(pid)")
}
// Watch on a timer so the signal sources on the main queue still run.
let timer = DispatchSource.makeTimerSource(queue: .main)
timer.schedule(deadline: .now() + 1, repeating: 1)
timer.setEventHandler {
  if kill(pid, 0) != 0 {
    // Give Wine a moment to put things back itself before checking.
    sleep(2)
    restore()
    exit(0)
  }
}
timer.resume()
dispatchMain()
