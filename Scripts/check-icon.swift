import AppKit
let appPath=CommandLine.arguments[1]
let output=CommandLine.arguments[2]
let icon=NSWorkspace.shared.icon(forFile:appPath)
let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:128,pixelsHigh:128,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
icon.draw(in:NSRect(x:0,y:0,width:128,height:128),from:.zero,operation:.copy,fraction:1)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output))
print("Finder icon resolved to",icon.size)
