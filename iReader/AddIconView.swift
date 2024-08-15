import SwiftUI

struct AddIconView: View {
    @Binding var iconItems: [IconItem]
    @Binding var newIconName: String
    @Binding var newIconTitle: String
    @Binding var newIconLink: String // New binding for the link
    @Binding var newIconColor: Color
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Icon Name (SF Symbol)", text: $newIconName)
                TextField("Icon Title", text: $newIconTitle)
                TextField("Icon Link", text: $newIconLink) // New text field for the link
                ColorPicker("Icon Color", selection: $newIconColor)
            }
            .navigationBarTitle("Add New Icon", displayMode: .inline)
            .navigationBarItems(trailing: Button("Add") {
                let newItem = IconItem(iconName: newIconName, title: newIconTitle, link: newIconLink, color: newIconColor)
                iconItems.append(newItem)
                newIconName = ""
                newIconTitle = ""
                newIconLink = "" // Reset the link
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
