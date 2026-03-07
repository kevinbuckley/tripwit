import SwiftUI

// MARK: - StopRatingView

/// A reusable 1–5 star rating control backed by an `Int32` binding.
///
/// - Tapping a filled star toggles the rating back to 0 (deselects it).
/// - Each tap fires a light haptic impact.
/// - Stars animate in/out with a spring bounce when the rating changes.
/// - An optional `onChange` closure is called after every rating update
///   (use it to persist the new value, e.g. `try? viewContext.save()`).
struct StopRatingView: View {

    @Binding var rating: Int32
    var onChange: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { star in
                let filled = star <= Int(rating)
                Image(systemName: filled ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(filled ? .yellow : Color(.systemGray4))
                    .scaleEffect(filled ? 1.0 : 0.85)
                    .animation(.spring(duration: 0.25, bounce: 0.45), value: rating)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.25, bounce: 0.45)) {
                            // Tap the active star → clear; tap another → set it
                            rating = (rating == Int32(star)) ? 0 : Int32(star)
                        }
                        HapticsManager.shared.light()
                        onChange?()
                    }
            }

            if rating > 0 {
                Text("\(rating) / 5")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.2), value: rating)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var rating: Int32 = 3
    return VStack(spacing: 20) {
        StopRatingView(rating: $rating)
        StopRatingView(rating: .constant(0))
        StopRatingView(rating: .constant(5))
    }
    .padding()
}
