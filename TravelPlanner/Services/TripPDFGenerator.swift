import UIKit
import SwiftUI
import TripCore

/// Generates a clean PDF itinerary for a trip.
struct TripPDFGenerator {

    static func generatePDF(for trip: TripEntity) -> Data {
        let pageWidth: CGFloat = 612  // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        let data = renderer.pdfData { context in
            var yOffset: CGFloat = 0

            func startNewPage() {
                context.beginPage()
                yOffset = margin
            }

            func ensureSpace(_ needed: CGFloat) {
                if yOffset + needed > pageHeight - margin {
                    startNewPage()
                }
            }

            func drawText(_ text: String, font: UIFont, color: UIColor = .black, x: CGFloat = margin, maxWidth: CGFloat? = nil) -> CGFloat {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                let width = maxWidth ?? contentWidth
                let constraintSize = CGSize(width: width, height: .greatestFiniteMagnitude)
                let boundingRect = (text as NSString).boundingRect(
                    with: constraintSize,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs,
                    context: nil
                )
                let drawRect = CGRect(x: x, y: yOffset, width: width, height: boundingRect.height)
                (text as NSString).draw(in: drawRect, withAttributes: attrs)
                let height = boundingRect.height
                yOffset += height
                return height
            }

            func drawDivider() {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: yOffset))
                path.addLine(to: CGPoint(x: pageWidth - margin, y: yOffset))
                UIColor.lightGray.setStroke()
                path.lineWidth = 0.5
                path.stroke()
                yOffset += 8
            }

            // === PAGE 1: Title Page ===
            startNewPage()
            yOffset = pageHeight * 0.3

            _ = drawText(trip.name, font: .systemFont(ofSize: 28, weight: .bold), color: .black)
            yOffset += 8
            _ = drawText(trip.destination, font: .systemFont(ofSize: 18), color: .darkGray)
            yOffset += 4
            let dateRange = "\(dateFormatter.string(from: trip.startDate)) – \(dateFormatter.string(from: trip.endDate))"
            _ = drawText(dateRange, font: .systemFont(ofSize: 14), color: .gray)
            yOffset += 4
            _ = drawText("\(trip.durationInDays) days", font: .systemFont(ofSize: 14), color: .gray)

            if !trip.notes.isEmpty {
                yOffset += 20
                _ = drawText(trip.notes, font: .italicSystemFont(ofSize: 12), color: .darkGray)
            }

            // === Bookings Page ===
            let sortedBookings = trip.bookings.sorted { $0.sortOrder < $1.sortOrder }
            if !sortedBookings.isEmpty {
                startNewPage()
                _ = drawText("Bookings", font: .systemFont(ofSize: 22, weight: .bold))
                yOffset += 12

                for booking in sortedBookings {
                    ensureSpace(80)
                    _ = drawText("[\(booking.bookingType.label.uppercased())]", font: .systemFont(ofSize: 10, weight: .semibold), color: .gray)
                    yOffset += 2
                    _ = drawText(booking.title, font: .systemFont(ofSize: 14, weight: .semibold))

                    if !booking.confirmationCode.isEmpty {
                        _ = drawText("Confirmation: \(booking.confirmationCode)", font: .monospacedSystemFont(ofSize: 11, weight: .regular), color: .darkGray)
                    }

                    // Flight specifics
                    if booking.bookingType == .flight {
                        if let airline = booking.airline, !airline.isEmpty {
                            _ = drawText("Airline: \(airline)", font: .systemFont(ofSize: 11), color: .darkGray)
                        }
                        if let dep = booking.departureAirport, let arr = booking.arrivalAirport {
                            _ = drawText("\(dep) → \(arr)", font: .systemFont(ofSize: 11), color: .darkGray)
                        }
                        if let time = booking.departureTime {
                            _ = drawText("Departs: \(dateFormatter.string(from: time)) \(timeFormatter.string(from: time))", font: .systemFont(ofSize: 11), color: .darkGray)
                        }
                        if let time = booking.arrivalTime {
                            _ = drawText("Arrives: \(dateFormatter.string(from: time)) \(timeFormatter.string(from: time))", font: .systemFont(ofSize: 11), color: .darkGray)
                        }
                    }

                    // Hotel specifics
                    if booking.bookingType == .hotel {
                        if let name = booking.hotelName, !name.isEmpty {
                            _ = drawText("Hotel: \(name)", font: .systemFont(ofSize: 11), color: .darkGray)
                        }
                        if let addr = booking.hotelAddress, !addr.isEmpty {
                            _ = drawText("Address: \(addr)", font: .systemFont(ofSize: 11), color: .darkGray)
                        }
                        if let checkIn = booking.checkInDate {
                            _ = drawText("Check-in: \(dateFormatter.string(from: checkIn))", font: .systemFont(ofSize: 11), color: .darkGray)
                        }
                        if let checkOut = booking.checkOutDate {
                            _ = drawText("Check-out: \(dateFormatter.string(from: checkOut))", font: .systemFont(ofSize: 11), color: .darkGray)
                        }
                    }

                    if !booking.notes.isEmpty {
                        _ = drawText(booking.notes, font: .italicSystemFont(ofSize: 10), color: .gray)
                    }

                    yOffset += 12
                    drawDivider()
                }
            }

            // === Itinerary Pages ===
            let sortedDays = trip.days.sorted { $0.dayNumber < $1.dayNumber }

            for day in sortedDays {
                ensureSpace(60)
                _ = drawText("Day \(day.dayNumber) — \(dateFormatter.string(from: day.date))", font: .systemFont(ofSize: 18, weight: .bold))
                yOffset += 4

                if !day.notes.isEmpty {
                    _ = drawText(day.notes, font: .italicSystemFont(ofSize: 11), color: .gray)
                    yOffset += 4
                }

                let sortedStops = day.stops.sorted { $0.sortOrder < $1.sortOrder }

                if sortedStops.isEmpty {
                    _ = drawText("No stops planned", font: .systemFont(ofSize: 11), color: .lightGray)
                    yOffset += 8
                } else {
                    for stop in sortedStops {
                        ensureSpace(50)

                        // Category badge + name
                        let catLabel = categoryLabel(stop.category)
                        _ = drawText("• \(catLabel): \(stop.name)", font: .systemFont(ofSize: 13, weight: .medium))

                        // Time
                        var timeStr = ""
                        if let arrival = stop.arrivalTime {
                            timeStr += timeFormatter.string(from: arrival)
                        }
                        if let departure = stop.departureTime {
                            timeStr += timeStr.isEmpty ? timeFormatter.string(from: departure) : " – \(timeFormatter.string(from: departure))"
                        }
                        if !timeStr.isEmpty {
                            _ = drawText("   \(timeStr)", font: .systemFont(ofSize: 10), color: .gray)
                        }

                        if !stop.notes.isEmpty {
                            _ = drawText("   \(stop.notes)", font: .italicSystemFont(ofSize: 10), color: .gray)
                        }

                        yOffset += 6
                    }
                }

                yOffset += 8
                drawDivider()
            }

            // Footer on last page
            yOffset += 20
            ensureSpace(30)
            _ = drawText("Generated by TravelPlanner", font: .systemFont(ofSize: 9), color: .lightGray)
        }

        return data
    }

    private static func categoryLabel(_ category: StopCategory) -> String {
        switch category {
        case .accommodation: return "Stay"
        case .restaurant: return "Eat"
        case .attraction: return "See"
        case .transport: return "Transit"
        case .activity: return "Do"
        case .other: return "Other"
        }
    }
}
