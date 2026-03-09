//
//  VideoFilterView.swift
//  Uncensored
//

import SwiftUI
import CoreImage

// MARK: - VideoFilter

/// All real-time filter presets available in the recorder.
enum VideoFilter: String, CaseIterable, Identifiable {
    case normal        = "Normal"
    case beautify      = "Beautify"
    case blackAndWhite = "B&W"
    case vintage       = "Vintage"
    case cool          = "Cool"
    case grayscale     = "Grayscale"
    case highContrast  = "High Contrast"
    case sepia         = "Sepia"
    case vivid         = "Vivid"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .normal:        return "camera"
        case .beautify:      return "sparkles"
        case .blackAndWhite: return "circle.lefthalf.filled"
        case .vintage:       return "photo.artframe"
        case .cool:          return "snowflake"
        case .grayscale:     return "circle.fill"
        case .highContrast:  return "sun.max.fill"
        case .sepia:         return "leaf.fill"
        case .vivid:         return "paintpalette.fill"
        }
    }

    /// Applies this filter to a CIImage (used during video post-processing/export).
    func apply(to image: CIImage) -> CIImage {
        switch self {
        case .normal:
            return image
        case .beautify:
            return image.applyingFilter("CIBloom",
                parameters: ["inputRadius": 5.0, "inputIntensity": 0.5])
        case .blackAndWhite, .grayscale:
            return image.applyingFilter("CIColorControls",
                parameters: ["inputSaturation": 0.0])
        case .vintage:
            return image
                .applyingFilter("CITemperatureAndTint", parameters: [
                    "inputNeutral": CIVector(x: 6500, y: 0),
                    "inputTargetNeutral": CIVector(x: 3000, y: 0)])
                .applyingFilter("CIColorControls", parameters: [
                    "inputBrightness": -0.05,
                    "inputContrast": 1.1])
        case .cool:
            return image.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: 6500, y: 0),
                "inputTargetNeutral": CIVector(x: 9500, y: 0)])
        case .highContrast:
            return image.applyingFilter("CIColorControls",
                parameters: ["inputContrast": 2.0])
        case .sepia:
            return image.applyingFilter("CISepiaTone",
                parameters: ["inputIntensity": 0.8])
        case .vivid:
            return image.applyingFilter("CIColorControls", parameters: [
                "inputSaturation": 2.0,
                "inputContrast": 1.2])
        }
    }
}

// MARK: - VideoFilterView

/// Vertical scrollable side panel that lets the user pick a filter.
struct VideoFilterView: View {
    @Binding var selectedFilter: VideoFilter

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                ForEach(VideoFilter.allCases) { filter in
                    filterButton(filter)
                }
            }
            .padding(.vertical, 16)
        }
        .frame(width: 72)
        .background(Color.black.opacity(0.55))
        .cornerRadius(16)
    }

    private func filterButton(_ filter: VideoFilter) -> some View {
        Button {
            selectedFilter = filter
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(selectedFilter == filter
                              ? Color.white
                              : Color.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: filter.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(selectedFilter == filter ? .black : .white)
                }
                Text(filter.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}
