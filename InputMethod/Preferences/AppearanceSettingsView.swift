import SwiftUI
import CoreIME
import CommonExtensions

struct AppearanceSettingsView: View {

        @State private var lineSpacing: Int = AppSettings.candidateLineSpacing
        @State private var pageCornerRadius: Int = AppSettings.pageCornerRadius
        @State private var contentInsets: Int = AppSettings.contentInsets
        @State private var innerCornerRadius: Int = AppSettings.innerCornerRadius
        private let lineSpacingRange: ClosedRange<Int> = AppSettings.candidateLineSpacingRange
        private let cornerRadiusRange: ClosedRange<Int> = AppSettings.cornerRadiusRange

        @State private var isThickerGlassPreferred = AppSettings.isThickerGlassPreferred

        var body: some View {
                ScrollView {
                        LazyVStack(alignment: .leading) {
                                Form {
                                        Section {
                                                Picker("AppearanceSettingsView.CandidateLineSpacing.PickerTitle", selection: $lineSpacing) {
                                                        ForEach(lineSpacingRange, id: \.self) {
                                                                Text(verbatim: "\($0) pt").tag($0)
                                                        }
                                                }
                                                .pickerStyle(.menu)
                                                .onChange(of: lineSpacing) { newLineSpacing in
                                                        AppSettings.updateCandidateLineSpacing(to: newLineSpacing)
                                                }
                                                Picker("AppearanceSettingsView.CandidatePageCornerRadius.PickerTitle", selection: $pageCornerRadius) {
                                                        ForEach(cornerRadiusRange, id: \.self) {
                                                                Text(verbatim: "\($0) pt").tag($0)
                                                        }
                                                }
                                                .pickerStyle(.menu)
                                                .onChange(of: pageCornerRadius) { newValue in
                                                        AppSettings.updatePageCornerRadius(to: newValue)
                                                }
                                                Picker("AppearanceSettingsView.CandidatePageInsets.PickerTitle", selection: $contentInsets) {
                                                        ForEach(cornerRadiusRange, id: \.self) {
                                                                Text(verbatim: "\($0) pt").tag($0)
                                                        }
                                                }
                                                .pickerStyle(.menu)
                                                .onChange(of: contentInsets) { newValue in
                                                        AppSettings.updateContentInsets(to: newValue)
                                                }
                                                Picker("AppearanceSettingsView.CandidateCornerRadius.PickerTitle", selection: $innerCornerRadius) {
                                                        ForEach(cornerRadiusRange, id: \.self) {
                                                                Text(verbatim: "\($0) pt").tag($0)
                                                        }
                                                }
                                                .pickerStyle(.menu)
                                                .onChange(of: innerCornerRadius) { newValue in
                                                        AppSettings.updateInnerCornerRadius(to: newValue)
                                                }
                                        }
                                        if #available(macOS 26.0, *) {
                                                Section {
                                                        Toggle("AppearanceSettingsView.EnhancedGlass.Thicker.ToggleTitle", isOn: $isThickerGlassPreferred)
                                                                .toggleStyle(.switch)
                                                                .onChange(of: isThickerGlassPreferred) { isOn in
                                                                        AppSettings.updatePreferredThickerGlass(to: isOn)
                                                                }
                                                }
                                        }
                                }
                                .formStyle(.grouped)
                                .scrollContentBackground(.hidden)
                                .stack(cornerRadius: 16)
                                .frame(maxWidth: 480)
                        }
                        .padding(8)
                }
                .navigationTitle("AppearanceSettingsView.NavigationTitle.TitleKey")
        }
}
