import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), saint: "Άγιος της Ημέρας", quote: "Φορτώνει...")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), saint: "Άγιος Τρύφων", quote: "Χαίρετε εν Κυρίω πάντοτε.")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.orthodoxy365")
        let saint = userDefaults?.string(forKey: "saint") ?? "Άγιος της Ημέρας"
        let quote = userDefaults?.string(forKey: "quote") ?? "Δεν βρέθηκαν δεδομένα"
        
        let entry = SimpleEntry(date: Date(), saint: saint, quote: quote)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let saint: String
    let quote: String
}

struct OrthodoxyWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 8) {
                Text(entry.saint)
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.22)) // Gold
                    .multilineTextAlignment(.center)
                
                Divider().background(Color(red: 0.83, green: 0.69, blue: 0.22))
                
                Text(entry.quote)
                    .font(.system(size: 12).italic())
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

//@main
struct OrthodoxyWidget: Widget {
    let kind: String = "OrthodoxyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            OrthodoxyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("365 Orthodoxy")
        .description("Δείτε τον Άγιο της ημέρας στην οθόνη σας.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
