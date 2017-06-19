import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class UserInfoControllerArguments {
    let account: Account
    let avatarAndNameInfoContext: ItemListAvatarAndNameInfoItemContext
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let tapAvatarAction: () -> Void
    let openChat: () -> Void
    let changeNotificationMuteSettings: () -> Void
    let openSharedMedia: () -> Void
    let openGroupsInCommon: () -> Void
    let updatePeerBlocked: (Bool) -> Void
    let deleteContact: () -> Void
    let displayUsernameContextMenu: (String) -> Void
    let call: () -> Void
    
    init(account: Account, avatarAndNameInfoContext: ItemListAvatarAndNameInfoItemContext, updateEditingName: @escaping (ItemListAvatarAndNameInfoItemName) -> Void, tapAvatarAction: @escaping () -> Void, openChat: @escaping () -> Void, changeNotificationMuteSettings: @escaping () -> Void, openSharedMedia: @escaping () -> Void, openGroupsInCommon: @escaping () -> Void, updatePeerBlocked: @escaping (Bool) -> Void, deleteContact: @escaping () -> Void, displayUsernameContextMenu: @escaping (String) -> Void, call: @escaping () -> Void) {
        self.account = account
        self.avatarAndNameInfoContext = avatarAndNameInfoContext
        self.updateEditingName = updateEditingName
        self.tapAvatarAction = tapAvatarAction
        self.openChat = openChat
        self.changeNotificationMuteSettings = changeNotificationMuteSettings
        self.openSharedMedia = openSharedMedia
        self.openGroupsInCommon = openGroupsInCommon
        self.updatePeerBlocked = updatePeerBlocked
        self.deleteContact = deleteContact
        self.displayUsernameContextMenu = displayUsernameContextMenu
        self.call = call
    }
}

private enum UserInfoSection: ItemListSectionId {
    case info
    case actions
    case sharedMediaAndNotifications
    case block
}

private enum UserInfoEntryTag {
    case username
}

private enum UserInfoEntry: ItemListNodeEntry {
    case info(PresentationTheme, PresentationStrings, peer: Peer?, presence: PeerPresence?, cachedData: CachedPeerData?, state: ItemListAvatarAndNameInfoItemState, displayCall: Bool)
    case about(PresentationTheme, String, String)
    case phoneNumber(PresentationTheme, Int, PhoneNumberWithLabel)
    case userName(PresentationTheme, String, String)
    case sendMessage(PresentationTheme, String)
    case shareContact(PresentationTheme, String)
    case startSecretChat(PresentationTheme, String)
    case sharedMedia(PresentationTheme, String)
    case notifications(PresentationTheme, String, String)
    case notificationSound(PresentationTheme, String, String)
    case groupsInCommon(PresentationTheme, String, Int32)
    case secretEncryptionKey(PresentationTheme, String, SecretChatKeyFingerprint)
    case block(PresentationTheme, String, DestructiveUserInfoAction)
    
    var section: ItemListSectionId {
        switch self {
            case .info, .about, .phoneNumber, .userName:
                return UserInfoSection.info.rawValue
            case .sendMessage, .shareContact, .startSecretChat:
                return UserInfoSection.actions.rawValue
            case .sharedMedia, .notifications, .notificationSound, .secretEncryptionKey, .groupsInCommon:
                return UserInfoSection.sharedMediaAndNotifications.rawValue
            case .block:
                return UserInfoSection.block.rawValue
        }
    }
    
    var stableId: Int {
        return self.sortIndex
    }
    
    static func ==(lhs: UserInfoEntry, rhs: UserInfoEntry) -> Bool {
        switch lhs {
            case let .info(lhsTheme, lhsStrings, lhsPeer, lhsPresence, lhsCachedData, lhsState, lhsDisplayCall):
                switch rhs {
                    case let .info(rhsTheme, rhsStrings, rhsPeer, rhsPresence, rhsCachedData, rhsState, rhsDisplayCall):
                        if lhsTheme !== rhsTheme {
                            return false
                        }
                        if lhsStrings !== rhsStrings {
                            return false
                        }
                        if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                            if !lhsPeer.isEqual(rhsPeer) {
                                return false
                            }
                        } else if (lhsPeer != nil) != (rhsPeer != nil) {
                            return false
                        }
                        if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                            if !lhsPresence.isEqual(to: rhsPresence) {
                                return false
                            }
                        } else if (lhsPresence != nil) != (rhsPresence != nil) {
                            return false
                        }
                        if let lhsCachedData = lhsCachedData, let rhsCachedData = rhsCachedData {
                            if !lhsCachedData.isEqual(to: rhsCachedData) {
                                return false
                            }
                        } else if (lhsCachedData != nil) != (rhsCachedData != nil) {
                            return false
                        }
                        if lhsState != rhsState {
                            return false
                        }
                        if lhsDisplayCall != rhsDisplayCall {
                            return false
                        }
                        return true
                    default:
                        return false
                }
            case let .about(lhsTheme, lhsText, lhsValue):
                if case let .about(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .phoneNumber(lhsTheme, lhsIndex, lhsValue):
                if case let .phoneNumber(rhsTheme, rhsIndex, rhsValue) = rhs, lhsTheme === rhsTheme, lhsIndex == rhsIndex, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .userName(lhsTheme, lhsText, lhsValue):
                if case let .userName(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .sendMessage(lhsTheme, lhsText):
                if case let .sendMessage(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .shareContact(lhsTheme, lhsText):
                if case let .shareContact(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .startSecretChat(lhsTheme, lhsText):
                if case let .startSecretChat(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .sharedMedia(lhsTheme, lhsText):
                if case let .sharedMedia(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .notifications(lhsTheme, lhsText, lhsValue):
                if case let .notifications(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .notificationSound(lhsTheme, lhsText, lhsValue):
                if case let .notificationSound(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .groupsInCommon(lhsTheme, lhsText, lhsValue):
                if case let .groupsInCommon(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .secretEncryptionKey(lhsTheme, lhsText, lhsValue):
                if case let .secretEncryptionKey(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .block(lhsTheme, lhsText, lhsAction):
                if case let .block(rhsTheme, rhsText, rhsAction) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsAction == rhsAction {
                    return true
                } else {
                    return false
                }
        }
    }
    
    private var sortIndex: Int {
        switch self {
            case .info:
                return 0
            case .about:
                return 1
            case let .phoneNumber(_, index, _):
                return 2 + index
            case .userName:
                return 1000
            case .sendMessage:
                return 1001
            case .shareContact:
                return 1002
            case .startSecretChat:
                return 1003
            case .sharedMedia:
                return 1004
            case .notifications:
                return 1005
            case .notificationSound:
                return 1006
            case .groupsInCommon:
                return 1007
            case .secretEncryptionKey:
                return 1008
            case .block:
                return 1009
        }
    }
    
    static func <(lhs: UserInfoEntry, rhs: UserInfoEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(_ arguments: UserInfoControllerArguments) -> ListViewItem {
        switch self {
            case let .info(theme, strings, peer, presence, cachedData, state, displayCall):
                return ItemListAvatarAndNameInfoItem(account: arguments.account, theme: theme, strings: strings, peer: peer, presence: presence, cachedData: cachedData, state: state, sectionId: self.section, style: .plain, editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                }, avatarTapped: {
                    arguments.tapAvatarAction()
                }, context: arguments.avatarAndNameInfoContext, call: displayCall ? {
                    arguments.call()
                } : nil)
            case let .about(theme, text, value):
                return ItemListTextWithLabelItem(theme: theme, label: text, text: value, multiline: true, sectionId: self.section, action: nil)
            case let .phoneNumber(theme, _, value):
                return ItemListTextWithLabelItem(theme: theme, label: value.label, text: formatPhoneNumber(value.number), multiline: false, sectionId: self.section, action: {
                    
                })
            case let .userName(theme, text, value):
                return ItemListTextWithLabelItem(theme: theme, label: text, text: "@\(value)", multiline: false, sectionId: self.section, action: {
                    arguments.displayUsernameContextMenu("@" + value)
                }, tag: UserInfoEntryTag.username)
            case let .sendMessage(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.openChat()
                })
            case let .shareContact(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    
                })
            case let .startSecretChat(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    
                })
            case let .sharedMedia(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .plain, action: {
                    arguments.openSharedMedia()
                })
            case let .notifications(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .plain, action: {
                    arguments.changeNotificationMuteSettings()
                })
            case let .notificationSound(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .plain, action: {
                })
            case let .groupsInCommon(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: "\(value)", sectionId: self.section, style: .plain, action: {
                    arguments.openGroupsInCommon()
                })
            case let .secretEncryptionKey(theme, text, fingerprint):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .plain, action: {
                })
            case let .block(theme, text, action):
                return ItemListActionItem(theme: theme, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    switch action {
                        case .block:
                            arguments.updatePeerBlocked(true)
                        case .unblock:
                            arguments.updatePeerBlocked(false)
                        case .removeContact:
                            arguments.deleteContact()
                    }
                })
        }
    }
}

private enum DestructiveUserInfoAction {
    case block
    case removeContact
    case unblock
}

private struct UserInfoEditingState: Equatable {
    let editingName: ItemListAvatarAndNameInfoItemName?
    
    static func ==(lhs: UserInfoEditingState, rhs: UserInfoEditingState) -> Bool {
        if lhs.editingName != rhs.editingName {
            return false
        }
        return true
    }
}

private struct UserInfoState: Equatable {
    let savingData: Bool
    let editingState: UserInfoEditingState?
    
    init() {
        self.savingData = false
        self.editingState = nil
    }
    
    init(savingData: Bool, editingState: UserInfoEditingState?) {
        self.savingData = savingData
        self.editingState = editingState
    }
    
    static func ==(lhs: UserInfoState, rhs: UserInfoState) -> Bool {
        if lhs.savingData != rhs.savingData {
            return false
        }
        if lhs.editingState != rhs.editingState {
            return false
        }
        return true
    }
    
    func withUpdatedSavingData(_ savingData: Bool) -> UserInfoState {
        return UserInfoState(savingData: savingData, editingState: self.editingState)
    }
    
    func withUpdatedEditingState(_ editingState: UserInfoEditingState?) -> UserInfoState {
        return UserInfoState(savingData: self.savingData, editingState: editingState)
    }
}

private func stringForBlockAction(strings: PresentationStrings, action: DestructiveUserInfoAction) -> String {
    switch action {
        case .block:
            return strings.Conversation_BlockUser
        case .unblock:
            return strings.Conversation_UnblockUser
        case .removeContact:
            return strings.UserInfo_DeleteContact
    }
}

private func userInfoEntries(account: Account, presentationData: PresentationData, view: PeerView, state: UserInfoState, peerChatState: Coding?) -> [UserInfoEntry] {
    var entries: [UserInfoEntry] = []
    
    guard let peer = view.peers[view.peerId], let user = peerViewMainPeer(view) as? TelegramUser else {
        return []
    }
    
    var editingName: ItemListAvatarAndNameInfoItemName?
    
    var isEditing = false
    if let editingState = state.editingState {
        isEditing = true
        
        if view.peerIsContact {
            editingName = editingState.editingName
        }
    }
    
    entries.append(UserInfoEntry.info(presentationData.theme, presentationData.strings, peer: user, presence: view.peerPresences[user.id], cachedData: view.cachedData, state: ItemListAvatarAndNameInfoItemState(editingName: editingName, updatingName: nil), displayCall: true))
    if let cachedUserData = view.cachedData as? CachedUserData {
        if let about = cachedUserData.about, !about.isEmpty {
            entries.append(UserInfoEntry.about(presentationData.theme, presentationData.strings.Profile_About, about))
        }
    }
    
    if let phoneNumber = user.phone, !phoneNumber.isEmpty {
        entries.append(UserInfoEntry.phoneNumber(presentationData.theme, 0, PhoneNumberWithLabel(label: "home", number: phoneNumber)))
    }
    
    if !isEditing {
        if let username = user.username, !username.isEmpty {
            entries.append(UserInfoEntry.userName(presentationData.theme, presentationData.strings.Profile_Username, username))
        }
        
        if !(peer is TelegramSecretChat) {
            entries.append(UserInfoEntry.sendMessage(presentationData.theme, presentationData.strings.UserInfo_SendMessage))
            if view.peerIsContact {
                entries.append(UserInfoEntry.shareContact(presentationData.theme, presentationData.strings.UserInfo_ShareContact))
            }
            entries.append(UserInfoEntry.startSecretChat(presentationData.theme, presentationData.strings.UserInfo_StartSecretChat))
        }
        entries.append(UserInfoEntry.sharedMedia(presentationData.theme, presentationData.strings.GroupInfo_SharedMedia))
    }
    let notificationsLabel: String
    if let settings = view.notificationSettings as? TelegramPeerNotificationSettings, case .muted = settings.muteState {
        notificationsLabel = presentationData.strings.UserInfo_NotificationsDisabled
    } else {
        notificationsLabel = presentationData.strings.UserInfo_NotificationsEnabled
    }
    entries.append(UserInfoEntry.notifications(presentationData.theme, presentationData.strings.GroupInfo_Notifications, notificationsLabel))
    if let groupsInCommon = (view.cachedData as? CachedUserData)?.commonGroupCount, groupsInCommon != 0 && !isEditing {
        entries.append(UserInfoEntry.groupsInCommon(presentationData.theme, presentationData.strings.UserInfo_GroupsInCommon, groupsInCommon))
    }
    
    if peer is TelegramSecretChat, let peerChatState = peerChatState as? SecretChatKeyState, let keyFingerprint = peerChatState.keyFingerprint {
        entries.append(UserInfoEntry.secretEncryptionKey(presentationData.theme, presentationData.strings.Profile_EncryptionKey, keyFingerprint))
    }
    
    if isEditing {
        entries.append(UserInfoEntry.notificationSound(presentationData.theme, presentationData.strings.GroupInfo_Sound, "Default"))
        if view.peerIsContact {
            entries.append(UserInfoEntry.block(presentationData.theme, stringForBlockAction(strings: presentationData.strings, action: .removeContact), .removeContact))
        }
    } else {
        if let cachedData = view.cachedData as? CachedUserData {
            if cachedData.isBlocked {
                entries.append(UserInfoEntry.block(presentationData.theme, stringForBlockAction(strings: presentationData.strings, action: .unblock), .unblock))
            } else {
                entries.append(UserInfoEntry.block(presentationData.theme, stringForBlockAction(strings: presentationData.strings, action: .block), .block))
            }
        }
    }
    
    return entries
}

public func userInfoController(account: Account, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(UserInfoState(), ignoreRepeated: true)
    let stateValue = Atomic(value: UserInfoState())
    let updateState: ((UserInfoState) -> UserInfoState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var openChatImpl: (() -> Void)?
    var displayUsernameContextMenuImpl: ((String) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let updatePeerNameDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerNameDisposable)
    
    let updatePeerBlockedDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerBlockedDisposable)
    
    let changeMuteSettingsDisposable = MetaDisposable()
    actionsDisposable.add(changeMuteSettingsDisposable)
    
    let hiddenAvatarRepresentationDisposable = MetaDisposable()
    actionsDisposable.add(hiddenAvatarRepresentationDisposable)
    
    var avatarGalleryTransitionArguments: ((AvatarGalleryEntry) -> GalleryTransitionArguments?)?
    let avatarAndNameInfoContext = ItemListAvatarAndNameInfoItemContext()
    var updateHiddenAvatarImpl: (() -> Void)?
    
    let arguments = UserInfoControllerArguments(account: account, avatarAndNameInfoContext: avatarAndNameInfoContext, updateEditingName: { editingName in
        updateState { state in
            if let _ = state.editingState {
                return state.withUpdatedEditingState(UserInfoEditingState(editingName: editingName))
            } else {
                return state
            }
        }
    }, tapAvatarAction: {
        let _ = (account.postbox.loadedPeerWithId(peerId) |> take(1) |> deliverOnMainQueue).start(next: { peer in
            if peer.profileImageRepresentations.isEmpty {
                return
            }
            
            let galleryController = AvatarGalleryController(account: account, peer: peer, replaceRootController: { controller, ready in
                
            })
            hiddenAvatarRepresentationDisposable.set((galleryController.hiddenMedia |> deliverOnMainQueue).start(next: { entry in
                avatarAndNameInfoContext.hiddenAvatarRepresentation = entry?.representations.first
                updateHiddenAvatarImpl?()
            }))
            presentControllerImpl?(galleryController, AvatarGalleryControllerPresentationArguments(transitionArguments: { entry in
                return avatarGalleryTransitionArguments?(entry)
            }))
        })
    }, openChat: {
        openChatImpl?()
    }, changeNotificationMuteSettings: {
        let controller = ActionSheetController()
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        let notificationAction: (Int32) -> Void = {  muteUntil in
            let muteState: PeerMuteState
            if muteUntil <= 0 {
                muteState = .unmuted
            } else if muteUntil == Int32.max {
                muteState = .muted(until: Int32.max)
            } else {
                muteState = .muted(until: Int32(Date().timeIntervalSince1970) + muteUntil)
            }
            changeMuteSettingsDisposable.set(changePeerNotificationSettings(account: account, peerId: peerId, settings: TelegramPeerNotificationSettings(muteState: muteState, messageSound: PeerMessageSound.bundledModern(id: 0))).start())
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: "Enable", action: {
                    dismissAction()
                    notificationAction(0)
                }),
                ActionSheetButtonItem(title: "Mute for 1 hour", action: {
                    dismissAction()
                    notificationAction(1 * 60 * 60)
                }),
                ActionSheetButtonItem(title: "Mute for 8 hours", action: {
                    dismissAction()
                    notificationAction(8 * 60 * 60)
                }),
                ActionSheetButtonItem(title: "Mute for 2 days", action: {
                    dismissAction()
                    notificationAction(2 * 24 * 60 * 60)
                }),
                ActionSheetButtonItem(title: "Disable", action: {
                    dismissAction()
                    notificationAction(Int32.max)
                })
                ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: "Cancel", action: { dismissAction() })])
            ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, openSharedMedia: {
        if let controller = peerSharedMediaController(account: account, peerId: peerId) {
            pushControllerImpl?(controller)
        }
    }, openGroupsInCommon: {
        pushControllerImpl?(groupsInCommonController(account: account, peerId: peerId))
    }, updatePeerBlocked: { value in
        updatePeerBlockedDisposable.set(requestUpdatePeerIsBlocked(account: account, peerId: peerId, isBlocked: value).start())
    }, deleteContact: {
        
    }, displayUsernameContextMenu: { text in
        displayUsernameContextMenuImpl?(text)
    }, call: {
        let callResult = account.telegramApplicationContext.callManager?.requestCall(peerId: peerId, endCurrentIfAny: false)
        if let callResult = callResult, case let .alreadyInProgress(currentPeerId) = callResult {
            if currentPeerId == peerId {
                account.telegramApplicationContext.navigateToCurrentCall?()
            } else {
                let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                let _ = (account.postbox.modify { modifier -> (Peer?, Peer?) in
                    return (modifier.getPeer(peerId), modifier.getPeer(currentPeerId))
                } |> deliverOnMainQueue).start(next: { peer, current in
                    if let peer = peer, let current = current {
                        presentControllerImpl?(standardTextAlertController(title: presentationData.strings.Call_CallInProgressTitle, text: presentationData.strings.Call_CallInProgressMessage(current.compactDisplayTitle, peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                            let _ = account.telegramApplicationContext.callManager?.requestCall(peerId: peerId, endCurrentIfAny: true)
                        })]), nil)
                    }
                })
            }
        }
    })
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), account.viewTracker.peerView(peerId), account.postbox.combinedView(keys: [.peerChatState(peerId: peerId)]))
        |> map { presentationData, state, view, chatState -> (ItemListControllerState, (ItemListNodeState<UserInfoEntry>, UserInfoEntry.ItemGenerationArguments)) in
            let peer = peerViewMainPeer(view)
            var leftNavigationButton: ItemListNavigationButton?
            let rightNavigationButton: ItemListNavigationButton
            if let editingState = state.editingState {
                leftNavigationButton = ItemListNavigationButton(title: presentationData.strings.Common_Cancel, style: .regular, enabled: true, action: {
                    updateState {
                        $0.withUpdatedEditingState(nil)
                    }
                })
                
                var doneEnabled = true
                if let editingName = editingState.editingName, editingName.isEmpty {
                    doneEnabled = false
                }
                
                if state.savingData {
                    rightNavigationButton = ItemListNavigationButton(title: "", style: .activity, enabled: doneEnabled, action: {})
                } else {
                    rightNavigationButton = ItemListNavigationButton(title: presentationData.strings.Common_Done, style: .bold, enabled: doneEnabled, action: {
                        var updateName: ItemListAvatarAndNameInfoItemName?
                        updateState { state in
                            if let editingState = state.editingState, let editingName = editingState.editingName {
                                if let user = peer {
                                    if ItemListAvatarAndNameInfoItemName(user.indexName) != editingName {
                                        updateName = editingName
                                    }
                                }
                            }
                            if updateName != nil {
                                return state.withUpdatedSavingData(true)
                            } else {
                                return state.withUpdatedEditingState(nil)
                            }
                        }
                        
                        if let updateName = updateName, case let .personName(firstName, lastName) = updateName {
                            updatePeerNameDisposable.set((updateContactName(account: account, peerId: peerId, firstName: firstName, lastName: lastName) |> deliverOnMainQueue).start(error: { _ in
                                updateState { state in
                                    return state.withUpdatedSavingData(false)
                                }
                            }, completed: {
                                updateState { state in
                                    return state.withUpdatedSavingData(false).withUpdatedEditingState(nil)
                                }
                            }))
                        }
                    })
                }
            } else {
                rightNavigationButton = ItemListNavigationButton(title: presentationData.strings.Common_Edit, style: .regular, enabled: true, action: {
                    if let user = peer {
                        updateState { state in
                            return state.withUpdatedEditingState(UserInfoEditingState(editingName: ItemListAvatarAndNameInfoItemName(user.indexName)))
                        }
                    }
                })
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.UserInfo_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: nil)
            let listState = ItemListNodeState(entries: userInfoEntries(account: account, presentationData: presentationData, view: view, state: state, peerChatState: (chatState.views[.peerChatState(peerId: peerId)] as? PeerChatStateView)?.chatState), style: .plain)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(account: account, state: signal)
    
    pushControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.pushViewController(value)
    }
    presentControllerImpl = { [weak controller] value, presentationArguments in
        controller?.present(value, in: .window, with: presentationArguments)
    }
    openChatImpl = { [weak controller] in
        if let navigationController = (controller?.navigationController as? NavigationController) {
            navigateToChatController(navigationController: navigationController, account: account, peerId: peerId)
        }
    }
    displayUsernameContextMenuImpl = { [weak controller] text in
        if let strongController = controller {
            var resultItemNode: ListViewItemNode?
            let _ = strongController.frameForItemNode({ itemNode in
                if let itemNode = itemNode as? ItemListTextWithLabelItemNode {
                    if let tag = itemNode.tag as? UserInfoEntryTag {
                        if tag == .username {
                            resultItemNode = itemNode
                            return true
                        }
                    }
                }
                return false
            })
            if let resultItemNode = resultItemNode {
                let contextMenuController = ContextMenuController(actions: [ContextMenuAction(content: .text("Copy"), action: {
                    UIPasteboard.general.string = text
                })])
                strongController.present(contextMenuController, in: .window, with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak resultItemNode] in
                    if let resultItemNode = resultItemNode {
                        return (resultItemNode, resultItemNode.contentBounds.insetBy(dx: 0.0, dy: -2.0))
                    } else {
                        return nil
                    }
                }))
                
            }
        }
    }
    avatarGalleryTransitionArguments = { [weak controller] entry in
        if let controller = controller {
            var result: (ASDisplayNode, CGRect)?
            controller.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ItemListAvatarAndNameInfoItemNode {
                    result = itemNode.avatarTransitionNode()
                }
            }
            if let (node, _) = result {
                return GalleryTransitionArguments(transitionNode: node, transitionContainerNode: controller.displayNode, transitionBackgroundNode: controller.displayNode)
            }
        }
        return nil
    }
    updateHiddenAvatarImpl = { [weak controller] in
        if let controller = controller {
            controller.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ItemListAvatarAndNameInfoItemNode {
                    itemNode.updateAvatarHidden()
                }
            }
        }
    }
    return controller
}