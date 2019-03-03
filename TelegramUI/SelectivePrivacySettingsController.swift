import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

enum SelectivePrivacySettingsKind {
    case presence
    case groupInvitations
    case voiceCalls
}

private enum SelectivePrivacySettingType {
    case everybody
    case contacts
    case nobody
    
    init(_ setting: SelectivePrivacySettings) {
        switch setting {
            case .disableEveryone:
                self = .nobody
            case .enableContacts:
                self = .contacts
            case .enableEveryone:
                self = .everybody
        }
    }
}

enum SelectivePrivacySettingsPeerTarget {
    case main
    case callP2P
}

private final class SelectivePrivacySettingsControllerArguments {
    let account: Account
    
    let updateType: (SelectivePrivacySettingType) -> Void
    let openEnableFor: (SelectivePrivacySettingsPeerTarget) -> Void
    let openDisableFor: (SelectivePrivacySettingsPeerTarget) -> Void
    
    let updateCallP2PMode: ((SelectivePrivacySettingType) -> Void)?
    let updateCallIntegrationEnabled: ((Bool) -> Void)?
    
    init(account: Account, updateType: @escaping (SelectivePrivacySettingType) -> Void, openEnableFor: @escaping (SelectivePrivacySettingsPeerTarget) -> Void, openDisableFor: @escaping (SelectivePrivacySettingsPeerTarget) -> Void, updateCallP2PMode: ((SelectivePrivacySettingType) -> Void)?, updateCallIntegrationEnabled: ((Bool) -> Void)?) {
        self.account = account
        self.updateType = updateType
        self.openEnableFor = openEnableFor
        self.openDisableFor = openDisableFor
        
        self.updateCallP2PMode = updateCallP2PMode
        self.updateCallIntegrationEnabled = updateCallIntegrationEnabled
    }
}

private enum SelectivePrivacySettingsSection: Int32 {
    case setting
    case peers
    case callsP2P
    case callsP2PPeers
    case callsIntegrationEnabled
}

private func stringForUserCount(_ count: Int, strings: PresentationStrings) -> String {
    if count == 0 {
        return strings.PrivacyLastSeenSettings_EmpryUsersPlaceholder
    } else {
        return strings.UserCount(Int32(count))
    }
}

private enum SelectivePrivacySettingsEntry: ItemListNodeEntry {
    case settingHeader(PresentationTheme, String)
    case everybody(PresentationTheme, String, Bool)
    case contacts(PresentationTheme, String, Bool)
    case nobody(PresentationTheme, String, Bool)
    case settingInfo(PresentationTheme, String)
    case disableFor(PresentationTheme, String, String)
    case enableFor(PresentationTheme, String, String)
    case peersInfo(PresentationTheme, String)
    case callsP2PHeader(PresentationTheme, String)
    case callsP2PAlways(PresentationTheme, String, Bool)
    case callsP2PContacts(PresentationTheme, String, Bool)
    case callsP2PNever(PresentationTheme, String, Bool)
    case callsP2PInfo(PresentationTheme, String)
    case callsP2PDisableFor(PresentationTheme, String, String)
    case callsP2PEnableFor(PresentationTheme, String, String)
    case callsP2PPeersInfo(PresentationTheme, String)
    case callsIntegrationEnabled(PresentationTheme, String, Bool)
    case callsIntegrationInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .settingHeader, .everybody, .contacts, .nobody, .settingInfo:
                return SelectivePrivacySettingsSection.setting.rawValue
            case .disableFor, .enableFor, .peersInfo:
                return SelectivePrivacySettingsSection.peers.rawValue
            case .callsP2PHeader, .callsP2PAlways, .callsP2PContacts, .callsP2PNever, .callsP2PInfo:
                return SelectivePrivacySettingsSection.callsP2P.rawValue
            case .callsP2PDisableFor, .callsP2PEnableFor, .callsP2PPeersInfo:
                return SelectivePrivacySettingsSection.callsP2PPeers.rawValue
            case .callsIntegrationEnabled, .callsIntegrationInfo:
                return SelectivePrivacySettingsSection.callsIntegrationEnabled.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .settingHeader:
                return 0
            case .everybody:
                return 1
            case .contacts:
                return 2
            case .nobody:
                return 3
            case .settingInfo:
                return 4
            case .disableFor:
                return 5
            case .enableFor:
                return 6
            case .peersInfo:
                return 7
            case .callsP2PHeader:
                return 8
            case .callsP2PAlways:
                return 9
            case .callsP2PContacts:
                return 10
            case .callsP2PNever:
                return 11
            case .callsP2PInfo:
                return 12
            case .callsP2PDisableFor:
                return 13
            case .callsP2PEnableFor:
                return 14
            case .callsP2PPeersInfo:
                return 15
            case .callsIntegrationEnabled:
                return 16
            case .callsIntegrationInfo:
                return 17
        }
    }
    
    static func ==(lhs: SelectivePrivacySettingsEntry, rhs: SelectivePrivacySettingsEntry) -> Bool {
        switch lhs {
            case let .settingHeader(lhsTheme, lhsText):
                if case let .settingHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .everybody(lhsTheme, lhsText, lhsValue):
                if case let .everybody(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .contacts(lhsTheme, lhsText, lhsValue):
                if case let .contacts(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .nobody(lhsTheme, lhsText, lhsValue):
                if case let nobody(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .settingInfo(lhsTheme, lhsText):
                if case let .settingInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .disableFor(lhsTheme, lhsText, lhsValue):
                if case let .disableFor(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .enableFor(lhsTheme, lhsText, lhsValue):
                if case let .enableFor(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .peersInfo(lhsTheme, lhsText):
                if case let .peersInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .callsP2PHeader(lhsTheme, lhsText):
                if case let .callsP2PHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .callsP2PInfo(lhsTheme, lhsText):
                if case let .callsP2PInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .callsP2PAlways(lhsTheme, lhsText, lhsValue):
                if case let .callsP2PAlways(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .callsP2PContacts(lhsTheme, lhsText, lhsValue):
                if case let .callsP2PContacts(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .callsP2PNever(lhsTheme, lhsText, lhsValue):
                if case let .callsP2PNever(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .callsP2PDisableFor(lhsTheme, lhsText, lhsValue):
                if case let .callsP2PDisableFor(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .callsP2PEnableFor(lhsTheme, lhsText, lhsValue):
                if case let .callsP2PEnableFor(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .callsP2PPeersInfo(lhsTheme, lhsText):
                if case let .callsP2PPeersInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .callsIntegrationEnabled(lhsTheme, lhsText, lhsValue):
                if case let .callsIntegrationEnabled(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .callsIntegrationInfo(lhsTheme, lhsText):
                if case let .callsIntegrationInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: SelectivePrivacySettingsEntry, rhs: SelectivePrivacySettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: SelectivePrivacySettingsControllerArguments) -> ListViewItem {
        switch self {
            case let .settingHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .everybody(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateType(.everybody)
                })
            case let .contacts(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateType(.contacts)
                })
            case let .nobody(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateType(.nobody)
                })
            case let .settingInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .disableFor(theme, title, value):
                return ItemListDisclosureItem(theme: theme, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openDisableFor(.main)
                })
            case let .enableFor(theme, title, value):
                return ItemListDisclosureItem(theme: theme, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openEnableFor(.main)
                })
            case let .peersInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .callsP2PHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .callsP2PAlways(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateCallP2PMode?(.everybody)
                })
            case let .callsP2PContacts(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateCallP2PMode?(.contacts)
                })
            case let .callsP2PNever(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateCallP2PMode?(.nobody)
                })
            case let .callsP2PInfo(theme, text):
                    return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .callsP2PDisableFor(theme, title, value):
                return ItemListDisclosureItem(theme: theme, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openDisableFor(.callP2P)
                })
            case let .callsP2PEnableFor(theme, title, value):
                return ItemListDisclosureItem(theme: theme, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.openEnableFor(.callP2P)
                })
            case let .callsP2PPeersInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .callsIntegrationEnabled(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updateCallIntegrationEnabled?(value)
                })
            case let .callsIntegrationInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct SelectivePrivacySettingsControllerState: Equatable {
    let setting: SelectivePrivacySettingType
    let enableFor: Set<PeerId>
    let disableFor: Set<PeerId>
    
    let saving: Bool
    
    let callDataSaving: VoiceCallDataSaving?
    let callP2PMode: SelectivePrivacySettingType?
    let callP2PEnableFor: Set<PeerId>?
    let callP2PDisableFor: Set<PeerId>?
    let callIntegrationAvailable: Bool?
    let callIntegrationEnabled: Bool?
    
    init(setting: SelectivePrivacySettingType, enableFor: Set<PeerId>, disableFor: Set<PeerId>, saving: Bool, callDataSaving: VoiceCallDataSaving?, callP2PMode: SelectivePrivacySettingType?, callP2PEnableFor: Set<PeerId>?, callP2PDisableFor: Set<PeerId>?, callIntegrationAvailable: Bool?, callIntegrationEnabled: Bool?) {
        self.setting = setting
        self.enableFor = enableFor
        self.disableFor = disableFor
        self.saving = saving
        self.callDataSaving = callDataSaving
        self.callP2PMode = callP2PMode
        self.callP2PEnableFor = callP2PEnableFor
        self.callP2PDisableFor = callP2PDisableFor
        self.callIntegrationAvailable = callIntegrationAvailable
        self.callIntegrationEnabled = callIntegrationEnabled
    }
    
    static func ==(lhs: SelectivePrivacySettingsControllerState, rhs: SelectivePrivacySettingsControllerState) -> Bool {
        if lhs.setting != rhs.setting {
            return false
        }
        if lhs.enableFor != rhs.enableFor {
            return false
        }
        if lhs.disableFor != rhs.disableFor {
            return false
        }
        if lhs.saving != rhs.saving {
            return false
        }
        if lhs.callDataSaving != rhs.callDataSaving {
            return false
        }
        if lhs.callP2PMode != rhs.callP2PMode {
            return false
        }
        if lhs.callP2PEnableFor != rhs.callP2PEnableFor {
            return false
        }
        if lhs.callP2PDisableFor != rhs.callP2PDisableFor {
            return false
        }
        if lhs.callIntegrationAvailable != rhs.callIntegrationAvailable {
            return false
        }
        if lhs.callIntegrationEnabled != rhs.callIntegrationEnabled {
            return false
        }
        
        return true
    }
    
    func withUpdatedSetting(_ setting: SelectivePrivacySettingType) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: self.saving, callDataSaving: self.callDataSaving, callP2PMode: self.callP2PMode, callP2PEnableFor: self.callP2PEnableFor, callP2PDisableFor: self.callP2PDisableFor, callIntegrationAvailable: self.callIntegrationAvailable, callIntegrationEnabled: self.callIntegrationEnabled)
    }
    
    func withUpdatedEnableFor(_ enableFor: Set<PeerId>) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: enableFor, disableFor: self.disableFor, saving: self.saving, callDataSaving: self.callDataSaving, callP2PMode: self.callP2PMode, callP2PEnableFor: self.callP2PEnableFor, callP2PDisableFor: self.callP2PDisableFor, callIntegrationAvailable: self.callIntegrationAvailable, callIntegrationEnabled: self.callIntegrationEnabled)
    }
    
    func withUpdatedDisableFor(_ disableFor: Set<PeerId>) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: disableFor, saving: self.saving, callDataSaving: self.callDataSaving, callP2PMode: self.callP2PMode, callP2PEnableFor: self.callP2PEnableFor, callP2PDisableFor: self.callP2PDisableFor, callIntegrationAvailable: self.callIntegrationAvailable, callIntegrationEnabled: self.callIntegrationEnabled)
    }
    
    func withUpdatedSaving(_ saving: Bool) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: saving, callDataSaving: self.callDataSaving, callP2PMode: self.callP2PMode, callP2PEnableFor: self.callP2PEnableFor, callP2PDisableFor: self.callP2PDisableFor, callIntegrationAvailable: self.callIntegrationAvailable, callIntegrationEnabled: self.callIntegrationEnabled)
    }
    
    func withUpdatedCallP2PMode(_ mode: SelectivePrivacySettingType) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: self.saving, callDataSaving: self.callDataSaving, callP2PMode: mode, callP2PEnableFor: self.callP2PEnableFor, callP2PDisableFor: self.callP2PDisableFor, callIntegrationAvailable: self.callIntegrationAvailable, callIntegrationEnabled: self.callIntegrationEnabled)
    }
    
    func withUpdatedCallP2PEnableFor(_ enableFor: Set<PeerId>) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: self.saving, callDataSaving: self.callDataSaving, callP2PMode: self.callP2PMode, callP2PEnableFor: enableFor, callP2PDisableFor: self.callP2PDisableFor, callIntegrationAvailable: self.callIntegrationAvailable, callIntegrationEnabled: self.callIntegrationEnabled)
    }
    
    func withUpdatedCallP2PDisableFor(_ disableFor: Set<PeerId>) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: self.saving, callDataSaving: self.callDataSaving, callP2PMode: self.callP2PMode, callP2PEnableFor: self.callP2PEnableFor, callP2PDisableFor: disableFor, callIntegrationAvailable: self.callIntegrationAvailable, callIntegrationEnabled: self.callIntegrationEnabled)
    }
    
    func withUpdatedCallsIntegrationEnabled(_ enabled: Bool) -> SelectivePrivacySettingsControllerState {
        return SelectivePrivacySettingsControllerState(setting: self.setting, enableFor: self.enableFor, disableFor: self.disableFor, saving: self.saving, callDataSaving: self.callDataSaving, callP2PMode: self.callP2PMode, callP2PEnableFor: self.callP2PEnableFor, callP2PDisableFor: self.callP2PDisableFor, callIntegrationAvailable: self.callIntegrationAvailable, callIntegrationEnabled: enabled)
    }
}

private func selectivePrivacySettingsControllerEntries(presentationData: PresentationData, kind: SelectivePrivacySettingsKind, state: SelectivePrivacySettingsControllerState) -> [SelectivePrivacySettingsEntry] {
    var entries: [SelectivePrivacySettingsEntry] = []
    
    let settingTitle: String
    let settingInfoText: String
    let disableForText: String
    let enableForText: String
    switch kind {
        case .presence:
            settingTitle = presentationData.strings.PrivacyLastSeenSettings_WhoCanSeeMyTimestamp
            settingInfoText = presentationData.strings.PrivacyLastSeenSettings_CustomHelp
            disableForText = presentationData.strings.PrivacyLastSeenSettings_NeverShareWith
            enableForText = presentationData.strings.PrivacyLastSeenSettings_AlwaysShareWith
        case .groupInvitations:
            settingTitle = presentationData.strings.Privacy_GroupsAndChannels_WhoCanAddMe
            settingInfoText = presentationData.strings.Privacy_GroupsAndChannels_CustomHelp
            disableForText = presentationData.strings.Privacy_GroupsAndChannels_NeverAllow
            enableForText = presentationData.strings.Privacy_GroupsAndChannels_AlwaysAllow
        case .voiceCalls:
            settingTitle = presentationData.strings.Privacy_Calls_WhoCanCallMe
            settingInfoText = presentationData.strings.Privacy_Calls_CustomHelp
            disableForText = presentationData.strings.Privacy_GroupsAndChannels_NeverAllow
            enableForText = presentationData.strings.Privacy_GroupsAndChannels_AlwaysAllow
    }
    
    entries.append(.settingHeader(presentationData.theme, settingTitle))
    
    entries.append(.everybody(presentationData.theme, presentationData.strings.PrivacySettings_LastSeenEverybody, state.setting == .everybody))
    entries.append(.contacts(presentationData.theme, presentationData.strings.PrivacySettings_LastSeenContacts, state.setting == .contacts))
    switch kind {
        case .presence, .voiceCalls:
            entries.append(.nobody(presentationData.theme, presentationData.strings.PrivacySettings_LastSeenNobody, state.setting == .nobody))
        case .groupInvitations:
            break
    }
    entries.append(.settingInfo(presentationData.theme, settingInfoText))
    
    switch state.setting {
        case .everybody:
            entries.append(.disableFor(presentationData.theme, disableForText, stringForUserCount(state.disableFor.count, strings: presentationData.strings)))
        case .contacts:
            entries.append(.disableFor(presentationData.theme, disableForText, stringForUserCount(state.disableFor.count, strings: presentationData.strings)))
            entries.append(.enableFor(presentationData.theme, enableForText, stringForUserCount(state.enableFor.count, strings: presentationData.strings)))
        case .nobody:
            entries.append(.enableFor(presentationData.theme, enableForText, stringForUserCount(state.enableFor.count, strings: presentationData.strings)))
    }
    entries.append(.peersInfo(presentationData.theme, presentationData.strings.PrivacyLastSeenSettings_CustomShareSettingsHelp))
    
    if case .voiceCalls = kind, let p2pMode = state.callP2PMode, let integrationAvailable = state.callIntegrationAvailable, let integrationEnabled = state.callIntegrationEnabled  {
        entries.append(.callsP2PHeader(presentationData.theme, presentationData.strings.Privacy_Calls_P2P.uppercased()))
        
        entries.append(.callsP2PAlways(presentationData.theme, presentationData.strings.Privacy_Calls_P2PAlways, p2pMode == .everybody))
        entries.append(.callsP2PContacts(presentationData.theme, presentationData.strings.Privacy_Calls_P2PContacts, p2pMode == .contacts))
        entries.append(.callsP2PNever(presentationData.theme, presentationData.strings.Privacy_Calls_P2PNever, p2pMode == .nobody))
        entries.append(.callsP2PInfo(presentationData.theme, presentationData.strings.Privacy_Calls_P2PHelp))
        
        if let callP2PMode = state.callP2PMode, let disableFor = state.callP2PDisableFor, let enableFor = state.callP2PEnableFor {
            switch callP2PMode {
                case .everybody:
                    entries.append(.callsP2PDisableFor(presentationData.theme, disableForText, stringForUserCount(disableFor.count, strings: presentationData.strings)))
                case .contacts:
                    entries.append(.callsP2PDisableFor(presentationData.theme, disableForText, stringForUserCount(disableFor.count, strings: presentationData.strings)))
                    entries.append(.callsP2PEnableFor(presentationData.theme, enableForText, stringForUserCount(enableFor.count, strings: presentationData.strings)))
                case .nobody:
                    entries.append(.callsP2PEnableFor(presentationData.theme, enableForText, stringForUserCount(enableFor.count, strings: presentationData.strings)))
            }
        }
        entries.append(.callsP2PPeersInfo(presentationData.theme, presentationData.strings.PrivacyLastSeenSettings_CustomShareSettingsHelp))
        
        if integrationAvailable {
            entries.append(.callsIntegrationEnabled(presentationData.theme, presentationData.strings.Privacy_Calls_Integration, integrationEnabled))
            entries.append(.callsIntegrationInfo(presentationData.theme, presentationData.strings.Privacy_Calls_IntegrationHelp))
        }
    }
    
    return entries
}

func selectivePrivacySettingsController(context: AccountContext, kind: SelectivePrivacySettingsKind, current: SelectivePrivacySettings, callSettings: (SelectivePrivacySettings, VoiceCallSettings)? = nil, voipConfiguration: VoipConfiguration? = nil, callIntegrationAvailable: Bool? = nil, updated: @escaping (SelectivePrivacySettings, (SelectivePrivacySettings, VoiceCallSettings)?) -> Void) -> ViewController {
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    
    var initialEnableFor = Set<PeerId>()
    var initialDisableFor = Set<PeerId>()
    switch current {
        case let .disableEveryone(enableFor):
            initialEnableFor = enableFor
        case let .enableContacts(enableFor, disableFor):
            initialEnableFor = enableFor
            initialDisableFor = disableFor
        case let .enableEveryone(disableFor):
            initialDisableFor = disableFor
    }
    var initialCallP2PEnableFor: Set<PeerId>?
    var initialCallP2PDisableFor: Set<PeerId>?
    if let callCurrent = callSettings?.0 {
        switch callCurrent {
            case let .disableEveryone(enableFor):
                initialCallP2PEnableFor = enableFor
                initialCallP2PDisableFor = Set<PeerId>()
            case let .enableContacts(enableFor, disableFor):
                initialCallP2PEnableFor = enableFor
                initialCallP2PDisableFor = disableFor
            case let .enableEveryone(disableFor):
                initialCallP2PEnableFor = Set<PeerId>()
                initialCallP2PDisableFor = disableFor
        }
    }
    
    let initialState = SelectivePrivacySettingsControllerState(setting: SelectivePrivacySettingType(current), enableFor: initialEnableFor, disableFor: initialDisableFor, saving: false, callDataSaving: callSettings?.1.dataSaving, callP2PMode: callSettings != nil ? SelectivePrivacySettingType(callSettings!.0) : nil, callP2PEnableFor: initialCallP2PEnableFor, callP2PDisableFor: initialCallP2PDisableFor, callIntegrationAvailable: callIntegrationAvailable, callIntegrationEnabled: callSettings?.1.enableSystemIntegration)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((SelectivePrivacySettingsControllerState) -> SelectivePrivacySettingsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let updateSettingsDisposable = MetaDisposable()
    actionsDisposable.add(updateSettingsDisposable)
    
    let arguments = SelectivePrivacySettingsControllerArguments(account: context.account, updateType: { type in
        updateState {
            $0.withUpdatedSetting(type)
        }
    }, openEnableFor: { target in
        let title: String
        switch kind {
            case .presence:
                title = strings.PrivacyLastSeenSettings_AlwaysShareWith_Title
            case .groupInvitations:
                title = strings.Privacy_GroupsAndChannels_AlwaysAllow_Title
            case .voiceCalls:
                title = strings.Privacy_Calls_AlwaysAllow_Title
        }
        var peerIds = Set<PeerId>()
        updateState { state in
            switch target {
            case .main:
                peerIds = state.enableFor
            case .callP2P:
                if let callP2PEnableFor = state.callP2PEnableFor {
                    peerIds = callP2PEnableFor
                }
            }
            return state
        }
        pushControllerImpl?(selectivePrivacyPeersController(context: context, title: title, initialPeerIds: Array(peerIds), updated: { updatedPeerIds in
            updateState { state in
                switch target {
                    case .main:
                        return state.withUpdatedEnableFor(Set(updatedPeerIds)).withUpdatedDisableFor(state.disableFor.subtracting(Set(updatedPeerIds)))
                    case .callP2P:
                        let callP2PDisableFor = state.callP2PDisableFor ?? Set()
                        return state.withUpdatedCallP2PEnableFor(Set(updatedPeerIds)).withUpdatedCallP2PDisableFor(callP2PDisableFor.subtracting(Set(updatedPeerIds)))
                }
            }
        }))
    }, openDisableFor: { target in
        let title: String
        switch kind {
            case .presence:
                title = strings.PrivacyLastSeenSettings_NeverShareWith_Title
            case .groupInvitations:
                title = strings.Privacy_GroupsAndChannels_NeverAllow_Title
            case .voiceCalls:
                title = strings.Privacy_Calls_NeverAllow_Title
        }
        var peerIds = Set<PeerId>()
        updateState { state in
            switch target {
                case .main:
                    peerIds = state.disableFor
                case .callP2P:
                    if let callP2PDisableFor = state.callP2PDisableFor {
                        peerIds = callP2PDisableFor
                    }
            }
            return state
        }
        pushControllerImpl?(selectivePrivacyPeersController(context: context, title: title, initialPeerIds: Array(peerIds), updated: { updatedPeerIds in
            updateState { state in
                switch target {
                    case .main:
                        return state.withUpdatedDisableFor(Set(updatedPeerIds)).withUpdatedEnableFor(state.enableFor.subtracting(Set(updatedPeerIds)))
                    case .callP2P:
                        let callP2PEnableFor = state.callP2PEnableFor ?? Set()
                        return state.withUpdatedCallP2PDisableFor(Set(updatedPeerIds)).withUpdatedCallP2PEnableFor(callP2PEnableFor.subtracting(Set(updatedPeerIds)))
                }
            }
        }))
    }, updateCallP2PMode: { mode in
        updateState { state in
            return state.withUpdatedCallP2PMode(mode)
        }
    }, updateCallIntegrationEnabled: { enabled in
         updateState { state in
            return state.withUpdatedCallsIntegrationEnabled(enabled)
        }
        let _ = updateVoiceCallSettingsSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.enableSystemIntegration = enabled
            return settings
        }).start()
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get()) |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState<SelectivePrivacySettingsEntry>, SelectivePrivacySettingsEntry.ItemGenerationArguments)) in
            
            let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
            
            let rightNavigationButton: ItemListNavigationButton
            if state.saving {
                rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
            } else {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                    var wasSaving = false
                    var settings: SelectivePrivacySettings?
                    var callP2PSettings: SelectivePrivacySettings?
                    updateState { state in
                        wasSaving = state.saving
                        switch state.setting {
                            case .everybody:
                                settings = SelectivePrivacySettings.enableEveryone(disableFor: state.disableFor)
                            case .contacts:
                                settings = SelectivePrivacySettings.enableContacts(enableFor: state.enableFor, disableFor: state.disableFor)
                            case .nobody:
                                settings = SelectivePrivacySettings.disableEveryone(enableFor: state.enableFor)
                        }
                        
                        if case .voiceCalls = kind, let callP2PMode = state.callP2PMode, let disableFor = state.callP2PDisableFor, let enableFor = state.callP2PEnableFor {
                            switch callP2PMode {
                                case .everybody:
                                    callP2PSettings = SelectivePrivacySettings.enableEveryone(disableFor: disableFor)
                                case .contacts:
                                    callP2PSettings = SelectivePrivacySettings.enableContacts(enableFor: enableFor, disableFor: disableFor)
                                case .nobody:
                                    callP2PSettings = SelectivePrivacySettings.disableEveryone(enableFor: enableFor)
                            }
                        }
                        
                        return state.withUpdatedSaving(true)
                    }
                    
                    if let settings = settings, !wasSaving {
                        let type: UpdateSelectiveAccountPrivacySettingsType
                        switch kind {
                            case .presence:
                                type = .presence
                            case .groupInvitations:
                                type = .groupInvitations
                            case .voiceCalls:
                                type = .voiceCalls
                        }
                        
                        let updateSettingsSignal = updateSelectiveAccountPrivacySettings(account: context.account, type: type, settings: settings)
                        var updateCallP2PSettingsSignal: Signal<Void, NoError> = Signal.complete()
                        if let callP2PSettings = callP2PSettings {
                            updateCallP2PSettingsSignal = updateSelectiveAccountPrivacySettings(account: context.account, type: .voiceCallsP2P, settings: callP2PSettings)
                        }
                        
                        updateSettingsDisposable.set((combineLatest(updateSettingsSignal, updateCallP2PSettingsSignal) |> deliverOnMainQueue).start(completed: {
                            updateState { state in
                                return state.withUpdatedSaving(false)
                            }
                            if case .voiceCalls = kind, let dataSaving = state.callDataSaving, let callP2PSettings = callP2PSettings, let systemIntegrationEnabled = state.callIntegrationEnabled {
                                updated(settings, (callP2PSettings, VoiceCallSettings(dataSaving: dataSaving, enableSystemIntegration: systemIntegrationEnabled)))
                            } else {
                                updated(settings, nil)
                            }
                            dismissImpl?()
                        }))
                    }
                })
            }
            
            let title: String
            switch kind {
                case .presence:
                    title = presentationData.strings.PrivacySettings_LastSeenTitle
                case .groupInvitations:
                    title = presentationData.strings.Privacy_GroupsAndChannels
                case .voiceCalls:
                    title = presentationData.strings.Settings_CallSettings
            }
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(entries: selectivePrivacySettingsControllerEntries(presentationData: presentationData, kind: kind, state: state), style: .blocks, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    dismissImpl = { [weak controller] in
        let _ = (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    
    return controller
}
