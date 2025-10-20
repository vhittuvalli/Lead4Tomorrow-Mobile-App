import SwiftUI

struct HomePageView: View {
    @State private var selectedDate = Date()
    @State private var entries: [String] = []
    @State private var theme: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isExpanded = false

    // Helper used by DatePicker range and clamping
    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    // NEW: Theme-of-the-day based on weekday
    private func dayTheme(for date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        // Apple weekday: 1=Sunday, 2=Monday, ... 7=Saturday
        switch weekday {
        case 2: return "Mindful Mondays"
        case 3: return "Thoughtful Tuesdays"
        case 4: return "What's-Up Wednesdays"
        case 5: return "Thankful Thursdays"
        case 6: return "Fast Fact Fridays"
        case 7: return "Self-care Saturdays"
        case 1: return "Strong Family Sundays"
        default: return "Daily Theme"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                // Error banner
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

                // Theme
                Text("Theme of the Month: \(theme)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Link("Visit Lead4Tomorrow Website",
                     destination: URL(string: "https://lead4tomorrow.org")!)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)

                // Selected date label
                Text("Selected Date: \(formattedDate(selectedDate))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 5)

                // Entry card (collapsible)
                if let entry = entries.first, !entry.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Message").font(.headline)
                            Spacer()
                            if isExpanded {
                                Button { isExpanded = false } label: {
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
                            Button { isExpanded = true } label: {
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

                // Empty state
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

                // Loading
                if isLoading {
                    ProgressView("Loading...").padding()
                }

                Divider().padding(.horizontal)

                // Date picker (no future dates)
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    in: ...today,
                    displayedComponents: [.date]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .onChange(of: selectedDate) { newDate in
                    // Clamp just in case
                    let clamped = min(Calendar.current.startOfDay(for: newDate), today)
                    if clamped != newDate { selectedDate = clamped }
                    fetchEntries(for: formattedRequestDate(clamped))
                }
                .onAppear {
                    // Snap to today if needed, then fetch
                    if selectedDate > today { selectedDate = today }
                    fetchEntries(for: formattedRequestDate(selectedDate))
                }
            }
        }
        // UPDATED: navigation title now shows the theme of the day
        .navigationTitle(dayTheme(for: selectedDate))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

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
        let parts = date.split(separator: "-")
        guard parts.count == 2 else {
            errorMessage = "Invalid date format."
            return
        }

        let month = parts[0], day = parts[1]
        guard let url = URL(string: "\(APIConfig.baseURL)/get_entry?month=\(month)&day=\(day)") else {
            errorMessage = "Invalid URL."
            return
        }

        isLoading = true
        errorMessage = nil

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    entries = []
                    theme = ""
                    errorMessage = "Error: \(error.localizedDescription)"
                    return
                }

                guard
                    let data = data,
                    let decoded = try? JSONDecoder().decode([String: String].self, from: data)
                else {
                    entries = []
                    theme = ""
                    errorMessage = "Failed to load data from server."
                    return
                }

                theme = decoded["theme"] ?? "No theme available"
                if let entry = decoded["entry"] {
                    entries = [entry]
                } else {
                    entries = []
                }
                isExpanded = false
            }
        }.resume()
    }
}

// Preview
#Preview {
    NavigationStack {
        HomePageView()
            // Title updates dynamically with today's weekday in the preview
            .navigationTitle(" ")
    }
}

