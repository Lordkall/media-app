import Flutter
import UIKit
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
import AppIntents
import CryptoKit
import SwiftUI
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MedicationReminders") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "salud_now/medication_reminders", binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      Task { @MainActor in
        do {
          switch call.method {
          case "alarmModeAvailable":
            #if canImport(AlarmKit)
            if #available(iOS 26.0, *) {
              result(true)
              return
            }
            #endif
            result(false)
          case "requestAlarmPermission":
            #if canImport(AlarmKit)
            if #available(iOS 26.0, *) {
              result((try? await AlarmManager.shared.requestAuthorization()) == .authorized)
              return
            }
            #endif
            result(false)
          case "replace":
            guard let items = call.arguments as? [[String: Any]] else {
              result(FlutterError(code: "medication_schedule", message: "Datos de alarma inválidos.", details: nil))
              return
            }
            result(try await Self.replaceMedicationAlerts(items))
          default:
            result(FlutterMethodNotImplemented)
          }
        } catch {
          result(FlutterError(code: "medication_schedule", message: "No se pudieron programar los avisos.", details: nil))
        }
      }
    }
  }

  fileprivate struct Medication {
    let id: Int
    let name: String
    let hours: Int
    let first: Date
    let alarmMode: Bool

    init?(_ raw: [String: Any]) {
      guard let id = raw["id"] as? Int, let name = raw["name"] as? String,
            let hours = raw["intervalHours"] as? Int, hours > 0, hours <= Int(Int32.max),
            let first = raw["firstAt"] as? NSNumber else { return nil }
      self.id = id
      self.name = name
      self.hours = hours
      self.first = Date(timeIntervalSince1970: first.doubleValue / 1000)
      self.alarmMode = raw["alarmMode"] as? Bool ?? false
    }

    var interval: TimeInterval { TimeInterval(hours * 3600) }

    func next(after now: Date) -> Date {
      if first > now { return first }
      let skipped = floor(now.timeIntervalSince(first) / interval) + 1
      return first.addingTimeInterval(skipped * interval)
    }
  }

  @MainActor
  private static func replaceMedicationAlerts(_ items: [[String: Any]]) async throws -> String {
    let center = UNUserNotificationCenter.current()
    let prefix = "salud_now.medication."
    let medications = items.compactMap(Medication.init)
    var nativeIDs = Set<Int>()
    var nativeLimited = false
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      let native = try await MedicationSystemAlarms.replace(medications.filter { $0.alarmMode })
      nativeIDs = native.ids
      nativeLimited = native.limited
    }
    #endif
    let standard = medications.filter { !nativeIDs.contains($0.id) }
    let alarmFallback = standard.contains { $0.alarmMode }
    let active = Set(standard.map { "\(prefix)\($0.id)." })
    let ownPending = await center.pendingNotificationRequests()
    let ownDelivered = await center.deliveredNotifications()
    center.removePendingNotificationRequests(withIdentifiers: ownPending.compactMap {
      $0.identifier.hasPrefix(prefix) ? $0.identifier : nil
    })
    center.removeDeliveredNotifications(withIdentifiers: ownDelivered.compactMap {
      let id = $0.request.identifier
      return id.hasPrefix(prefix) && !active.contains(where: { id.hasPrefix($0) }) ? id : nil
    })

    if standard.isEmpty { return nativeLimited ? "limited" : "standard" }

    let settings = await center.notificationSettings()
    guard settings.authorizationStatus == .authorized ||
          settings.authorizationStatus == .provisional else { return "disabled" }

    // Leave room for the other scheduled notifications from Salud Now.
    let capacity = min(48, 64 - ownPending.filter { !$0.identifier.hasPrefix(prefix) }.count)
    guard capacity >= standard.count else { return "capacity" }
    let now = Date()
    var remaining = capacity
    var finite = [(medication: Medication, next: Date)]()
    var requests = [UNNotificationRequest]()

    for (index, med) in standard.enumerated() {
      let count = 24 / med.hours
      let requiredSlots = standard.count - index - 1 + finite.count
      let canRepeat = 24 % med.hours == 0 && count <= remaining - requiredSlots &&
          med.first.timeIntervalSince(now) <= med.interval
      if canRepeat {
        let next = med.next(after: now)
        for offset in 0..<count {
          let date = next.addingTimeInterval(TimeInterval(offset) * med.interval)
          let fields = Calendar.current.dateComponents([.hour, .minute], from: date)
          let trigger = UNCalendarNotificationTrigger(dateMatching: fields, repeats: true)
          requests.append(medicationRequest(med, id: "\(prefix)\(med.id).daily.\(offset)", trigger: trigger))
        }
        remaining -= count
      } else {
        finite.append((med, med.next(after: now)))
      }
    }

    // Guarantee a next alert for each medication before filling the rest of the window.
    for entry in finite {
      requests.append(singleMedicationRequest(entry.medication, at: entry.next, prefix: prefix))
      remaining -= 1
    }
    finite = finite.map { ($0.medication, $0.next.addingTimeInterval($0.medication.interval)) }
    while remaining > 0 && !finite.isEmpty {
      finite.sort { $0.next < $1.next }
      let entry = finite[0]
      requests.append(singleMedicationRequest(entry.medication, at: entry.next, prefix: prefix))
      finite[0].next = entry.next.addingTimeInterval(entry.medication.interval)
      remaining -= 1
    }

    for request in requests {
      try await center.add(request)
    }
    if alarmFallback { return "alarmFallback" }
    return finite.isEmpty && !nativeLimited ? "standard" : "limited"
  }

  private static func singleMedicationRequest(
    _ medication: Medication, at date: Date, prefix: String
  ) -> UNNotificationRequest {
    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: max(1, date.timeIntervalSinceNow), repeats: false
    )
    return medicationRequest(
      medication, id: "\(prefix)\(medication.id).\(Int(date.timeIntervalSince1970))", trigger: trigger
    )
  }

  private static func medicationRequest(
    _ medication: Medication, id: String, trigger: UNNotificationTrigger
  ) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = "Recordatorio de medicamento"
    content.body = medication.name
    content.sound = .default
    return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
  }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct MedicationAlarmMetadata: AlarmMetadata {}

@available(iOS 26.0, *)
struct MedicationSnoozeIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Posponer medicamento"
  static var openAppWhenRun = false

  @Parameter(title: "Identificador del recordatorio")
  var reminderID: Int

  @Parameter(title: "Identificador de la alarma")
  var alarmID: String

  init() {}
  init(reminderID: Int, alarmID: UUID) {
    self.reminderID = reminderID
    self.alarmID = alarmID.uuidString
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    try await MedicationSystemAlarms.snooze(reminderID, source: UUID(uuidString: alarmID))
    return .result()
  }
}

@available(iOS 26.0, *)
@MainActor
private enum MedicationSystemAlarms {
  private static let slotsKey = "medication.alarmkit.slots"
  private static let snoozesKey = "medication.alarmkit.snoozes"

  private struct Slot {
    let reminder: Int
    let id: UUID
    let schedule: Alarm.Schedule
  }

  static func replace(_ reminders: [AppDelegate.Medication]) async throws -> (ids: Set<Int>, limited: Bool) {
    let manager = AlarmManager.shared
    let defaults = UserDefaults.standard
    guard manager.authorizationState == .authorized else { return ([], false) }

    let previous = defaults.dictionary(forKey: slotsKey) as? [String: Int] ?? [:]
    var snoozes = defaults.dictionary(forKey: snoozesKey) as? [String: String] ?? [:]
    let active = try manager.alarms
    let byID = Dictionary(uniqueKeysWithValues: active.map { ($0.id, $0) })
    let now = Date()
    let selected = Array(reminders.prefix(24))
    let selectedIDs = Set(selected.map { $0.id })
    let weekdays: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
    var slots: [Slot] = []
    var finite: [(AppDelegate.Medication, Date)] = []
    var remaining = 24

    for (index, item) in selected.enumerated() {
      let dailyCount = 24 / item.hours
      let reserved = finite.count + selected.count - index - 1
      if 24 % item.hours == 0 && dailyCount <= remaining - reserved &&
          item.first.timeIntervalSince(now) <= item.interval {
        for offset in 0..<dailyCount {
          let time = item.next(after: now).addingTimeInterval(Double(offset) * item.interval)
          let fields = Calendar.current.dateComponents([.hour, .minute], from: time)
          guard let hour = fields.hour, let minute = fields.minute else { continue }
          slots.append(Slot(
            reminder: item.id,
            id: identifier("\(item.id).daily.\(hour).\(minute)"),
            schedule: .relative(.init(time: .init(hour: hour, minute: minute), repeats: .weekly(weekdays)))
          ))
        }
        remaining -= dailyCount
      } else {
        finite.append((item, item.next(after: now)))
      }
    }

    let limitedIDs = Set(finite.map { $0.0.id })
    for index in finite.indices {
      let (item, next) = finite[index]
      slots.append(fixedSlot(item, next))
      finite[index].1 = next.addingTimeInterval(item.interval)
      remaining -= 1
    }
    while remaining > 0 && !finite.isEmpty {
      finite.sort { $0.1 < $1.1 }
      let (item, next) = finite[0]
      slots.append(fixedSlot(item, next))
      finite[0].1 = next.addingTimeInterval(item.interval)
      remaining -= 1
    }

    let desired = Set(slots.map { $0.id })
    var retained: [String: Int] = [:]
    for (key, reminder) in previous {
      guard let id = UUID(uuidString: key), let alarm = byID[id], !desired.contains(id) else { continue }
      if selectedIDs.contains(reminder) && alarm.state == .alerting {
        retained[key] = reminder
      } else {
        try manager.cancel(id: id)
      }
    }
    for (key, value) in snoozes {
      guard let id = UUID(uuidString: value), byID[id] != nil else {
        snoozes.removeValue(forKey: key)
        continue
      }
      if !selectedIDs.contains(Int(key) ?? -1) {
        try manager.cancel(id: id)
        snoozes.removeValue(forKey: key)
      }
    }

    var successful = Set<Int>()
    for item in selected {
      let group = slots.filter { $0.reminder == item.id }
      var added: [UUID] = []
      do {
        for slot in group {
          if byID[slot.id] == nil {
            _ = try await manager.schedule(id: slot.id, configuration: configuration(slot.schedule, item.id, slot.id))
          }
          added.append(slot.id)
        }
        if !added.isEmpty { successful.insert(item.id) }
        for id in added { retained[id.uuidString] = item.id }
      } catch {
        for id in added { try manager.cancel(id: id) }
        if let raw = snoozes.removeValue(forKey: String(item.id)),
           let id = UUID(uuidString: raw), byID[id] != nil {
          try manager.cancel(id: id)
        }
      }
    }
    defaults.set(retained, forKey: slotsKey)
    defaults.set(snoozes, forKey: snoozesKey)
    return (successful, !limitedIDs.isDisjoint(with: successful))
  }

  static func snooze(_ reminder: Int, source: UUID?) async throws {
    let defaults = UserDefaults.standard
    let registered = defaults.dictionary(forKey: slotsKey) as? [String: Int] ?? [:]
    guard registered.values.contains(reminder) else { return }
    let manager = AlarmManager.shared
    let id = UUID()
    var snoozes = defaults.dictionary(forKey: snoozesKey) as? [String: String] ?? [:]
    let key = String(reminder)
    _ = try await manager.schedule(
      id: id, configuration: configuration(.fixed(Date().addingTimeInterval(600)), reminder, id)
    )
    if let raw = snoozes[key], let old = UUID(uuidString: raw), old != source {
      try? manager.cancel(id: old)
    }
    snoozes[key] = id.uuidString
    defaults.set(snoozes, forKey: snoozesKey)
    if let source { try? manager.stop(id: source) }
  }

  private static func fixedSlot(_ item: AppDelegate.Medication, _ date: Date) -> Slot {
    Slot(reminder: item.id,
         id: identifier("\(item.id).once.\(Int(date.timeIntervalSince1970))"),
         schedule: .fixed(date))
  }

  private static func identifier(_ key: String) -> UUID {
    let bytes = Array(SHA256.hash(data: Data(key.utf8)).prefix(16))
    return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                       bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
  }

  private static func configuration(
    _ schedule: Alarm.Schedule, _ reminder: Int, _ id: UUID
  ) -> AlarmManager.AlarmConfiguration<MedicationAlarmMetadata> {
    let alert = AlarmPresentation.Alert(
      title: "Hora de tomar tu medicamento",
      stopButton: AlarmButton(text: "Detener", textColor: .white, systemImageName: "stop.circle"),
      secondaryButton: AlarmButton(text: "Posponer 10 min", textColor: .white, systemImageName: "clock"),
      secondaryButtonBehavior: .custom
    )
    let attributes = AlarmAttributes(
      presentation: AlarmPresentation(alert: alert),
      metadata: MedicationAlarmMetadata(),
      tintColor: Color(red: 7.0 / 255, green: 86.0 / 255, blue: 164.0 / 255)
    )
    return .alarm(schedule: schedule, attributes: attributes, secondaryIntent: MedicationSnoozeIntent(reminderID: reminder, alarmID: id))
  }
}
#endif
