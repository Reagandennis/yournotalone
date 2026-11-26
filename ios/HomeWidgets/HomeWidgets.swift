// The home-screen and lock-screen widgets. They only display: every number
// and word comes from the app (lib/home_widgets/home_widget_sync.dart, which
// owns the keys read below), already in the app's language. The words in
// Localizable.strings are only the gallery's.

import SwiftUI
import WidgetKit

private let appGroup = "group.com.techgetafrica.yournotalone"

// MARK: - What the app left

/// What the app last wrote, made fit for [now]. The widget outlives the day
/// it was written on: a new day loses yesterday's check-in, suggestion and
/// sleep, and a new week starts at nothing, rather than showing old ticks
/// as if they were today's.
struct WidgetData {
  var signedOut: Bool
  var days: Int
  var goal: Int
  var week: [Bool]
  var todayIndex: Int
  var checkedIn: Bool
  var pickId: String?
  var pickTitle: String?
  var pickMeta: String?
  var sleepLine: String?
  var labelWeek: String
  var labelDays: String
  var labelGoalMet: String?
  var labelCheckIn: String
  var labelCheckedIn: String
  var labelForYou: String
  var labelOpenForPick: String

  var goalMet: Bool { days >= goal }
  var daysLine: String { goalMet ? (labelGoalMet ?? labelDays) : labelDays }

  static func read(now: Date) -> WidgetData {
    let store = UserDefaults(suiteName: appGroup)
    func text(_ key: String) -> String? {
      guard let value = store?.string(forKey: key), !value.isEmpty else { return nil }
      return value
    }
    func number(_ key: String) -> Int? {
      (store?.object(forKey: key) as? NSNumber)?.intValue
    }

    var calendar = Calendar(identifier: .iso8601)  // Monday first
    calendar.timeZone = .current
    let today = calendar.startOfDay(for: now)
    let monday = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    let todayIndex = (calendar.component(.weekday, from: today) + 5) % 7

    let ready = text("hw_state") == "ready"
    let sameWeek = ready && text("hw_week_start") == dateKey(monday)
    let sameDay = sameWeek && text("hw_day") == dateKey(today)
    let bits = sameWeek ? Array(text("hw_week") ?? "") : []

    return WidgetData(
      signedOut: !ready,
      days: sameWeek ? (number("hw_days") ?? 0) : 0,
      goal: min(max(number("hw_goal") ?? 3, 1), 7),
      week: (0..<7).map { $0 < bits.count && bits[$0] == "1" },
      todayIndex: todayIndex,
      checkedIn: sameDay && (store?.bool(forKey: "hw_checked_in") ?? false),
      pickId: sameDay ? text("hw_pick_id") : nil,
      pickTitle: sameDay ? text("hw_pick_title") : nil,
      pickMeta: sameDay ? text("hw_pick_meta") : nil,
      sleepLine: sameDay ? text("hw_sleep_line") : nil,
      labelWeek: text("hw_label_week") ?? localized("widget_week"),
      labelDays: (sameWeek ? text("hw_label_days") : text("hw_label_days_zero"))
        ?? localized("widget_days"),
      labelGoalMet: text("hw_label_goal_met"),
      labelCheckIn: text("hw_label_check_in") ?? localized("widget_check_in"),
      labelCheckedIn: text("hw_label_checked_in") ?? "",
      labelForYou: text("hw_label_for_you") ?? localized("widget_for_you"),
      labelOpenForPick: text("hw_label_open_for_pick") ?? localized("widget_open_app")
    )
  }

  /// The gallery's picture: a week under way, in the phone's language.
  static let sample = WidgetData(
    signedOut: false, days: 2, goal: 3,
    week: [true, false, true, false, false, false, false], todayIndex: 3,
    checkedIn: false, pickId: nil,
    pickTitle: localized("widget_pick"), pickMeta: localized("widget_pick_meta"),
    sleepLine: nil,
    labelWeek: localized("widget_week"), labelDays: localized("widget_days"),
    labelGoalMet: nil, labelCheckIn: localized("widget_check_in"), labelCheckedIn: "",
    labelForYou: localized("widget_for_you"), labelOpenForPick: localized("widget_open_app")
  )

  var checkInURL: URL { URL(string: "yournotalone-widget://checkin?homeWidget=1")! }

  /// Where the suggestion opens; the check-in when there's none.
  var pickURL: URL {
    guard let id = pickId,
      let escaped = id.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed),
      let url = URL(string: "yournotalone-widget://pick?id=\(escaped)&homeWidget=1")
    else { return checkInURL }
    return url
  }
}

private func localized(_ key: String) -> String {
  NSLocalizedString(key, comment: "")
}

private func dateKey(_ date: Date) -> String {
  let format = DateFormatter()
  format.calendar = Calendar(identifier: .gregorian)
  format.locale = Locale(identifier: "en_US_POSIX")
  format.timeZone = .current
  format.dateFormat = "yyyy-MM-dd"
  return format.string(from: date)
}

extension CharacterSet {
  /// A query value: no `&`, `=` or `+` left to be read as structure.
  fileprivate static let urlQueryValueAllowed: CharacterSet = {
    var set = CharacterSet.urlQueryAllowed
    set.remove(charactersIn: "&=+?#")
    return set
  }()
}

// MARK: - Timeline

struct Entry: TimelineEntry {
  let date: Date
  let data: WidgetData
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> Entry {
    Entry(date: Date(), data: .sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
    let now = Date()
    completion(Entry(date: now, data: context.isPreview ? .sample : .read(now: now)))
  }

  /// Now, and again at midnight, so the new day shows as new even if the
  /// app isn't opened; the app asks for a fresh timeline whenever it writes.
  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let now = Date()
    let midnight = Calendar.current.nextDate(
      after: now, matching: DateComponents(hour: 0, minute: 0, second: 5),
      matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
    completion(
      Timeline(
        entries: [
          Entry(date: now, data: .read(now: now)),
          Entry(date: midnight, data: .read(now: midnight)),
        ],
        policy: .atEnd))
  }
}

// MARK: - Colours (lib/brand.dart)

extension Color {
  fileprivate init(light: UInt32, dark: UInt32) {
    self.init(
      UIColor { traits in
        let hex = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(
          red: CGFloat((hex >> 16) & 0xFF) / 255,
          green: CGFloat((hex >> 8) & 0xFF) / 255,
          blue: CGFloat(hex & 0xFF) / 255,
          alpha: 1)
      })
  }
}

private enum Brand {
  static let background = Color(light: 0xFFFFFF, dark: 0x10284D)
  static let ink = Color(light: 0x1A2238, dark: 0xEEF1F6)
  static let muted = Color(light: 0x5E6576, dark: 0xA3AEC2)
  static let accent = Color(light: 0x3764CD, dark: 0x86A8F2)
  static let onAccent = Color(light: 0xFFFFFF, dark: 0x001939)
  static let dotOff = Color(light: 0xE6E1D9, dark: 0x1E3A63)
  static let pillars = [
    Color(light: 0xE12D23, dark: 0xE12D23),
    Color(light: 0x3764CD, dark: 0x3764CD),
    Color(light: 0x1A2238, dark: 0xEEF1F6),
    Color(light: 0xFAB414, dark: 0xFAB414),
  ]
}

// MARK: - Pieces

/// The four-pillar stripe, as under the app's headings.
private struct PillarStripe: View {
  var body: some View {
    HStack(spacing: 3) {
      ForEach(0..<4, id: \.self) { i in
        RoundedRectangle(cornerRadius: 2).fill(Brand.pillars[i]).frame(width: 14, height: 4)
      }
    }
    .accessibilityHidden(true)
  }
}

private struct WeekDots: View {
  let data: WidgetData

  var body: some View {
    HStack(spacing: 5) {
      ForEach(0..<7, id: \.self) { i in
        if data.week[i] {
          Circle().fill(Brand.accent).frame(width: 10, height: 10)
        } else if i == data.todayIndex {
          // Today, not shown up on yet: a ring, open rather than missed.
          Circle().strokeBorder(Brand.accent, lineWidth: 2).frame(width: 10, height: 10)
        } else {
          Circle().fill(Brand.dotOff).frame(width: 10, height: 10)
        }
      }
    }
    .accessibilityHidden(true)
  }
}

private struct RhythmBlock: View {
  let data: WidgetData

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      PillarStripe()
      Text(data.labelWeek)
        .font(.system(size: 12)).foregroundColor(Brand.muted)
        .padding(.top, 10)
      Text(data.daysLine)
        .font(.system(size: 17, weight: .bold)).foregroundColor(Brand.ink)
        .lineLimit(2).minimumScaleFactor(0.8)
        .padding(.top, 2)
      WeekDots(data: data).padding(.top, 10)
      Spacer(minLength: 8)
      if data.checkedIn {
        Text("✓ " + data.labelCheckedIn)
          .font(.system(size: 13)).foregroundColor(Brand.muted).lineLimit(2)
      } else {
        Text(data.labelCheckIn)
          .font(.system(size: 13, weight: .bold)).foregroundColor(Brand.onAccent)
          .lineLimit(1)
          .padding(.horizontal, 14).padding(.vertical, 6)
          .background(Capsule().fill(Brand.accent))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

private struct SignedOutView: View {
  let data: WidgetData

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      PillarStripe()
      Text(data.labelOpenForPick)
        .font(.system(size: 14, weight: .bold)).foregroundColor(Brand.ink)
        .lineLimit(3)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

// MARK: - Families

private struct SmallView: View {
  let data: WidgetData

  var body: some View {
    Group {
      if data.signedOut { SignedOutView(data: data) } else { RhythmBlock(data: data) }
    }
    .widgetURL(data.checkInURL)
  }
}

private struct MediumView: View {
  let data: WidgetData

  var body: some View {
    if data.signedOut {
      SignedOutView(data: data).widgetURL(data.checkInURL)
    } else {
      HStack(alignment: .top, spacing: 14) {
        Link(destination: data.checkInURL) { RhythmBlock(data: data) }
        Rectangle().fill(Brand.dotOff).frame(width: 1)
        Link(destination: data.pickURL) {
          VStack(alignment: .leading, spacing: 2) {
            Text(data.labelForYou)
              .font(.system(size: 12)).foregroundColor(Brand.muted)
              .padding(.top, 14)
            Text(data.pickTitle ?? data.labelOpenForPick)
              .font(.system(size: 15, weight: .bold)).foregroundColor(Brand.ink)
              .lineLimit(2)
            if data.pickTitle != nil, let meta = data.pickMeta {
              Text(meta).font(.system(size: 12)).foregroundColor(Brand.accent).lineLimit(1)
            }
            Spacer(minLength: 4)
            if let sleep = data.sleepLine {
              Text(sleep).font(.system(size: 12)).foregroundColor(Brand.muted).lineLimit(1)
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
      }
    }
  }
}

/// The lock screen: the week as a ring, days against the goal.
private struct CircularView: View {
  let data: WidgetData

  var body: some View {
    Gauge(value: Double(min(data.days, data.goal)), in: 0...Double(data.goal)) {
      Text(data.labelWeek)
    } currentValueLabel: {
      Text(data.signedOut ? "–" : "\(data.days)")
    }
    .gaugeStyle(.accessoryCircularCapacity)
    .widgetURL(data.checkInURL)
  }
}

/// The lock screen: the week's line and today's suggestion.
private struct RectangularView: View {
  let data: WidgetData

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      if data.signedOut {
        Text(data.labelOpenForPick).font(.headline).lineLimit(2)
      } else {
        Text(data.daysLine).font(.headline).lineLimit(1)
        if let pick = data.pickTitle {
          Text(pick).font(.caption).lineLimit(2)
        } else {
          Text(data.checkedIn ? data.labelCheckedIn : data.labelCheckIn)
            .font(.caption).lineLimit(1)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .widgetURL(data.pickTitle != nil ? data.pickURL : data.checkInURL)
  }
}

struct HomeWidgetsView: View {
  @Environment(\.widgetFamily) private var family
  let entry: Entry

  var body: some View {
    switch family {
    case .systemMedium:
      MediumView(data: entry.data).brandBackground(padded: true)
    case .accessoryCircular:
      CircularView(data: entry.data).brandBackground(padded: false, clear: true)
    case .accessoryRectangular:
      RectangularView(data: entry.data).brandBackground(padded: false, clear: true)
    default:
      SmallView(data: entry.data).brandBackground(padded: true)
    }
  }
}

extension View {
  /// The card colour behind a home-screen widget; the lock screen draws its
  /// own. iOS 17 wants it as the container background, so the system can
  /// drop it where it tints widgets (StandBy, accented home screens).
  @ViewBuilder
  fileprivate func brandBackground(padded: Bool, clear: Bool = false) -> some View {
    if #available(iOS 17.0, *) {
      if clear {
        self.containerBackground(for: .widget) { Color.clear }
      } else {
        self.containerBackground(for: .widget) { Brand.background }
      }
    } else if clear {
      self
    } else {
      self.padding(padded ? 16 : 0).background(Brand.background)
    }
  }
}

// MARK: - The widget

@main
struct HomeWidgets: Widget {
  /// The kind the app names when it asks for a redraw.
  let kind = "HomeWidgets"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      HomeWidgetsView(entry: entry)
    }
    .configurationDisplayName(Text("widget_name"))
    .description(Text("widget_desc"))
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
  }
}
