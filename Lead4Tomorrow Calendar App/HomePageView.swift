import SwiftUI

struct HomePageView: View {
    @State private var selectedDate = Date()
    @State private var entries: [String] = []  // State to store fetched entries

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
                .onChange(of: selectedDate, perform: { newDate in
                    // Fetch entries whenever a new date is selected
                    fetchEntries(for: formattedRequestDate(newDate))
                })

                Text("Selected Date: \(formattedDate(selectedDate))")
                    .padding()

                // Display the fetched entries
                if entries.isEmpty {
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
        }
    }

    // Format the date for display in the app
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    // Format the date to send as a request (e.g., "M-d")
    private func formattedRequestDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d"  // Matches your backend's expected format
        return formatter.string(from: date)
    }

    // Fetch entries for the selected date
    private func fetchEntries(for date: String) {
        guard let url = URL(string: "http://localhost:5000/get_entry?date=\(date)") else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let decodedResponse = try? JSONDecoder().decode([String].self, from: data) {
                    DispatchQueue.main.async {
                        self.entries = decodedResponse
                    }
                } else {
                    // Handle decoding failure
                    DispatchQueue.main.async {
                        self.entries = ["Failed to load entries."]
                    }
                }
            } else if let error = error {
                // Handle network error
                DispatchQueue.main.async {
                    self.entries = ["Error: \(error.localizedDescription)"]
                }
            }
        }.resume()
    }
}

struct HomePageView_Previews: PreviewProvider {
    static var previews: some View {
        HomePageView()
    }
}

