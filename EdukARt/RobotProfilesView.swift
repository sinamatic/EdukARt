import SwiftUI

struct RobotProfilesView: View {
    @ObservedObject var controller: RobotController
    @State private var profiles = RobotProfileStore.shared
    @State private var expanded = false
    @State private var settingsExpanded = false
    @State private var showingAddRobot = false
    @State private var newName = ""
    @State private var editingProfile: RobotProfile?
    @State private var deletingProfile: RobotProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                HStack {
                    Label("Robots", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    if let profile = profiles.selectedProfile {
                        Text(profile.name)
                            .font(.caption)
                    }
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            if expanded {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                    ForEach(profiles.profiles) { profile in
                        RobotSelectionButton(
                            profile: profile,
                            isSelected: profile.id == profiles.selectedID
                        ) {
                            controller.selectRobotProfile(profile.id)
                            settingsExpanded = false
                        }
                    }
                }

                if !controller.bridgeStatus.isEmpty {
                    Text(controller.bridgeStatus)
                        .font(.callout)
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                }

                if let selected = profiles.selectedProfile,
                   let store = profiles.settings(for: selected.id),
                   store.data(forKey: RobotSetupConfiguration.key) != nil {
                    RobotDebuggingView(controller: controller, store: store, profile: selected.id)
                        .id(selected.id)
                }

                if let selected = profiles.selectedProfile {
                    DisclosureGroup(isExpanded: $settingsExpanded) {
                        RobotProfileDetails(profile: selected, profiles: profiles) {
                            controller.prepareForRobotProfileChange()
                            editingProfile = selected
                        } onDelete: {
                            deletingProfile = selected
                        }
                        .id(selected.id)
                        .padding(.top, 8)
                    } label: {
                        Label("\(selected.name) Settings", systemImage: "gearshape")
                            .font(.subheadline)
                    }
                    .tint(.white)
                } else {
                    Text("Add a robot to configure its ROS settings.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Button {
                    newName = ""
                    showingAddRobot = true
                } label: {
                    Label("Add Robot", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }
        }
        .padding(14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .alert("Add Robot", isPresented: $showingAddRobot) {
            TextField("Robot name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                if let profile = profiles.add(name: newName) {
                    controller.selectRobotProfile(profile.id)
                    settingsExpanded = true
                }
            }
            .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .alert("Delete Robot?", isPresented: Binding(
            get: { deletingProfile != nil },
            set: { if !$0 { deletingProfile = nil } }
        )) {
            Button("Cancel", role: .cancel) { deletingProfile = nil }
            Button("Delete", role: .destructive) {
                if let profile = deletingProfile {
                    controller.deleteRobotProfile(profile.id)
                }
                deletingProfile = nil
                settingsExpanded = false
            }
        } message: {
            Text("The robot and its saved ROS settings will be deleted.")
        }
        .sheet(item: $editingProfile, onDismiss: { controller.eduard.reconnect() }) { profile in
            if let store = profiles.settings(for: profile.id) {
                NavigationStack {
                    Group {
                        if store.data(forKey: RobotSetupConfiguration.key) != nil {
                            RobotSetupView(store: store, profile: profile.id)
                        } else {
                            RobotROSSettingsView(store: store)
                        }
                    }
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                if store.data(forKey: RobotSetupConfiguration.key) == nil {
                                    Button("Done") { editingProfile = nil }
                                }
                            }
                        }
                }
            }
        }
    }
}

private struct RobotSelectionButton: View {
    let profile: RobotProfile
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Label(profile.name, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(
                    isSelected ? Color.green.opacity(0.8) : Color.white.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct RobotProfileDetails: View {
    let profile: RobotProfile
    let profiles: RobotProfileStore
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var name = ""
    @State private var aprilTagNumber = ""

    private var validTagNumber: Bool {
        aprilTagNumber.isEmpty || (Int(aprilTagNumber).map { $0 >= 0 } ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Robot name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Robot name")
                Button("Save") { profiles.rename(profile.id, to: name) }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name == profile.name)
            }
            Text("April Tag Number")
                .font(.caption)
            HStack {
                TextField("Not configured", text: $aprilTagNumber)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("April Tag Number")
                Button("Save") {
                    profiles.setAprilTagNumber(Int(aprilTagNumber), for: profile.id)
                }
                .disabled(!validTagNumber || aprilTagNumber == (profile.aprilTagNumber.map(String.init) ?? ""))
            }
            Text("Robot marker for localization. Excluded from map creation. Leave empty if no tag is assigned.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !validTagNumber {
                Text("Enter a whole number greater than or equal to 0.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Button(action: onEdit) {
                Label("ROS Settings", systemImage: "slider.horizontal.3")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete Robot", systemImage: "trash")
            }
        }
        .buttonStyle(.bordered)
        .onAppear {
            name = profile.name
            aprilTagNumber = profile.aprilTagNumber.map(String.init) ?? ""
        }
    }
}
