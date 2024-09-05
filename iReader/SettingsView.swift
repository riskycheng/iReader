import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Account")) {
                    Text("Profile")
                    Text("Notifications")
                }
                Section(header: Text("App Settings")) {
                    Text("Theme")
                    Text("Reading Preferences")
                }
                Section(header: Text("About")) {
                    Text("Version")
                    Text("Privacy Policy")
                }
            }
            .navigationTitle("设置")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
