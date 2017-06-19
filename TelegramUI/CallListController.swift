import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

public final class CallListController: ViewController {
    private var controllerNode: CallListControllerNode {
        return self.displayNode as! CallListControllerNode
    }
    
    private let _ready = Promise<Bool>(false)
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let account: Account
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let segmentedTitleView: ItemListControllerSegmentedTitleView
    
    private var isEmpty: Bool?
    private var editingMode: Bool = false
    
    private let createActionDisposable = MetaDisposable()
    
    public init(account: Account) {
        self.account = account
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        self.segmentedTitleView = ItemListControllerSegmentedTitleView(segments: [self.presentationData.strings.Calls_All, self.presentationData.strings.Calls_Missed], index: 0, color: self.presentationData.theme.rootController.navigationBar.accentTextColor)
        
        super.init(navigationBarTheme: NavigationBarTheme(rootControllerTheme: self.presentationData.theme))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationCallIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.callPressed))
        
        self.tabBarItem.title = self.presentationData.strings.Calls_TabTitle
        self.tabBarItem.image = UIImage(bundleImageName: "Chat List/Tabs/IconCalls")
        self.tabBarItem.selectedImage = UIImage(bundleImageName: "Chat List/Tabs/IconCallsSelected")
        
        self.segmentedTitleView.indexUpdated = { [weak self] index in
            if let strongSelf = self {
                strongSelf.controllerNode.updateType(index == 0 ? .all : .missed)
            }
        }
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    let previousTheme = strongSelf.presentationData.theme
                    let previousStrings = strongSelf.presentationData.strings
                    
                    strongSelf.presentationData = presentationData
                    
                    if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                        strongSelf.updateThemeAndStrings()
                    }
                }
            })
        
        self.scrollToTop = { [weak self] in
            self?.controllerNode.scrollToLatest()
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.createActionDisposable.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.segmentedTitleView.segments = [self.presentationData.strings.Calls_All, self.presentationData.strings.Calls_Missed]
        self.segmentedTitleView.color = self.presentationData.theme.rootController.navigationBar.accentTextColor
        
        if let isEmpty = self.isEmpty, isEmpty {
            self.navigationItem.title = self.presentationData.strings.Calls_TabTitle
        } else {
            if self.editingMode {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
            } else {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
            }
        }
        
        self.tabBarItem.title = self.presentationData.strings.Calls_TabTitle
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationCallIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.callPressed))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.navigationBar?.updateTheme(NavigationBarTheme(rootControllerTheme: self.presentationData.theme))
        
        if self.isNodeLoaded {
            self.controllerNode.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings)
        }
        
    }
    
    override public func loadDisplayNode() {
        self.displayNode = CallListControllerNode(account: self.account, presentationData: self.presentationData, call: { [weak self] peerId in
            if let strongSelf = self {
                strongSelf.call(peerId)
            }
        }, openInfo: { [weak self] peerId in
            if let strongSelf = self {
                let _ = (strongSelf.account.postbox.loadedPeerWithId(peerId)
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { peer in
                        if let strongSelf = self {
                            if let infoController = peerInfoController(account: strongSelf.account, peer: peer) {
                                (strongSelf.navigationController as? NavigationController)?.pushViewController(infoController)
                            }
                        }
                    })
            }
        }, emptyStateUpdated: { [weak self] empty in
            if let strongSelf = self {
                if empty != strongSelf.isEmpty {
                    strongSelf.isEmpty = empty
                    
                    if empty {
                        strongSelf.navigationItem.setLeftBarButton(nil, animated: true)
                        strongSelf.navigationItem.title = strongSelf.presentationData.strings.Calls_TabTitle
                    } else {
                        strongSelf.navigationItem.title = ""
                        strongSelf.navigationItem.titleView = strongSelf.segmentedTitleView
                        if strongSelf.editingMode {
                            strongSelf.navigationItem.leftBarButtonItem = UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Done, style: .done, target: strongSelf, action: #selector(strongSelf.donePressed))
                        } else {
                            strongSelf.navigationItem.leftBarButtonItem = UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Edit, style: .plain, target: strongSelf, action: #selector(strongSelf.editPressed))
                        }
                    }
                }
            }
        })
        self._ready.set(self.controllerNode.ready)
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc func callPressed() {
        let controller = ContactSelectionController(account: self.account, title: { $0.Calls_NewCall })
        self.createActionDisposable.set((controller.result
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak controller, weak self] peerId in
                controller?.dismissSearch()
                if let strongSelf = self, let peerId = peerId {
                    strongSelf.call(peerId, began: {
                        if let strongSelf = self {
                            if let hasOngoingCall = strongSelf.account.telegramApplicationContext.hasOngoingCall {
                                let _ = (hasOngoingCall
                                    |> filter { $0 }
                                    |> timeout(1.0, queue: Queue.mainQueue(), alternate: .single(true))
                                    |> delay(0.5, queue: Queue.mainQueue())
                                    |> deliverOnMainQueue).start(next: { _ in
                                        if let strongSelf = self, let controller = controller, let navigationController = controller.navigationController as? NavigationController {
                                            if navigationController.viewControllers.last === controller {
                                                let _ = navigationController.popViewController(animated: true)
                                            }
                                        }
                                    })
                            }
                        }
                    })
                }
            }))
        (self.navigationController as? NavigationController)?.pushViewController(controller)
    }
    
    @objc func editPressed() {
        self.editingMode = true
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
        
        self.controllerNode.updateState { state in
            return state.withUpdatedEditing(true)
        }
    }
    
    @objc func donePressed() {
        self.editingMode = false
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
        
        self.controllerNode.updateState { state in
            return state.withUpdatedEditing(false)
        }
    }
    
    private func call(_ peerId: PeerId, began: (() -> Void)? = nil) {
        let callResult = self.account.telegramApplicationContext.callManager?.requestCall(peerId: peerId, endCurrentIfAny: false)
        if let callResult = callResult {
            if case let .alreadyInProgress(currentPeerId) = callResult {
                if currentPeerId == peerId {
                    began?()
                    self.account.telegramApplicationContext.navigateToCurrentCall?()
                } else {
                    let presentationData = self.presentationData
                    let _ = (self.account.postbox.modify { modifier -> (Peer?, Peer?) in
                        return (modifier.getPeer(peerId), modifier.getPeer(currentPeerId))
                        } |> deliverOnMainQueue).start(next: { [weak self] peer, current in
                            if let strongSelf = self, let peer = peer, let current = current {
                                strongSelf.present(standardTextAlertController(title: presentationData.strings.Call_CallInProgressTitle, text: presentationData.strings.Call_CallInProgressMessage(current.compactDisplayTitle, peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                                    if let strongSelf = self {
                                        let _ = strongSelf.account.telegramApplicationContext.callManager?.requestCall(peerId: peerId, endCurrentIfAny: true)
                                        began?()
                                    }
                                })]), in: .window)
                            }
                        })
                }
            } else {
                began?()
            }
        }
    }
}