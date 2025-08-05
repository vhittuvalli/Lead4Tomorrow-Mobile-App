import SwiftUI

struct APIConfig {
    static let baseURL = "https://lead4tomorrow-mobile-app.onrender.com"
}

struct HomePageView: View {
    @Binding var loggedInEmail: String

    @State private var selectedDate = Date()
    @State private var entries: [String] = []
    @State private var theme: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {

                // TOP MESSAGES SECTION
                Group {
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }

                    Text("Theme of the Month: \(theme)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Text("Selected Date: \(formattedDate(selectedDate))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.bottom, 5)

                    if entries.isEmpty && !isLoading && errorMessage == nil {
                        Text("No entries for the selected date.")
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }

                    if isLoading {
                        ProgressView("Loading...").padding()
                    }
                }

                Divider().padding(.horizontal)

                // DATE PICKER
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                .onChange(of: selectedDate) { newDate in
                    fetchEntries(for: formattedRequestDate(newDate))
                }

                // ENTRIES LIST
                if !entries.isEmpty {
                    List(entries, id: \.self) { entry in
                        Text(entry)
                            .padding(.vertical, 4)
                    }
                }

            }
            .navigationTitle("Home")
            .onAppear {
                fetchEntries(for: formattedRequestDate(selectedDate))
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func formattedRequestDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d"
        return formatter.string(from: date)
    }

    private func fetchEntries(for date: String) {
        let components = date.split(separator: "-")
        guard components.count == 2 else {
            self.errorMessage = "Invalid date format."
            return
        }

        let month = components[0]
        let day = components[1]

        guard let url = URL(string: "\(APIConfig.baseURL)/get_entry?month=\(month)&day=\(day)") else {
            self.errorMessage = "Invalid URL."
            return
        }

        isLoading = true
        errorMessage = nil

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.entries = []
                    self.theme = ""
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    return
                }

                guard let data = data,
                      let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
                    self.entries = []
                    self.theme = ""
                    self.errorMessage = "Failed to load data from server."
                    return
                }

                self.theme = decoded["theme"] ?? "No theme available"
                if let entry = decoded["entry"] {
                    self.entries = [entry]
                } else {
                    self.entries = []
                }
            }
        }.resume()
    }
}

struct HomePageView_Previews: PreviewProvider {
    @State static var testEmail = "test@example.com"

    static var previews: some View {
        HomePageView(loggedInEmail: $testEmail)
    }
}

