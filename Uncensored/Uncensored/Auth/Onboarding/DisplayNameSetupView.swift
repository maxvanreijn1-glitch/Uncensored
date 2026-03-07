import SwiftUI

struct DisplayNameSetupView: View {
    @State private var displayName: String = ""
    
    var body: some View {
        Form {
            TextField("Display Name", text: $displayName)
              .autocapitalization(.words)
              .disableAutocorrection(true)
            Button("Continue") {
                // Validate display name and save it.
            }
        }
        .navigationTitle("Set Your Display Name")
    }
}

struct DisplayNameSetupView_Previews: PreviewProvider {
    static var previews: some View {
        DisplayNameSetupView()
    }
}