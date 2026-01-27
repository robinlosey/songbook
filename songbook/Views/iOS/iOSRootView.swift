//
//  iOSRootView.swift
//  songbook
//
//  iPhone root view with NavigationStack.
//

import SwiftUI

struct iOSRootView: View {
    @AppStorage("appearance") private var appearance = "system"
    @StateObject var viewModel: CategoryListViewModel
    @State private var showSettings = false

    var body: some View {
        ZStack {
            MeshBackground()

            NavigationStack {
                iOSCategoryListView(viewModel: viewModel, showSettings: $showSettings)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

#Preview {
    iOSRootView(viewModel: PreviewCategoryListViewModel())
        .environment(\.managedObjectContext, DataManager.preview.container.viewContext)
        .environment(SyncManager.shared)
}
