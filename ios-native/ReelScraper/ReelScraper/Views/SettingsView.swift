import SwiftUI

struct SettingsView: View {
    @State private var apifyToken = Settings.apifyToken ?? ""
    @State private var notionToken = Settings.notionToken ?? ""
    @State private var notionDatabaseID = Settings.notionDatabaseID ?? ""

    @State private var apifyTokenVisible = false
    @State private var notionTokenVisible = false

    @State private var saved = false

    var body: some View {
        Form {
            Section {
                HStack {
                    if apifyTokenVisible {
                        TextField("API Token", text: $apifyToken)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("API Token", text: $apifyToken)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    Button {
                        apifyTokenVisible.toggle()
                    } label: {
                        Image(systemName: apifyTokenVisible ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Apify")
            } footer: {
                Text("Your Apify API token (starts with apify_api_)")
            }

            Section {
                HStack {
                    if notionTokenVisible {
                        TextField("Integration Token", text: $notionToken)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("Integration Token", text: $notionToken)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    Button {
                        notionTokenVisible.toggle()
                    } label: {
                        Image(systemName: notionTokenVisible ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                TextField("Database ID", text: $notionDatabaseID)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Notion")
            } footer: {
                Text("Notion integration token and the ID of your Saved Reels database")
            }

            Section {
                Button {
                    Settings.apifyToken = apifyToken.isEmpty ? nil : apifyToken
                    Settings.notionToken = notionToken.isEmpty ? nil : notionToken
                    Settings.notionDatabaseID = notionDatabaseID.isEmpty ? nil : notionDatabaseID
                    withAnimation {
                        saved = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            saved = false
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if saved {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("Save")
                        }
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
