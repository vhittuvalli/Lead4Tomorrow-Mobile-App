import SwiftUI
import WebKit

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

    private func dayTheme(for date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
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
            VStack(spacing: 14) {

                // Error banner
                if let error = errorMessage {
                    Text(error)
                        .font(AppTheme.body(15, weight: .semibold))
                        .foregroundColor(AppTheme.errorText)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.errorBG)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }

                // Theme of Month
                Text("Theme of the Month: \(theme)")
                    .font(AppTheme.heading(18, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.green)
                    .padding(.horizontal)

                // Site link (accent)
                Link("Visit Lead4Tomorrow Website",
                     destination: URL(string: "https://lead4tomorrow.org")!)
                    .font(AppTheme.body(15, weight: .medium))
                    .foregroundColor(AppTheme.link)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(AppTheme.backgroundCard)
                    .cornerRadius(10)

                // Selected date label
                Text("Selected Date: \(formattedDate(selectedDate))")
                    .font(AppTheme.body(14))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.bottom, 4)

                // Entry card (collapsible)
                if let entry = entries.first, !entry.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Message")
                                .modifier(ThemedSectionTitle())
                            Spacer()
                            if isExpanded {
                                Button { isExpanded = false } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                .accessibilityLabel("Collapse message")
                            }
                        }

                        if isExpanded {
                            VStack(alignment: .leading, spacing: 12) {
                                // Markdown-capable body
                                if let md = try? AttributedString(markdown: entry) {
                                    ThemedCard {
                                        Text(md)
                                            .font(AppTheme.body())
                                            .foregroundColor(AppTheme.textPrimary)
                                            .textSelection(.enabled)
                                    }
                                } else {
                                    ThemedCard {
                                        Text(entry)
                                            .font(AppTheme.body())
                                            .foregroundColor(AppTheme.textPrimary)
                                    }
                                }

                                // Detect and embed YouTube video (if present)
                                if let youtubeURL = extractYouTubeURL(from: entry) {
                                    YouTubeWebView(url: youtubeURL)
                                        .frame(height: 220)
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                                }

                                // Detect and show all other links
                                ForEach(extractAllLinks(from: entry)
                                    .filter { !$0.absoluteString.contains("youtube") }, id: \.self) { url in
                                        Link(destination: url) {
                                            Label(url.absoluteString, systemImage: "link")
                                        }
                                        .font(AppTheme.body(14, weight: .medium))
                                        .foregroundColor(AppTheme.link)
                                }
                            }
                        } else {
                            Button { isExpanded = true } label: {
                                ThemedCard {
                                    Text(entry)
                                        .font(AppTheme.body())
                                        .lineLimit(3)
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                            }
                            .accessibilityLabel("Expand message")
                        }
                    }
                    .padding(.horizontal)
                }

                // Empty state
                if entries.isEmpty && !isLoading && errorMessage == nil {
                    ThemedCard {
                        Text("No entries for the selected date.")
                            .font(AppTheme.body(15, weight: .medium))
                            .foregroundColor(AppTheme.brown) // a warm neutral callout
                    }
                    .padding(.horizontal)
                }

                if isLoading {
                    ProgressView("Loading...")
                        .font(AppTheme.body(15))
                        .tint(AppTheme.accent)
                        .padding(.vertical, 6)
                }

                Divider()
                    .overlay(AppTheme.backgroundSoft)
                    .padding(.horizontal)

                // Date Picker
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    in: ...today,
                    displayedComponents: [.date]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .tint(AppTheme.accent)
                .font(AppTheme.body(15))
                .padding(.horizontal)
                .onChange(of: selectedDate) { newDate in
                    let clamped = min(Calendar.current.startOfDay(for: newDate), today)
                    if clamped != newDate { selectedDate = clamped }
                    fetchEntries(for: formattedRequestDate(clamped))
                }
                .onAppear {
                    if selectedDate > today { selectedDate = today }
                    fetchEntries(for: formattedRequestDate(selectedDate))
                }
            }
            .padding(.vertical, 12)
        }
        .background(AppTheme.backgroundSoft.ignoresSafeArea())
        .navigationTitle(dayTheme(for: selectedDate))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.backgroundSoft, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(AppTheme.accent) // global accent within this screen
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

    // MARK: - Link + YouTube Detection

    private func extractYouTubeURL(from text: String) -> URL? {
        let pattern = #"https?://(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/)[^\s]+"#
        if let range = text.range(of: pattern, options: .regularExpression) {
            return URL(string: String(text[range]))
        }
        return nil
    }

    private func extractAllLinks(from text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return URL(string: String(text[range]))
        }
    }
}

// MARK: - Embedded YouTube WebView

struct YouTubeWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView()
        web.scrollView.isScrollEnabled = false
        web.isOpaque = false
        web.backgroundColor = .clear
        return web
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <!doctype html><html><head><meta name='viewport' content='initial-scale=1, width=device-width'>
        <style>body,html{margin:0;padding:0;background:transparent}</style></head>
        <body>
        <iframe width='100%' height='100%' src='\(url.absoluteString)?playsinline=1'
            frameborder='0'
            allow='accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
            allowfullscreen>
        </iframe>
        </body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

#Preview {
    NavigationStack { HomePageView() }
}

