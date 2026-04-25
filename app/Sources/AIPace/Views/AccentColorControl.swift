import SwiftUI

struct AccentColorControl: View {
    @Binding var hexValue: String
    let fallbackColor: Color
    let resetLabel: String

    @FocusState private var isFocused: Bool
    @State private var draftHex = ""

    var body: some View {
        HStack(spacing: 8) {
            ColorPicker(
                "",
                selection: Binding(
                    get: { AppColorHex.color(from: hexValue) ?? fallbackColor },
                    set: { newColor in
                        guard let resolvedHex = AppColorHex.string(from: newColor) else {
                            return
                        }
                        hexValue = resolvedHex
                        draftHex = resolvedHex
                    }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            .frame(width: 32)

            TextField("#F26B1D", text: $draftHex)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 96)
                .focused($isFocused)
                .onSubmit(commitDraft)
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        commitDraft()
                    }
                }
                .onChange(of: hexValue) { _, _ in
                    if !isFocused {
                        syncDraft()
                    }
                }

            Button(resetLabel) {
                hexValue = ""
                draftHex = ""
            }
            .buttonStyle(.borderless)
            .disabled(AppColorHex.normalized(hexValue) == nil)
            .pointerOnHover()
        }
        .onAppear(perform: syncDraft)
    }

    private func commitDraft() {
        let trimmed = draftHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            hexValue = ""
            draftHex = ""
            return
        }

        guard let normalized = AppColorHex.normalized(trimmed) else {
            syncDraft()
            return
        }

        hexValue = normalized
        draftHex = normalized
    }

    private func syncDraft() {
        draftHex = AppColorHex.normalized(hexValue) ?? ""
    }
}
