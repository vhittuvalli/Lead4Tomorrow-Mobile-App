import SwiftUI

struct CreateAccountView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var phone: String = ""
    @State private var carrier: String = ""
    @State private var method: String = ""
    @State private var time: String = ""
    @State private var timezone: String = ""
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Group {
                    TextField("Enter Email", text: $email)
                    SecureField("Enter Password", text: $password)
                        .textContentType(.oneTimeCode) // disables iOS autofill overlay
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.oneTimeCode)
                    TextField("Phone Number", text: $phone)
                    TextField("Carrier", text: $carrier)
                    TextField("Method (text/email)", text: $method)
                    TextField("Time (e.g., 13:00)", text: $time)
                    TextField("Timezone (e.g., -5)", text: $timezone)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                .autocapitalization(.none)
                .disableAutocorrection(true)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                }

                Button(action: createAccount) {
                    Text("Create Account")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(8)
                }

                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Back to Login")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
        .ignoresSafeArea(.keyboard)
        .navigationBarHidden(true)
    }

    private func createAccount() {
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "All fields are required."
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        let profileData: [String: String] = [
            "email": email,
            "password": password,
            "phone": phone,
            "carrier": carrier,
            "method": method,
            "time": time,
            "timezone": timezone
        ]

        guard let url = URL(string: "https://lead4tomorrow-mobile-app.onrender.com/create_profile") else {
            errorMessage = "Invalid backend URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(profileData)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = "Network error: \(error.localizedDescription)"
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    errorMessage = "Invalid response from server"
                }
                return
            }

            if httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    presentationMode.wrappedValue.dismiss()
                }
            } else {
                if let data = data,
                   let backendMessage = try? JSONDecoder().decode([String: String].self, from: data) {
                    DispatchQueue.main.async {
                        errorMessage = backendMessage["error"] ?? "Failed to create account."
                    }
                } else {
                    DispatchQueue.main.async {
                        errorMessage = "Unknown error occurred."
                    }
                }
            }
        }.resume()
    }
}

