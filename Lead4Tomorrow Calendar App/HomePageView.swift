import SwiftUI

struct APIConfig {
    static let baseURL = "https://lead4tomorrow-mobile-app.onrender.com" // CHANGE THIS for deployment
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
            VStack {
                // Date picker to select a date
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

                // Display the theme of the month
                Text("Theme of the Month: \(theme)")
                    .font(.headline)
                    .padding()

                // Display the selected date
                Text("Selected Date: \(formattedDate(selectedDate))")
                    .padding()

                if isLoading {
                    ProgressView("Loading...").padding()
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }

                if entries.isEmpty && !isLoading {
                    Text("No entries for the selected date.")
                        .italic()
                        .padding()
                } else {
                    List(entries, id: \.self) { entry in
                        Text(entry)
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
        guard let url = URL(string: "\(APIConfig.baseURL)/get_entry?date=\(date)") else {
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

