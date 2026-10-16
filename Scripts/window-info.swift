import AppKit
import CoreGraphics
let windows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []
for w in windows where (w[kCGWindowOwnerName as String] as? String)=="MDView" && (w[kCGWindowLayer as String] as? Int)==0 {
 print(w[kCGWindowNumber as String] ?? "",w[kCGWindowName as String] ?? "",w[kCGWindowBounds as String] ?? "")
}
