import AppKit
import WebKit
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate, NSSearchFieldDelegate {
    var window: NSWindow!
    var web: ReaderWebView!
    let resources = ResourceHandler()
    let searchField = NSSearchField()
    let resultLabel = NSTextField(labelWithString: "")
    let statusLabel = NSTextField(labelWithString: "문서를 열거나 창에 파일을 놓아 주세요")
    let themeButton = NSPopUpButton()
    var current: ViewerDocument?
    var ready = false
    var loadID = 0
    var pending: URL?
    var documentSession = ""
    var fontSize = UserDefaults.standard.object(forKey: "fontSize") as? Int ?? 17
    var theme = UserDefaults.standard.string(forKey: "theme") ?? "system"
    var sidebar = true
    var appearanceObservation: NSKeyValueObservation?
    var lastError: String?
    var renderedCount = 0
    var testing = false
    var panel: NSOpenPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        #if TESTING
        testing = CommandLine.arguments.contains("--self-test")
        #endif
        buildMenu(); buildWindow()
        // Deny web network loads independently of document sanitization and CSP.
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "MDViewOffline-v1", encodedContentRuleList: """
        [{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}},{"trigger":{"url-filter":"^wss?://"},"action":{"type":"block"}},{"trigger":{"url-filter":"^ftp://"},"action":{"type":"block"}}]
        """) { [weak self] rules, error in
            guard let self else { return }
            guard let rules, error == nil else { self.showError("오프라인 보호를 초기화하지 못했습니다. 앱을 다시 열어 주세요."); return }
            self.web.configuration.userContentController.add(rules)
            self.web.load(URLRequest(url: URL(string: "mdview://bundle/index.html")!))
        }
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.applySettings() }
        }
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let first = urls.first else { return }
        if web == nil { pending = first } else { openDocument(first) }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool { window.makeKeyAndOrderFront(nil); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func menuItem(_ title: String, _ action: Selector?, _ key: String = "", target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = target ?? self; return item
    }
    func buildMenu() {
        let menu = NSMenu()
        let app = NSMenuItem(); menu.addItem(app); app.submenu = NSMenu(title: "MDView")
        app.submenu?.addItem(menuItem("MDView 정보", #selector(about)))
        app.submenu?.addItem(.separator())
        app.submenu?.addItem(menuItem("MDView 가리기", #selector(NSApplication.hide(_:)), "h", target: NSApp))
        app.submenu?.addItem(menuItem("MDView 종료", #selector(NSApplication.terminate(_:)), "q", target: NSApp))
        let file = NSMenuItem(); menu.addItem(file); file.submenu = NSMenu(title: "파일")
        file.submenu?.addItem(menuItem("열기…", #selector(openPanel), "o"))
        file.submenu?.addItem(menuItem("다시 읽기", #selector(reloadDocument), "r"))
        file.submenu?.addItem(menuItem("Finder에서 보기", #selector(revealDocument)))
        file.submenu?.addItem(.separator()); file.submenu?.addItem(menuItem("창 닫기", #selector(closeWindow), "w"))
        let edit = NSMenuItem(); menu.addItem(edit); edit.submenu = NSMenu(title: "편집")
        for (title, selector, key) in [("복사", "copy:", "c"), ("전체 선택", "selectAll:", "a"), ("오려두기", "cut:", "x"), ("붙여넣기", "paste:", "v")] {
            let item = NSMenuItem(title: title, action: Selector(selector), keyEquivalent: key); edit.submenu?.addItem(item)
        }
        edit.submenu?.addItem(.separator()); edit.submenu?.addItem(menuItem("문서에서 찾기", #selector(focusSearch), "f"))
        edit.submenu?.addItem(menuItem("다음 결과", #selector(nextMatch), "g"))
        let previous = menuItem("이전 결과", #selector(previousMatch), "g"); previous.keyEquivalentModifierMask = [.command,.shift]; edit.submenu?.addItem(previous)
        let view = NSMenuItem(); menu.addItem(view); view.submenu = NSMenu(title: "보기")
        view.submenu?.addItem(menuItem("글자 크게", #selector(increaseFont), "+"))
        view.submenu?.addItem(menuItem("글자 작게", #selector(decreaseFont), "-"))
        view.submenu?.addItem(menuItem("기본 글자 크기", #selector(resetFont), "0"))
        view.submenu?.addItem(menuItem("목차 표시 / 숨기기", #selector(toggleSidebar), "\\"))
        let help = NSMenuItem(); menu.addItem(help); help.submenu = NSMenu(title:"도움말")
        help.submenu?.addItem(menuItem("MDView 사용법", #selector(showHelp)))
        NSApp.mainMenu = menu
    }
    func button(_ title: String, _ action: Selector, help: String) -> NSButton {
        let b = NSButton(title:title, target:self, action:action); b.bezelStyle = .rounded; b.toolTip=help; b.setAccessibilityLabel(help); return b
    }
    func buildWindow() {
        window = NSWindow(contentRect:NSRect(x:0,y:0,width:1160,height:800),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title="MDView";window.minSize=NSSize(width:760,height:500);window.center();window.setFrameAutosaveName("MDView.Reader")
        let root = NSView();window.contentView=root
        let bar = NSStackView();bar.orientation = .horizontal;bar.spacing=10;bar.edgeInsets=NSEdgeInsets(top:10,left:16,bottom:10,right:16)
        bar.addArrangedSubview(button("☰",#selector(toggleSidebar),help:"목차 표시 / 숨기기 (⌘\\)"))
        bar.addArrangedSubview(button("열기…",#selector(openPanel),help:"문서 열기 (⌘O)"))
        let spacer=NSView();spacer.setContentHuggingPriority(.defaultLow,for:.horizontal);bar.addArrangedSubview(spacer)
        searchField.placeholderString="문서에서 찾기";searchField.delegate=self;searchField.sendsSearchStringImmediately=true;searchField.setAccessibilityLabel("문서에서 찾기")
        searchField.widthAnchor.constraint(equalToConstant:190).isActive=true;bar.addArrangedSubview(searchField)
        resultLabel.font = .monospacedDigitSystemFont(ofSize:11,weight:.regular);resultLabel.textColor = .secondaryLabelColor;resultLabel.widthAnchor.constraint(equalToConstant:64).isActive=true;bar.addArrangedSubview(resultLabel)
        bar.addArrangedSubview(button("‹",#selector(previousMatch),help:"이전 검색 결과"));bar.addArrangedSubview(button("›",#selector(nextMatch),help:"다음 검색 결과"))
        bar.addArrangedSubview(button("A−",#selector(decreaseFont),help:"글자 작게"));bar.addArrangedSubview(button("A+",#selector(increaseFont),help:"글자 크게"))
        themeButton.addItems(withTitles:["시스템","라이트","다크"]);themeButton.selectItem(at:["system","light","dark"].firstIndex(of:theme) ?? 0);themeButton.target=self;themeButton.action=#selector(changeTheme);themeButton.setAccessibilityLabel("테마");bar.addArrangedSubview(themeButton)
        let config = WKWebViewConfiguration();config.websiteDataStore = .nonPersistent();config.setURLSchemeHandler(resources,forURLScheme:"mdview");config.setURLSchemeHandler(resources,forURLScheme:"mdimage");config.userContentController.add(self,name:"bridge")
        config.preferences.javaScriptCanOpenWindowsAutomatically=false
        web=ReaderWebView(frame:.zero,configuration:config);web.navigationDelegate=self;web.allowsBackForwardNavigationGestures=false
        web.registerForDraggedTypes([.fileURL]);web.onDrop = { [weak self] urls in self?.acceptDrop(urls) ?? false }
        statusLabel.font = .systemFont(ofSize:11);statusLabel.textColor = .secondaryLabelColor;statusLabel.lineBreakMode = .byTruncatingMiddle
        let separator=NSBox();separator.boxType = .separator
        for view in [bar,separator,web!,statusLabel] { view.translatesAutoresizingMaskIntoConstraints=false;root.addSubview(view) }
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo:root.topAnchor),bar.leadingAnchor.constraint(equalTo:root.leadingAnchor),bar.trailingAnchor.constraint(equalTo:root.trailingAnchor),bar.heightAnchor.constraint(equalToConstant:54),
            separator.topAnchor.constraint(equalTo:bar.bottomAnchor),separator.leadingAnchor.constraint(equalTo:root.leadingAnchor),separator.trailingAnchor.constraint(equalTo:root.trailingAnchor),separator.heightAnchor.constraint(equalToConstant:1),
            web.topAnchor.constraint(equalTo:separator.bottomAnchor),web.leadingAnchor.constraint(equalTo:root.leadingAnchor),web.trailingAnchor.constraint(equalTo:root.trailingAnchor),web.bottomAnchor.constraint(equalTo:statusLabel.topAnchor,constant:-7),
            statusLabel.leadingAnchor.constraint(equalTo:root.leadingAnchor,constant:18),statusLabel.trailingAnchor.constraint(equalTo:root.trailingAnchor,constant:-18),statusLabel.bottomAnchor.constraint(equalTo:root.bottomAnchor,constant:-7),statusLabel.heightAnchor.constraint(equalToConstant:14)
        ])
    }
    @objc func openPanel() {
        guard panel == nil else { return }
        let p = NSOpenPanel();panel=p;p.title="Markdown 문서 열기";p.canChooseDirectories=false;p.allowsMultipleSelection=false
        p.allowedContentTypes=["md","markdown","mdown","mkd","txt"].compactMap{UTType(filenameExtension:$0)}
        p.beginSheetModal(for:window){ [weak self] response in
            self?.panel=nil
            if response == .OK, let url=p.url { self?.openDocument(url) }
        }
    }
    @discardableResult func acceptDrop(_ urls:[URL])->Bool {
        guard urls.count == 1 else { return false };openDocument(urls[0]);return true
    }
    func openDocument(_ url:URL) {
        guard ready else { pending=url;return }
        loadID += 1; let ticket=loadID
        statusLabel.stringValue="읽는 중: \(url.lastPathComponent)"
        DispatchQueue.global(qos:.userInitiated).async { [weak self] in
            let result=Result{try ViewerDocument.read(url)}
            DispatchQueue.main.async { [weak self] in
                guard let self, ticket==self.loadID else { return }
                switch result {
                case .success(let document): self.display(document)
                case .failure(let error):self.restoreStatus();self.showError(error.localizedDescription)
                }
            }
        }
    }
    func display(_ document: ViewerDocument) {
        current=document;lastError=nil;documentSession=UUID().uuidString.lowercased();resources.setDocument(document.url,session:documentSession)
        searchField.stringValue="";resultLabel.stringValue="";window.title="\(document.url.lastPathComponent) — MDView";window.representedURL=document.url
        web.callAsyncJavaScript("MDView.render(data)",arguments:["data":["name":document.url.lastPathComponent,"text":document.text,"bytes":document.bytes,"plain":document.plain,"session":documentSession]],in:nil,in:.page){ [weak self] result in
            if case .failure = result { self?.showError("문서를 표시하지 못했습니다. 다시 읽기를 시도해 주세요.") }
        }
        restoreStatus()
    }
    func restoreStatus() { statusLabel.stringValue=current.map{"\($0.url.lastPathComponent)  ·  \(ByteCountFormatter.string(fromByteCount:Int64($0.bytes),countStyle:.file))  ·  \($0.plain ? "큰 문서 · 원문 보기" : "읽기 전용")"} ?? "문서를 열거나 창에 파일을 놓아 주세요" }
    func showError(_ message:String) {lastError=message;guard !testing else{return};let alert=NSAlert();alert.messageText="문서를 열 수 없습니다";alert.informativeText=message;alert.beginSheetModal(for:window)}
    func js(_ code:String) {guard ready else{return};web.evaluateJavaScript(code,completionHandler:nil)}
    func applySettings() {
        guard ready else{return}
        let dark=NSApp.effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
        window.appearance = theme == "system" ? nil : NSAppearance(named:theme == "dark" ? .darkAqua : .aqua)
        web.callAsyncJavaScript("MDView.settings(settings)",arguments:["settings":["font":fontSize,"theme":theme,"dark":dark,"sidebar":sidebar]],in:nil,in:.page,completionHandler:nil)
        if !testing {UserDefaults.standard.set(fontSize,forKey:"fontSize");UserDefaults.standard.set(theme,forKey:"theme")}
    }
    @objc func changeTheme(){theme=["system","light","dark"][themeButton.indexOfSelectedItem];applySettings()}
    @objc func increaseFont(){fontSize=min(28,fontSize+1);applySettings()}
    @objc func decreaseFont(){fontSize=max(12,fontSize-1);applySettings()}
    @objc func resetFont(){fontSize=17;applySettings()}
    @objc func toggleSidebar(){sidebar.toggle();applySettings()}
    @objc func focusSearch(){window.makeFirstResponder(searchField)}
    @objc func nextMatch(){js("MDView.next()")}
    @objc func previousMatch(){js("MDView.previous()")}
    @objc func closeWindow(){window.close()}
    @objc func reloadDocument(){if let url=current?.url{openDocument(url)}}
    @objc func revealDocument(){if let url=current?.url{NSWorkspace.shared.activateFileViewerSelecting([url])}}
    func controlTextDidChange(_ obj:Notification){web.callAsyncJavaScript("MDView.search(query)",arguments:["query":searchField.stringValue],in:nil,in:.page,completionHandler:nil)}
    func control(_ control:NSControl,textView:NSTextView,doCommandBy commandSelector:Selector)->Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)){nextMatch();return true}
        if commandSelector == #selector(NSResponder.cancelOperation(_:)){searchField.stringValue="";controlTextDidChange(Notification(name:NSControl.textDidChangeNotification));window.makeFirstResponder(web);return true};return false
    }
    @objc func about(){let a=NSAlert();a.messageText="MDView 1.0";a.informativeText="문서에 집중하는 시간.\n오프라인 Markdown 뷰어 · 읽기 전용\nmacOS 13 이상 · Apple Silicon / Intel";a.beginSheetModal(for:window)}
    @objc func showHelp(){let a=NSAlert();a.messageText="MDView 사용법";a.informativeText="⌘O: 문서 열기 · 창에 파일 드래그 앤 드롭\n⌘F: 문서 검색 · ⌘G: 다음 결과 · Esc: 검색 지우기\n⌘+ / ⌘− / ⌘0: 글자 크기 · ⌘\\: 목차\n⌘R: 다시 읽기\n\n원문 HTML, 원격 이미지, SVG 파일은 실행하거나 불러오지 않습니다. 상대 이미지는 문서 폴더 안에서만 표시합니다. Mermaid는 오프라인으로 지원하며 큰 도식·사용자 설정은 원문으로 표시합니다.\n\nUTF-8 / BOM UTF-16 · 최대 8 MB\n1 MB를 넘는 문서는 원문 보기로 표시합니다.\n도식 내부 글자는 검색 대상에서 제외됩니다.";a.beginSheetModal(for:window)}
    func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage) {
        guard message.frameInfo.isMainFrame,message.frameInfo.request.url?.scheme == "mdview",message.frameInfo.request.url?.host == "bundle",let body=message.body as? [String:Any],let type=body["type"] as? String else{return}
        switch type {
        case "ready":ready=true;applySettings();if let url=pending{pending=nil;openDocument(url)}
            #if TESTING
            if testing { Task { await IntegrationTests.run(self) } }
            #endif
        case "open":openPanel()
        case "search":let count=body["count"] as? Int ?? 0;let index=body["index"] as? Int ?? 0;resultLabel.stringValue=searchField.stringValue.isEmpty ? "" : "\(index)/\(count)\(count>=3000 ? "+" : "")"
        case "rendered":renderedCount += 1
        case "link":if let href=body["href"] as? String{handleLink(href)}
        default:break
        }
    }
    func handleLink(_ href:String) {
        guard let url=URL(string:href) else{return}
        if let scheme=url.scheme?.lowercased(),["https","http","mailto"].contains(scheme){
            let a=NSAlert();a.messageText="외부 링크를 열까요?";a.informativeText=url.absoluteString;a.addButton(withTitle:"기본 앱에서 열기");a.addButton(withTitle:"취소")
            a.beginSheetModal(for:window){result in if result == .alertFirstButtonReturn{NSWorkspace.shared.open(url)}}
        }else if url.scheme == nil, !href.hasPrefix("/"), let current {
            let path=(href.components(separatedBy:"#").first ?? href).removingPercentEncoding ?? href
            let root=current.url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
            let target=root.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
            guard target.path.hasPrefix(root.path+"/") else{js("MDView.notice('문서 폴더 밖의 링크는 직접 열어 주세요.')");return}
            openDocument(target)
        }else{js("MDView.notice('이 링크 형식은 지원하지 않습니다.')")}
    }
    func webView(_ webView:WKWebView,decidePolicyFor action:WKNavigationAction,decisionHandler:@escaping(WKNavigationActionPolicy)->Void){
        let url=action.request.url
        decisionHandler(action.navigationType == .other && url?.absoluteString == "mdview://bundle/index.html" ? .allow : .cancel)
    }
    func webViewWebContentProcessDidTerminate(_ webView:WKWebView){ready=false;pending=current?.url;web.reload()}
}
