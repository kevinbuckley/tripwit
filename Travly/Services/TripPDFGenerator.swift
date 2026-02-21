import UIKit
import SwiftUI
import TripCore

/// Generates a beautifully designed PDF itinerary for a trip.
struct TripPDFGenerator {

    // MARK: - Color Palette

    private static let accentBlue = UIColor(red: 0.20, green: 0.40, blue: 0.85, alpha: 1.0)
    private static let accentBlueBg = UIColor(red: 0.20, green: 0.40, blue: 0.85, alpha: 0.08)
    private static let headerDark = UIColor(red: 0.12, green: 0.14, blue: 0.20, alpha: 1.0)
    private static let bodyText = UIColor(red: 0.20, green: 0.22, blue: 0.28, alpha: 1.0)
    private static let subtitleGray = UIColor(red: 0.45, green: 0.47, blue: 0.53, alpha: 1.0)
    private static let lightGray = UIColor(red: 0.70, green: 0.72, blue: 0.76, alpha: 1.0)
    private static let dividerColor = UIColor(red: 0.88, green: 0.89, blue: 0.91, alpha: 1.0)

    private static let catColors: [StopCategory: UIColor] = [
        .accommodation: UIColor(red: 0.56, green: 0.27, blue: 0.85, alpha: 1.0),
        .restaurant: UIColor(red: 0.92, green: 0.50, blue: 0.15, alpha: 1.0),
        .attraction: UIColor(red: 0.85, green: 0.65, blue: 0.05, alpha: 1.0),
        .transport: UIColor(red: 0.20, green: 0.50, blue: 0.90, alpha: 1.0),
        .activity: UIColor(red: 0.20, green: 0.72, blue: 0.40, alpha: 1.0),
        .other: UIColor(red: 0.55, green: 0.57, blue: 0.62, alpha: 1.0),
    ]

    // MARK: - Generate

    static func generatePDF(for trip: TripEntity) -> Data {
        let isUS = Locale.current.measurementSystem == .us
        let pw: CGFloat = isUS ? 612 : 595.28
        let ph: CGFloat = isUS ? 792 : 841.89
        let m: CGFloat = 48
        let cw = pw - m * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pw, height: ph))

        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .medium; dateFmt.timeStyle = .none
        let timeFmt = DateFormatter()
        timeFmt.dateStyle = .none; timeFmt.timeStyle = .short
        let shortFmt = DateFormatter()
        shortFmt.dateFormat = "EEE, MMM d"

        return renderer.pdfData { ctx in
            var y: CGFloat = 0

            // MARK: Helpers

            func newPage() { ctx.beginPage(); y = m }

            func space(_ needed: CGFloat) {
                if y + needed > ph - m - 20 { footer(); newPage() }
            }

            func text(_ s: String, font: UIFont, color: UIColor = bodyText, x: CGFloat = m, w: CGFloat? = nil) {
                let style = NSMutableParagraphStyle(); style.lineSpacing = 2
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
                let maxW = w ?? cw
                let rect = (s as NSString).boundingRect(with: CGSize(width: maxW, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
                (s as NSString).draw(in: CGRect(x: x, y: y, width: maxW, height: rect.height), withAttributes: attrs)
                y += rect.height
            }

            func draw(_ s: String, at pt: CGPoint, font: UIFont, color: UIColor) {
                let a: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                (s as NSString).draw(at: pt, withAttributes: a)
            }

            func sizeOf(_ s: String, font: UIFont) -> CGSize {
                (s as NSString).size(withAttributes: [.font: font])
            }

            func divider() {
                let p = UIBezierPath()
                p.move(to: CGPoint(x: m, y: y))
                p.addLine(to: CGPoint(x: pw - m, y: y))
                dividerColor.setStroke(); p.lineWidth = 0.5; p.stroke()
                y += 12
            }

            func footer() {
                let fy = ph - 30
                ctx.cgContext.setStrokeColor(dividerColor.cgColor)
                ctx.cgContext.setLineWidth(0.5)
                ctx.cgContext.move(to: CGPoint(x: 48, y: fy - 6))
                ctx.cgContext.addLine(to: CGPoint(x: pw - 48, y: fy - 6))
                ctx.cgContext.strokePath()
                draw("Travly  •  \(trip.wrappedName)", at: CGPoint(x: 48, y: fy), font: .systemFont(ofSize: 8, weight: .medium), color: lightGray)
            }

            func fillRect(_ rect: CGRect, color: UIColor, radius: CGFloat = 0) {
                let p = UIBezierPath(roundedRect: rect, cornerRadius: radius)
                color.setFill(); p.fill()
            }

            // ================================================================
            // COVER PAGE
            // ================================================================
            newPage()

            // Top accent stripe
            fillRect(CGRect(x: 0, y: 0, width: pw, height: 6), color: accentBlue)

            y = ph * 0.28
            draw("✈  YOUR TRIP TO", at: CGPoint(x: m, y: y), font: .systemFont(ofSize: 14, weight: .medium), color: accentBlue)
            y += 24

            text(trip.wrappedName.uppercased(), font: .systemFont(ofSize: 34, weight: .heavy), color: headerDark)
            y += 6
            fillRect(CGRect(x: m, y: y, width: 60, height: 3), color: accentBlue)
            y += 16

            text(trip.wrappedDestination, font: .systemFont(ofSize: 20, weight: .medium), color: subtitleGray)
            y += 12
            text("\(dateFmt.string(from: trip.wrappedStartDate))  –  \(dateFmt.string(from: trip.wrappedEndDate))", font: .systemFont(ofSize: 13), color: lightGray)
            y += 4
            text("\(trip.durationInDays) days", font: .systemFont(ofSize: 13), color: lightGray)

            // Stats bar
            y += 36
            let stopCount = trip.daysArray.reduce(0) { $0 + $1.stopsArray.count }
            let bkCount = trip.bookingsArray.count
            fillRect(CGRect(x: m, y: y, width: cw, height: 56), color: accentBlueBg, radius: 10)

            let stats: [(String, String)] = [("\(trip.durationInDays)", "DAYS"), ("\(stopCount)", "STOPS"), ("\(bkCount)", "BOOKINGS"), ("\(trip.daysArray.count)", "DAY PLANS")]
            let sw = cw / CGFloat(stats.count)
            for (i, stat) in stats.enumerated() {
                let cx = m + sw * CGFloat(i) + sw / 2
                let ns = sizeOf(stat.0, font: .systemFont(ofSize: 22, weight: .bold))
                draw(stat.0, at: CGPoint(x: cx - ns.width / 2, y: y + 8), font: .systemFont(ofSize: 22, weight: .bold), color: accentBlue)
                let ls = sizeOf(stat.1, font: .systemFont(ofSize: 9, weight: .semibold))
                draw(stat.1, at: CGPoint(x: cx - ls.width / 2, y: y + 34), font: .systemFont(ofSize: 9, weight: .semibold), color: subtitleGray)
            }
            y += 56

            if !trip.wrappedNotes.isEmpty {
                y += 24
                text(trip.wrappedNotes, font: .italicSystemFont(ofSize: 11), color: subtitleGray)
            }
            footer()

            // ================================================================
            // BOOKINGS
            // ================================================================
            let bookings = trip.bookingsArray
            if !bookings.isEmpty {
                newPage()
                text("Flights & Hotels", font: .systemFont(ofSize: 22, weight: .bold), color: headerDark)
                y += 16

                for bk in bookings {
                    space(90)

                    // Type badge pill
                    let badgeStr = " \(bk.bookingType.label.uppercased()) "
                    let badgeFont = UIFont.systemFont(ofSize: 8, weight: .bold)
                    let bs = sizeOf(badgeStr, font: badgeFont)
                    fillRect(CGRect(x: m, y: y, width: bs.width + 10, height: bs.height + 6), color: bookingColor(bk.bookingType), radius: 4)
                    draw(badgeStr, at: CGPoint(x: m + 5, y: y + 3), font: badgeFont, color: .white)
                    y += bs.height + 10

                    text(bk.wrappedTitle, font: .systemFont(ofSize: 14, weight: .semibold), color: headerDark)

                    if !bk.wrappedConfirmationCode.isEmpty {
                        text("Confirmation: \(bk.wrappedConfirmationCode)", font: .monospacedSystemFont(ofSize: 11, weight: .medium), color: accentBlue)
                    }

                    if bk.bookingType == .flight {
                        if let al = bk.airline, !al.isEmpty { text("Airline: \(al)", font: .systemFont(ofSize: 11), color: subtitleGray) }
                        if let dep = bk.departureAirport, let arr = bk.arrivalAirport, !dep.isEmpty, !arr.isEmpty {
                            text("\(dep)  ✈  \(arr)", font: .systemFont(ofSize: 13, weight: .semibold), color: bodyText)
                        }
                        if let t = bk.departureTime { text("Departs: \(dateFmt.string(from: t)) at \(timeFmt.string(from: t))", font: .systemFont(ofSize: 11), color: subtitleGray) }
                        if let t = bk.arrivalTime { text("Arrives: \(dateFmt.string(from: t)) at \(timeFmt.string(from: t))", font: .systemFont(ofSize: 11), color: subtitleGray) }
                    }

                    if bk.bookingType == .hotel {
                        if let n = bk.hotelName, !n.isEmpty { text(n, font: .systemFont(ofSize: 13, weight: .medium), color: bodyText) }
                        if let a = bk.hotelAddress, !a.isEmpty { text(a, font: .systemFont(ofSize: 11), color: subtitleGray) }
                        if let ci = bk.checkInDate, let co = bk.checkOutDate {
                            let n = Calendar.current.dateComponents([.day], from: ci, to: co).day ?? 0
                            text("Check-in: \(dateFmt.string(from: ci))  •  Check-out: \(dateFmt.string(from: co))  (\(n) night\(n == 1 ? "" : "s"))", font: .systemFont(ofSize: 11), color: subtitleGray)
                        }
                    }

                    if bk.bookingType == .carRental {
                        if let t = bk.departureTime { text("Pickup: \(dateFmt.string(from: t)) \(timeFmt.string(from: t))", font: .systemFont(ofSize: 11), color: subtitleGray) }
                        if let t = bk.arrivalTime { text("Return: \(dateFmt.string(from: t)) \(timeFmt.string(from: t))", font: .systemFont(ofSize: 11), color: subtitleGray) }
                    }

                    if !bk.wrappedNotes.isEmpty { text(bk.wrappedNotes, font: .italicSystemFont(ofSize: 10), color: lightGray) }
                    y += 8; divider()
                }
                footer()
            }

            // ================================================================
            // BUDGET & EXPENSES
            // ================================================================
            let expenses = trip.expensesArray
            if trip.budgetAmount > 0 || !expenses.isEmpty {
                newPage()
                text("Budget & Expenses", font: .systemFont(ofSize: 22, weight: .bold), color: headerDark)
                y += 16

                let total = expenses.reduce(0.0) { $0 + $1.amount }
                let cf = NumberFormatter(); cf.numberStyle = .currency; cf.currencyCode = trip.wrappedBudgetCurrencyCode

                if trip.budgetAmount > 0 {
                    let spent = cf.string(from: NSNumber(value: total)) ?? "$\(total)"
                    let budget = cf.string(from: NSNumber(value: trip.budgetAmount)) ?? "$\(trip.budgetAmount)"
                    text("\(spent) spent of \(budget)", font: .systemFont(ofSize: 14, weight: .semibold), color: headerDark)
                    y += 8

                    // Progress bar
                    fillRect(CGRect(x: m, y: y, width: cw, height: 8), color: UIColor(red: 0.92, green: 0.93, blue: 0.94, alpha: 1.0), radius: 4)
                    let ratio = min(total / trip.budgetAmount, 1.0)
                    let barColor: UIColor = ratio < 0.75 ? UIColor(red: 0.20, green: 0.72, blue: 0.40, alpha: 1.0) : ratio < 0.90 ? UIColor(red: 0.92, green: 0.70, blue: 0.15, alpha: 1.0) : UIColor(red: 0.90, green: 0.25, blue: 0.20, alpha: 1.0)
                    if ratio > 0 { fillRect(CGRect(x: m, y: y, width: cw * ratio, height: 8), color: barColor, radius: 4) }
                    y += 14
                    text(String(format: "%.0f%% used", ratio * 100), font: .systemFont(ofSize: 10, weight: .medium), color: subtitleGray)
                    y += 12
                } else {
                    let spent = cf.string(from: NSNumber(value: total)) ?? "$\(total)"
                    text("Total spent: \(spent)", font: .systemFont(ofSize: 14, weight: .semibold), color: headerDark)
                    y += 12
                }

                // Category breakdown
                let grouped = Dictionary(grouping: expenses, by: { $0.category })
                if !grouped.isEmpty {
                    divider()
                    for cat in ExpenseCategory.allCases {
                        guard let items = grouped[cat] else { continue }
                        let catTotal = items.reduce(0.0) { $0 + $1.amount }
                        let catStr = cf.string(from: NSNumber(value: catTotal)) ?? "$\(catTotal)"
                        space(18)
                        text("  \(cat.label):  \(catStr)", font: .systemFont(ofSize: 12, weight: .medium), color: bodyText)
                        y += 2
                    }
                    y += 10
                }

                // Expense list
                if !expenses.isEmpty {
                    divider()
                    for exp in expenses {
                        space(20)
                        let dateStr = shortFmt.string(from: exp.wrappedDateIncurred)
                        let amtStr = cf.string(from: NSNumber(value: exp.amount)) ?? "$\(exp.amount)"
                        let savedY = y
                        text("\(dateStr)  •  \(exp.wrappedTitle)", font: .systemFont(ofSize: 11), color: bodyText, w: cw * 0.7)
                        // Right-align amount on same starting line
                        let as2 = sizeOf(amtStr, font: .monospacedDigitSystemFont(ofSize: 11, weight: .semibold))
                        draw(amtStr, at: CGPoint(x: pw - m - as2.width, y: savedY), font: .monospacedDigitSystemFont(ofSize: 11, weight: .semibold), color: headerDark)
                        y += 4
                    }
                }
                footer()
            }

            // ================================================================
            // ITINERARY
            // ================================================================
            let days = trip.daysArray

            // Group consecutive days by location
            var segments: [(location: String, days: [DayEntity])] = []
            for day in days {
                let loc = day.wrappedLocation.isEmpty ? trip.wrappedDestination : day.wrappedLocation
                if let last = segments.last, last.location == loc {
                    segments[segments.count - 1].days.append(day)
                } else {
                    segments.append((location: loc, days: [day]))
                }
            }
            let isMultiCity = segments.count > 1

            for seg in segments {
                // Location segment header (only for multi-city trips)
                if isMultiCity {
                    space(60)
                    y += 8
                    // Location header bar
                    fillRect(CGRect(x: m, y: y, width: cw, height: 32), color: accentBlue.withAlphaComponent(0.06), radius: 8)
                    draw("📍 \(seg.location.uppercased())", at: CGPoint(x: m + 12, y: y + 8), font: .systemFont(ofSize: 12, weight: .bold), color: accentBlue)
                    if let first = seg.days.first, let last = seg.days.last {
                        let rangeStr = first.dayNumber == last.dayNumber ? "Day \(first.dayNumber)" : "Days \(first.dayNumber)–\(last.dayNumber)"
                        let rs = sizeOf(rangeStr, font: .systemFont(ofSize: 10, weight: .medium))
                        draw(rangeStr, at: CGPoint(x: pw - m - rs.width - 12, y: y + 10), font: .systemFont(ofSize: 10, weight: .medium), color: subtitleGray)
                    }
                    y += 40
                }

                for day in seg.days {
                    space(80)

                    // Day header card
                    let dh: CGFloat = 40
                    let dayColor = dayAccentColor(day.dayNumber)
                    fillRect(CGRect(x: m, y: y, width: cw, height: dh), color: dayColor.withAlphaComponent(0.08), radius: 8)

                    // Left accent bar
                    let leftBar = UIBezierPath(roundedRect: CGRect(x: m, y: y, width: 4, height: dh), byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: CGSize(width: 4, height: 4))
                    dayColor.setFill(); leftBar.fill()

                    draw("DAY \(day.dayNumber)", at: CGPoint(x: m + 16, y: y + 6), font: .systemFont(ofSize: 14, weight: .heavy), color: dayColor)
                    draw(shortFmt.string(from: day.wrappedDate), at: CGPoint(x: m + 16, y: y + 23), font: .systemFont(ofSize: 11, weight: .regular), color: subtitleGray)

                    let scStr = "\(day.stopsArray.count) stop\(day.stopsArray.count == 1 ? "" : "s")"
                    let scSz = sizeOf(scStr, font: .systemFont(ofSize: 11, weight: .medium))
                    draw(scStr, at: CGPoint(x: pw - m - scSz.width - 12, y: y + 13), font: .systemFont(ofSize: 11, weight: .medium), color: lightGray)

                    y += dh + 12

                    if !day.wrappedNotes.isEmpty {
                        text(day.wrappedNotes, font: .italicSystemFont(ofSize: 10), color: subtitleGray)
                        y += 6
                    }

                    let stops = day.stopsArray
                    if stops.isEmpty {
                        text("No stops planned yet", font: .systemFont(ofSize: 11), color: lightGray)
                        y += 6
                    } else {
                        for (idx, stop) in stops.enumerated() {
                            space(55)
                            let cc = catColors[stop.category] ?? lightGray
                            let tx: CGFloat = m + 36

                            // Category color dot
                            let dotRect = CGRect(x: m + 6, y: y + 4, width: 10, height: 10)
                            fillRect(dotRect, color: cc, radius: 5)

                            // Time
                            var ts = ""
                            if let a = stop.arrivalTime { ts = timeFmt.string(from: a) }
                            if let d = stop.departureTime { ts += ts.isEmpty ? timeFmt.string(from: d) : " – \(timeFmt.string(from: d))" }
                            if !ts.isEmpty { text(ts, font: .systemFont(ofSize: 9, weight: .semibold), color: cc, x: tx, w: cw - 40) }

                            // Name
                            text(stop.wrappedName, font: .systemFont(ofSize: 13, weight: .semibold), color: headerDark, x: tx, w: cw - 40)

                            // Category badge
                            text(categoryLabel(stop.category), font: .systemFont(ofSize: 9, weight: .medium), color: cc, x: tx)

                            // Notes
                            if !stop.wrappedNotes.isEmpty {
                                text(stop.wrappedNotes, font: .italicSystemFont(ofSize: 9), color: subtitleGray, x: tx, w: cw - 40)
                            }

                            // Address
                            if let addr = stop.address, !addr.isEmpty {
                                text("📍 \(addr)", font: .systemFont(ofSize: 9), color: lightGray, x: tx, w: cw - 40)
                            }

                            y += 4

                            // Dashed connector
                            if idx < stops.count - 1 {
                                let cx = m + 11
                                ctx.cgContext.setStrokeColor(dividerColor.cgColor)
                                ctx.cgContext.setLineWidth(1)
                                ctx.cgContext.setLineDash(phase: 0, lengths: [3, 3])
                                ctx.cgContext.move(to: CGPoint(x: cx, y: y))
                                ctx.cgContext.addLine(to: CGPoint(x: cx, y: y + 6))
                                ctx.cgContext.strokePath()
                                ctx.cgContext.setLineDash(phase: 0, lengths: [])
                                y += 8
                            }
                        }
                    }
                    y += 16
                }
            }

            // ================================================================
            // CHECKLISTS
            // ================================================================
            let lists = trip.listsArray.filter { !$0.itemsArray.isEmpty }
            if !lists.isEmpty {
                space(60)
                divider()
                text("Checklists", font: .systemFont(ofSize: 22, weight: .bold), color: headerDark)
                y += 14

                for list in lists {
                    space(28)
                    let done = list.itemsArray.filter(\.isChecked).count
                    text("\(list.wrappedName)  (\(done)/\(list.itemsArray.count))", font: .systemFont(ofSize: 13, weight: .semibold), color: headerDark)
                    y += 4
                    for item in list.itemsArray {
                        space(18)
                        let ck = item.isChecked ? "☑" : "☐"
                        text("  \(ck)  \(item.wrappedText)", font: .systemFont(ofSize: 11), color: item.isChecked ? lightGray : bodyText)
                        y += 1
                    }
                    y += 10
                }
            }

            footer()
        }
    }

    // MARK: - Helpers

    private static func categoryLabel(_ category: StopCategory) -> String {
        switch category {
        case .accommodation: "Stay"
        case .restaurant: "Eat"
        case .attraction: "See"
        case .transport: "Transit"
        case .activity: "Do"
        case .other: "Other"
        }
    }

    private static func bookingColor(_ type: BookingType) -> UIColor {
        switch type {
        case .flight: UIColor(red: 0.20, green: 0.50, blue: 0.90, alpha: 1.0)
        case .hotel: UIColor(red: 0.56, green: 0.27, blue: 0.85, alpha: 1.0)
        case .carRental: UIColor(red: 0.92, green: 0.50, blue: 0.15, alpha: 1.0)
        case .other: UIColor(red: 0.55, green: 0.57, blue: 0.62, alpha: 1.0)
        }
    }

    private static func dayAccentColor(_ dayNumber: Int32) -> UIColor {
        let colors: [UIColor] = [
            UIColor(red: 0.20, green: 0.40, blue: 0.85, alpha: 1.0),
            UIColor(red: 0.20, green: 0.72, blue: 0.40, alpha: 1.0),
            UIColor(red: 0.92, green: 0.50, blue: 0.15, alpha: 1.0),
            UIColor(red: 0.56, green: 0.27, blue: 0.85, alpha: 1.0),
            UIColor(red: 0.90, green: 0.30, blue: 0.55, alpha: 1.0),
            UIColor(red: 0.85, green: 0.25, blue: 0.25, alpha: 1.0),
            UIColor(red: 0.15, green: 0.65, blue: 0.65, alpha: 1.0),
            UIColor(red: 0.30, green: 0.30, blue: 0.75, alpha: 1.0),
        ]
        return colors[Int(dayNumber - 1) % colors.count]
    }
}
