import SwiftUI

struct WatermarkEditorView: View {
    @ObservedObject var controller: PDFEditorController
    @Environment(\.dismiss) var dismiss

    @State private var text = "DRAFT"
    @State private var color: Color = .red
    @State private var opacity: Double = 0.3

    private let presetTexts = ["DRAFT", "CONFIDENTIAL", "FINAL", "APPROVED", "COPY"]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Watermark Text")) {
                    TextField("Text", text: $text)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(presetTexts, id: \.self) { preset in
                                Button(preset) {
                                    text = preset
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }

                Section(header: Text("Appearance")) {
                    ColorPicker("Color", selection: $color)

                    VStack(alignment: .leading) {
                        Text("Opacity: \(Int(opacity * 100))%")
                        Slider(value: $opacity, in: 0.1...1.0)
                    }
                }

                Section {
                    Button {
                        controller.applyWatermarkToAllPages(text: text, color: color, opacity: opacity)
                        dismiss()
                    } label: {
                        Text("Apply to All Pages")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Batch Watermark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
