import SwiftUI

struct ProfileEditorView: View {
    @ObservedObject var store = UserProfileStore.shared
    @Environment(\.dismiss) var dismiss
    @State private var originalProfile: UserProfile?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("Full Name", text: $store.profile.fullName)
                    TextField("Email", text: $store.profile.email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $store.profile.phone)
                        .keyboardType(.phonePad)
                }

                Section(header: Text("Address")) {
                    TextField("Mailing Address", text: $store.profile.address)
                }

                Section {
                    Text("This information is stored locally on your device and used only for the 'Smart Autofill' feature.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Autofill Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if originalProfile == nil {
                    originalProfile = store.profile
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if let originalProfile {
                            store.profile = originalProfile
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        store.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ProfileEditorView()
}
