import AppKit
// Preserve the supplied artwork's aspect ratio and alpha. No redesign or cropping.
let sourceURL=URL(fileURLWithPath:CommandLine.arguments[1])
let folder=URL(fileURLWithPath:CommandLine.arguments[2],isDirectory:true)
let output=URL(fileURLWithPath:CommandLine.arguments[3])
guard let original=NSImage(contentsOf:sourceURL) else{fatalError("Cannot read icon")}
try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
var payload=Data()
func be32(_ value:Int)->Data{withUnsafeBytes(of:UInt32(value).bigEndian){Data($0)}}
let codes:[Int:String]=[16:"icp4",32:"icp5",64:"icp6",128:"ic07",256:"ic08",512:"ic09",1024:"ic10"]
for size in [16,32,64,128,256,512,1024] {
 let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap);NSGraphicsContext.current?.imageInterpolation = .high
 let scale=CGFloat(size)/max(original.size.width,original.size.height)
 let width=original.size.width*scale,height=original.size.height*scale
 original.draw(in:NSRect(x:(CGFloat(size)-width)/2,y:(CGFloat(size)-height)/2,width:width,height:height),from:.zero,operation:.copy,fraction:1)
 NSGraphicsContext.restoreGraphicsState()
 let data=bitmap.representation(using:.png,properties:[:])!
 if [16,32,128,256,512].contains(size){try data.write(to:folder.appendingPathComponent("icon_\(size)x\(size).png"))}
 if [32,64,256,512,1024].contains(size){try data.write(to:folder.appendingPathComponent("icon_\(size/2)x\(size/2)@2x.png"))}
 payload.append(Data(codes[size]!.utf8));payload.append(be32(data.count+8));payload.append(data)
}
var icns=Data("icns".utf8);icns.append(be32(payload.count+8));icns.append(payload);try icns.write(to:output)
guard let result=NSImage(contentsOf:output),result.size.width>0 else{fatalError("ICNS round-trip failed")}
print("Icon created: \(output.lastPathComponent), \(icns.count) bytes; \(result.representations.count) decoded representations")
