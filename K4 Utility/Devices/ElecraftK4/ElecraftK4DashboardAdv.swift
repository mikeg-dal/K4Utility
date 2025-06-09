import SwiftUI

struct ElecraftK4DashboardAdv: View {
    @EnvironmentObject var settingsStore: SettingsStore

    @State private var eqSettings: [Int: Double] = [:]
    @State private var presetNameInput: String = ""
    @State private var selectedPresetName: String = UserDefaults.standard.string(forKey: "k4SelectedEQPreset") ?? "Default"
    @State private var selectedPage: Int = 1
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Page selector header
            HStack {
                ForEach(1...3, id: \.self) { page in
                    Button(action: { selectedPage = page }) {
                        Image(systemName: selectedPage == page ? "\(page).circle.fill" : "\(page).circle")
                            .foregroundStyle(selectedPage == page ? .white : .primary)
                            .background(
                                Circle()
                                    .fill(selectedPage == page ? Color.red : Color.clear)
                                    .frame(width: 24, height: 24)
                            )
                    }
                    .buttonStyle(.borderless)
                }
                Spacer()
            }
            .padding(.bottom, 4)

            Group {
                switch selectedPage {
                case 1:
                    VStack(alignment: .leading, spacing: 1) {
                        Text("TX")
                            .font(.title2)
                            .bold()

                        HStack(spacing: 8) {
                            ForEach(eqSettings.keys.sorted(), id: \.self) { freq in
                                VStack(spacing: 4) {
                                    Text(String(format: "%.0f", eqSettings[freq] ?? 0))
                                        .font(.caption2)
                                    VerticalSlider(value: Binding(
                                        get: { eqSettings[freq, default: 0] },
                                        set: {
                                            eqSettings[freq] = $0
                                            var presets = settingsStore.settings.k4EQPresets
                                            presets[selectedPresetName] = eqSettings
                                            settingsStore.settings.k4EQPresets = presets
                                        }
                                    ), range: -16...16, step: 1)
                                    .frame(height: 100)
                                    Text(freq >= 1000 ? String(format: "%.1f KHz", Double(freq)/1000.0) : "\(freq) Hz")
                                        .font(.caption)
                                }
                                .frame(width: 25)
                                .scaleEffect(0.85)
                            }
                        }

                        HStack {
                            Picker("TX", selection: $selectedPresetName) {
                                ForEach(Array(settingsStore.settings.k4EQPresets.keys), id: \.self) { name in
                                    Text(name).tag(name)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 80)
                            .onChange(of: selectedPresetName) { oldValue, newValue in
                                eqSettings = settingsStore.settings.k4EQPresets[newValue, default: defaultEQ()]
                            }

                            TextField("Name", text: $presetNameInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60)

                            Button("Save") {
                                var presets = settingsStore.settings.k4EQPresets
                                presets[presetNameInput] = eqSettings
                                settingsStore.settings.k4EQPresets = presets
                                selectedPresetName = presetNameInput
                            }

                            Button("Delete") {
                                if selectedPresetName != "Default" {
                                    var presets = settingsStore.settings.k4EQPresets
                                    presets.removeValue(forKey: selectedPresetName)
                                    settingsStore.settings.k4EQPresets = presets
                                    selectedPresetName = "Default"
                                    eqSettings = settingsStore.settings.k4EQPresets["Default", default: defaultEQ()]
                                }
                            }
                            .disabled(selectedPresetName == "Default")
                        }
                        .padding(.top)
                    }
                case 2:
                    Text("Page 2: Future audio controls here")
                        .foregroundColor(.gray)
                case 3:
                    Text("Page 3: Additional settings")
                        .foregroundColor(.gray)
                default:
                    EmptyView()
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .onAppear {
            selectedPresetName = settingsStore.settings.k4SelectedEQPreset
            eqSettings = settingsStore.settings.k4EQPresets[selectedPresetName, default: defaultEQ()]
        }
    }

    private func defaultEQ() -> [Int: Double] {
        [100: 0, 200: 0, 400: 0, 800: 0, 1200: 0, 1600: 0, 2400: 0, 3200: 0]
    }
}

#Preview {
    let previewStore = SettingsStore()
    previewStore.settings.k4EQPresets = [
        "Default": [100: 0, 200: 3, 400: -2, 800: 1, 1200: 0, 1600: -1, 2400: 4, 3200: -3],
        "Flat": [100: 0, 200: 0, 400: 0, 800: 0, 1200: 0, 1600: 0, 2400: 0, 3200: 0]
    ]
    previewStore.settings.k4SelectedEQPreset = "Default"
    
    return ElecraftK4DashboardAdv()
        .environmentObject(previewStore)
        .frame(width: 400, height: 250)
        .padding()
}

// MARK: - VerticalSlider for macOS
struct VerticalSlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(value: value, minValue: range.lowerBound, maxValue: range.upperBound, target: context.coordinator, action: #selector(Coordinator.valueChanged(_:)))
        slider.numberOfTickMarks = Int((range.upperBound - range.lowerBound) / step) + 1
        slider.allowsTickMarkValuesOnly = false
        slider.isVertical = true
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        nsView.doubleValue = value
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: VerticalSlider

        init(_ parent: VerticalSlider) {
            self.parent = parent
        }

        @objc func valueChanged(_ sender: NSSlider) {
            parent.value = sender.doubleValue
        }
    }
}
