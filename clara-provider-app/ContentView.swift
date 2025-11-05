//
//  ContentView.swift
//  Clara Provider
//
//  Created by Michael Hobbs on 10/22/25.
//

import SwiftUI
import os.log

private struct PatientListItem: Identifiable, Hashable {
    let id: UUID        // representative conversation UUID for routing
    let userId: String  // stable user identifier
    let name: String
}

struct PatientProfileDestination: Hashable {
    let childId: UUID?
    let childName: String?
    let childAge: String?
}

struct ContentView: View {
    @EnvironmentObject var store: ProviderConversationStore
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.colorScheme) var colorScheme
    @State private var isMenuOpen: Bool = false
    @State private var path = NavigationPath()
    
    @State private var patients: [PatientListItem] = []
    @State private var isLoadingPatients: Bool = false
    
    private var patientsFromStore: [PatientListItem] {
        var seen = Set<String>()
        var items: [PatientListItem] = []
        for req in store.reviewRequests {
            let key = req.userId // use userId to uniquely identify a patient
            if !seen.contains(key) {
                seen.insert(key)
                let name = (req.childName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Patient \(items.count + 1)"

                // CRITICAL FIX: Validate UUID format before adding to list
                // Creating a random UUID if parsing fails leads to opening wrong patient's data
                // This was a HIPAA violation risk - provider could see wrong patient's medical history
                if let validUUID = UUID(uuidString: req.conversationId) {
                    items.append(PatientListItem(id: validUUID, userId: req.userId, name: name))
                } else {
                    // Log data integrity issue but don't add invalid entry
                    os_log("[ContentView] Invalid conversation UUID format for patient: %{public}s (ID: %{public}s)", log: .default, type: .error, name, req.conversationId)
                }
            }
        }
        // Sort alphabetically by name for a nicer menu
        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        ZStack {
            // Main background
            Color.adaptiveBackground(for: colorScheme)
                .ignoresSafeArea()
            
            NavigationStack(path: $path) {
                ConversationListView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: {
                                HapticFeedback.light()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isMenuOpen.toggle() }
                            }) {
                                Image(systemName: "person.2")
                                    .imageScale(.large)
                                    .foregroundColor(.primaryCoral)
                            }
                            .accessibilityLabel("Open menu")
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: {
                                HapticFeedback.light()
                                withAnimation {
                                    isMenuOpen = false
                                    path = NavigationPath()
                                }
                                Task { @MainActor in
                                    authManager.lock()
                                }
                            }) {
                                Image(systemName: "lock.fill")
                                    .imageScale(.medium)
                                    .foregroundColor(.primaryCoral)
                            }
                            .accessibilityLabel("Lock app")
                        }
                    }
                    .navigationDestination(for: PatientListItem.self) { patient in
                        PatientChartView(
                            userId: patient.userId,
                            name: patient.name
                        )
                        .environmentObject(store)
                    }
                    .navigationDestination(for: UUID.self) { conversationId in
                        ConversationDetailView(conversationId: conversationId)
                            .environmentObject(store)
                    }
                    .navigationDestination(for: PatientProfileDestination.self) { destination in
                        PatientProfileView(
                            childId: destination.childId,
                            childName: destination.childName,
                            childAge: destination.childAge
                        )
                        .environmentObject(store)
                    }
            }
            .background(Color.adaptiveBackground(for: colorScheme).ignoresSafeArea())
            .environmentObject(store)
            .disabled(isMenuOpen) // prevent interaction when menu is open
            .overlay(
                Group {
                    if isMenuOpen {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isMenuOpen = false } }
                    }
                }
            )
            .task {
                await loadPatients()
            }

            // Floating undocked menu - iOS 26 style
            if isMenuOpen {
                SideMenuView(
                    close: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isMenuOpen = false }
                    },
                    patients: patients,
                    onSelectPatient: { patient in
                        path.append(patient)
                    }
                )
                .frame(maxWidth: 320)
                .padding(.leading, 16)
                .padding(.top, 60)
                .padding(.bottom, 20)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
    }
    
    private func loadPatients() async {
        await MainActor.run { isLoadingPatients = true }
        do {
            os_log("[ContentView] Fetching patients from Supabase", log: .default, type: .info)
            let results = try await ProviderSupabaseService.shared.fetchPatients()
            os_log("[ContentView] Fetched %d patients from Supabase", log: .default, type: .info, results.count)

            // Also try to get patients from review requests as fallback
            if results.isEmpty {
                os_log("[ContentView] No patients from patients table, using review requests as fallback", log: .default, type: .info)
                await store.loadReviewRequests()
                let fallbackPatients = patientsFromStore
                await MainActor.run {
                    self.patients = fallbackPatients
                    isLoadingPatients = false
                }
                os_log("[ContentView] Using %d patients from review requests", log: .default, type: .info, fallbackPatients.count)
            } else {
                let mapped: [PatientListItem] = results.map { p in
                    // Use the patient's id as a stable UUID if provided; otherwise generate
                    let uuid = p.id
                    let display = (p.name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Patient"
                    os_log("[ContentView] Patient: %{public}s (ID: %{public}s, UserID: %{public}s)", log: .default, type: .debug, display, uuid.uuidString, p.userId)
                    return PatientListItem(id: uuid, userId: p.userId, name: display)
                }
                await MainActor.run {
                    self.patients = mapped
                    isLoadingPatients = false
                    os_log("[ContentView] Loaded %d patients into menu", log: .default, type: .info, mapped.count)
                }
            }
        } catch {
            await MainActor.run { isLoadingPatients = false }
            os_log("[ContentView] Error fetching patients: %{public}s", log: .default, type: .error, error.localizedDescription)

            // Fallback to review requests if patients table fails
            os_log("[ContentView] Falling back to patients from review requests", log: .default, type: .info)
            await store.loadReviewRequests()
            let fallbackPatients = patientsFromStore
            await MainActor.run {
                self.patients = fallbackPatients
            }
            os_log("[ContentView] Using %d patients from review requests", log: .default, type: .info, fallbackPatients.count)
        }
    }
}

private struct SideMenuView: View {
    var close: () -> Void
    var patients: [PatientListItem] = []
    var onSelectPatient: (PatientListItem) -> Void = { _ in }
    @State private var searchText: String = ""
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .imageScale(.large)
                    .foregroundColor(.primaryCoral)
                Text("Patients")
                    .font(.rethinkSansBold(17, relativeTo: .headline))
                    .foregroundColor(Color.adaptiveLabel(for: colorScheme))
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.medium)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Close menu")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search patients", text: $searchText)
                    .font(.rethinkSans(17, relativeTo: .body))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(10)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()
                .padding(.bottom, 0)

            // Patients list
            if patients.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Patients")
                        .font(.rethinkSansBold(17, relativeTo: .headline))
                    Text("No patients found")
                        .font(.rethinkSans(15, relativeTo: .subheadline))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredPatients, id: \.self) { item in
                            Button {
                                HapticFeedback.medium()
                                onSelectPatient(item)
                                close()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.primaryCoral)
                                    
                                    Text(item.name)
                                        .font(.rethinkSansBold(15, relativeTo: .subheadline))
                                        .foregroundColor(Color.adaptiveLabel(for: colorScheme))
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(Color.clear)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if item.id != filteredPatients.last?.id {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.adaptiveBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.1), radius: 40, x: 0, y: 16)
    }
    
    private var filteredPatients: [PatientListItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return patients }
        return patients.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}

#Preview {
    ContentView()
        .environmentObject(ProviderConversationStore())
}
