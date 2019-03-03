import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

enum PeerChannelMemberContextKey: Equatable, Hashable {
    case recent
    case recentSearch(String)
    case admins(String?)
    case restrictedAndBanned(String?)
    case restricted(String?)
    case banned(String?)
    
    var hashValue: Int {
        switch self {
            case .recent:
                return 1
            case let .recentSearch(query):
                return query.hashValue
            case let .admins(query):
                return query?.hashValue ?? 2
            case let .restrictedAndBanned(query):
                return query?.hashValue ?? 3
            case let .restricted(query):
                return query?.hashValue ?? 4
            case let .banned(query):
                return query?.hashValue ?? 5
        }
    }
}

private final class PeerChannelMemberCategoriesContextsManagerImpl {
    fileprivate var contexts: [PeerId: PeerChannelMemberCategoriesContext] = [:]
    
    func getContext(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, key: PeerChannelMemberContextKey, requestUpdate: Bool, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl) {
        if let current = self.contexts[peerId] {
            return current.getContext(key: key, requestUpdate: requestUpdate, updated: updated)
        } else {
            var becameEmptyImpl: ((Bool) -> Void)?
            let context = PeerChannelMemberCategoriesContext(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, becameEmpty: { value in
                becameEmptyImpl?(value)
            })
            becameEmptyImpl = { [weak self, weak context] value in
                assert(Queue.mainQueue().isCurrent())
                if let strongSelf = self {
                    if let current = strongSelf.contexts[peerId], current === context {
                        strongSelf.contexts.removeValue(forKey: peerId)
                    }
                }
            }
            self.contexts[peerId] = context
            return context.getContext(key: key, requestUpdate: requestUpdate, updated: updated)
        }
    }
    
    func loadMore(peerId: PeerId, control: PeerChannelMemberCategoryControl) {
        if let context = self.contexts[peerId] {
            context.loadMore(control)
        }
    }
}

final class PeerChannelMemberCategoriesContextsManager {
    private let impl: QueueLocalObject<PeerChannelMemberCategoriesContextsManagerImpl>
    
    init() {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return PeerChannelMemberCategoriesContextsManagerImpl()
        })
    }
    
    func loadMore(peerId: PeerId, control: PeerChannelMemberCategoryControl?) {
        if let control = control {
            self.impl.with { impl in
                impl.loadMore(peerId: peerId, control: control)
            }
        }
    }
    
    private func getContext(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, key: PeerChannelMemberContextKey, requestUpdate: Bool, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        assert(Queue.mainQueue().isCurrent())
        if let (disposable, control) = self.impl.syncWith({ impl in
            return impl.getContext(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, key: key, requestUpdate: requestUpdate, updated: updated)
        }) {
            return (disposable, control)
        } else {
            return (EmptyDisposable, nil)
        }
    }
    
    func externallyAdded(peerId: PeerId, participant: RenderedChannelParticipant) {
        self.impl.with { impl in
            for (contextPeerId, context) in impl.contexts {
                if contextPeerId == peerId {
                    context.replayUpdates([(nil, participant, nil)])
                }
            }
        }
    }
    
    func recent(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, searchQuery: String? = nil, requestUpdate: Bool = true, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        let key: PeerChannelMemberContextKey
        if let searchQuery = searchQuery {
            key = .recentSearch(searchQuery)
        } else {
            key = .recent
        }
        return self.getContext(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, key: key, requestUpdate: requestUpdate, updated: updated)
    }
    
    func recentOnline(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId) -> Signal<Int32, NoError> {
        return Signal { [weak self] subscriber in
            var previousIds: Set<PeerId>?
            let statusesDisposable = MetaDisposable()
            let disposableAndControl = self?.recent(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, updated: { state in
                var idList: [PeerId] = []
                for item in state.list {
                    idList.append(item.peer.id)
                    if idList.count >= 200 {
                        break
                    }
                }
                let updatedIds = Set(idList)
                if previousIds != updatedIds {
                    previousIds = updatedIds
                    let key: PostboxViewKey = .peerPresences(peerIds: updatedIds)
                    statusesDisposable.set((postbox.combinedView(keys: [key])
                    |> map { view -> Int32 in
                        var count: Int32 = 0
                        let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                        if let presences = (view.views[key] as? PeerPresencesView)?.presences {
                            for (_, presence) in presences {
                                if let presence = presence as? TelegramUserPresence {
                                    let relativeStatus = relativeUserPresenceStatus(presence, relativeTo: Int32(timestamp))
                                    switch relativeStatus {
                                        case .online:
                                            count += 1
                                        default:
                                            break
                                    }
                                }
                            }
                        }
                        return count
                    }
                    |> distinctUntilChanged
                    |> deliverOnMainQueue).start(next: { count in
                        subscriber.putNext(count)
                    }))
                }
            })
            return ActionDisposable {
                disposableAndControl?.0.dispose()
                statusesDisposable.dispose()
            }
        }
        |> runOn(Queue.mainQueue())
        
    }
    
    func admins(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, searchQuery: String? = nil, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, key: .admins(searchQuery), requestUpdate: true, updated: updated)
    }
    
    func restricted(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, searchQuery: String? = nil, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, key: .restricted(searchQuery), requestUpdate: true, updated: updated)
    }
    
    func banned(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, searchQuery: String? = nil, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, key: .banned(searchQuery), requestUpdate: true, updated: updated)
    }
    
    func restrictedAndBanned(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, searchQuery: String? = nil, updated: @escaping (ChannelMemberListState) -> Void) -> (Disposable, PeerChannelMemberCategoryControl?) {
        return self.getContext(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId, key: .restrictedAndBanned(searchQuery), requestUpdate: true, updated: updated)
    }
    
    func updateMemberBannedRights(account: Account, peerId: PeerId, memberId: PeerId, bannedRights: TelegramChatBannedRights?) -> Signal<Void, NoError> {
        return updateChannelMemberBannedRights(account: account, peerId: peerId, memberId: memberId, rights: bannedRights)
        |> deliverOnMainQueue
        |> beforeNext { [weak self] (previous, updated, isMember) in
            if let strongSelf = self {
                strongSelf.impl.with { impl in
                    for (contextPeerId, context) in impl.contexts {
                        if peerId == contextPeerId {
                            context.replayUpdates([(previous, updated, isMember)])
                        }
                    }
                }
            }
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
    }
    
    func updateMemberAdminRights(account: Account, peerId: PeerId, memberId: PeerId, adminRights: TelegramChatAdminRights) -> Signal<Void, NoError> {
        return updateChannelAdminRights(account: account, peerId: peerId, adminId: memberId, rights: adminRights)
        |> map(Optional.init)
        |> `catch` { _ -> Signal<(ChannelParticipant?, RenderedChannelParticipant)?, NoError> in
            return .single(nil)
        }
        |> deliverOnMainQueue
        |> beforeNext { [weak self] result in
            if let strongSelf = self, let (previous, updated) = result {
                strongSelf.impl.with { impl in
                    for (contextPeerId, context) in impl.contexts {
                        if peerId == contextPeerId {
                            context.replayUpdates([(previous, updated, nil)])
                        }
                    }
                }
            }
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
    }
    
    func addMember(account: Account, peerId: PeerId, memberId: PeerId) -> Signal<Void, NoError> {
        return addChannelMember(account: account, peerId: peerId, memberId: memberId)
        |> map(Optional.init)
        |> `catch` { _ -> Signal<(ChannelParticipant?, RenderedChannelParticipant)?, NoError> in
            return .single(nil)
        }
        |> deliverOnMainQueue
        |> beforeNext { [weak self] result in
            if let strongSelf = self, let (previous, updated) = result {
                strongSelf.impl.with { impl in
                    for (contextPeerId, context) in impl.contexts {
                        if peerId == contextPeerId {
                            context.replayUpdates([(previous, updated, nil)])
                        }
                    }
                }
            }
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
    }
    
    func addMembers(account: Account, peerId: PeerId, memberIds: [PeerId]) -> Signal<Void, AddChannelMemberError> {
        let signals: [Signal<(ChannelParticipant?, RenderedChannelParticipant)?, AddChannelMemberError>] = memberIds.map({ memberId in
            return addChannelMember(account: account, peerId: peerId, memberId: memberId)
            |> map(Optional.init)
            |> `catch` { error -> Signal<(ChannelParticipant?, RenderedChannelParticipant)?, AddChannelMemberError> in
                return .fail(error)
            }
        })
        return combineLatest(signals)
        |> deliverOnMainQueue
        |> beforeNext { [weak self] results in
            if let strongSelf = self {
                strongSelf.impl.with { impl in
                    for result in results {
                        if let (previous, updated) = result {
                            for (contextPeerId, context) in impl.contexts {
                                if peerId == contextPeerId {
                                    context.replayUpdates([(previous, updated, nil)])
                                }
                            }
                        }
                    }
                }
            }
        }
        |> mapToSignal { _ -> Signal<Void, AddChannelMemberError> in
            return .complete()
        }
        
        /*return addChannelMembers(account: account, peerId: peerId, memberIds: memberIds)
        |> deliverOnMainQueue
        |> beforeNext { [weak self] result in
            if let strongSelf = self {
                strongSelf.impl.with { impl in
                    for (contextPeerId, context) in impl.contexts {
                        if peerId == contextPeerId {
                            context.reset(.recent)
                        }
                    }
                }
            }
        }
        |> mapToSignal { _ -> Signal<Void, AddChannelMemberError> in
            return .single(Void())
        }*/
    }
}
