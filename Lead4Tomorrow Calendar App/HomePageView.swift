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

    @State private var isExpanded = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {

                    // ERROR MESSAGE
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

                    // THEME
                    Text("Theme of the Month: \(theme)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                
                    Link("Visit Lead4Tomorrow Website", destination: URL(string: "https://lead4tomorrow.org")!)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)


                    // SELECTED DATE
                    Text("Selected Date: \(formattedDate(selectedDate))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.bottom, 5)

                    // MESSAGE DISPLAY WITH TOGGLE
                    if let entry = entries.first, !entry.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Message")
                                    .font(.headline)
                                Spacer()
                                if isExpanded {
                                    Button(action: {
                                        isExpanded = false
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }

                            if isExpanded {
                                Text(entry)
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            } else {
                                Button(action: {
                                    isExpanded = true
                                }) {
                                    Text(entry)
                                        .font(.body)
                                        .lineLimit(3)
                                        .foregroundColor(.primary)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

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

                    // ADDITIONAL ENTRIES (if ever supported)
                    if entries.count > 1 {
                        ForEach(entries.dropFirst(), id: \.self) { entry in
                            Text(entry)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                    }

                }
                .padding(.top)
                .navigationTitle("Home")
                .onAppear {
                    fetchEntries(for: formattedRequestDate(selectedDate))
                }
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

                // Collapse the box when switching dates
                self.isExpanded = false
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

