import Model
import SwiftUI

struct Toolbar: View {
    @Environment(\.appDependencies) private var appDependencies
    @Environment(\.canGoBack) private var canGoBack
    @Environment(\.canGoForward) private var canGoForward
    @ScaledMetric private var imageSize = 40
    var store: Browser

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color(.border))
            HStack {
                Button {
                    Task {
                        await store.send(.goBackButtonTapped)
                    }
                } label: {
                    Label {
                        Text("goBack", bundle: .module)
                    } icon: {
                        Image(systemName: "chevron.backward")
                            .imageScale(.large)
                            .frame(width: imageSize, height: imageSize)
                    }
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .disabled(!canGoBack)
                .accessibilityIdentifier("goBackButton")
                Button {
                    Task {
                        await store.send(.goForwardButtonTapped)
                    }
                } label: {
                    Label {
                        Text("goForward", bundle: .module)
                    } icon: {
                        Image(systemName: "chevron.forward")
                            .imageScale(.large)
                            .frame(width: imageSize, height: imageSize)
                    }
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .disabled(!canGoForward)
                .accessibilityIdentifier("goForwardButton")
                Spacer()
                // Popup Kill toggle button - blocks popups when enabled
                Button {
                    Task {
                        await store.send(.popupKillToggleTapped)
                    }
                } label: {
                    Label {
                        Text("Popup Kill", bundle: .module)
                    } icon: {
                        Image(systemName: store.isPopupKillEnabled ? "hand.raised.fill" : "hand.raised")
                            .imageScale(.large)
                            .frame(width: imageSize, height: imageSize)
                            .foregroundColor(store.isPopupKillEnabled ? .red : .primary)
                    }
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("popupKillButton")
                // Restore last blocked popup button - only shown when there's a blocked popup
                if store.lastBlockedPopupURL != nil {
                    Button {
                        Task {
                            await store.send(.restoreLastBlockedPopupTapped)
                        }
                    } label: {
                        Label {
                            Text("Restore Popup", bundle: .module)
                        } icon: {
                            Image(systemName: "arrow.uturn.backward")
                                .imageScale(.large)
                                .frame(width: imageSize, height: imageSize)
                        }
                        .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("restorePopupButton")
                }
                Button {
                    Task {
                        await store.send(.bookmarkButtonTapped(appDependencies))
                    }
                } label: {
                    Label {
                        Text("openBookmarks", bundle: .module)
                    } icon: {
                        Image(systemName: "book")
                            .imageScale(.large)
                            .frame(width: imageSize, height: imageSize)
                    }
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("openBookmarksButton")
                Button {
                    Task {
                        await store.send(.hideToolbarButtonTapped)
                    }
                } label: {
                    Label {
                        Text("hideToolbar", bundle: .module)
                    } icon: {
                        Image(systemName: "chevron.down")
                            .imageScale(.large)
                            .frame(width: imageSize, height: imageSize)
                    }
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("hideToolbarButton")
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color(.footer))
        }
    }
}

#Preview {
    Toolbar(store: .init(.testDependencies()))
}
