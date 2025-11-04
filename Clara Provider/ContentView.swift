//
//  ContentView.swift
//  Clara Provider
//
//  Created by Michael Hobbs on 10/22/25.
//

import SwiftUI

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
                let id = UUID(uuidString: req.conversationId) ?? UUID()
                items.append(PatientListItem(id: id, userId: req.userId, name: name))
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
            print("🔍 Fetching patients from Supabase...")
            let results = try await ProviderSupabaseService.shared.fetchPatients()
            print("✅ Fetched \(results.count) patients from Supabase")
            
            // Also try to get patients from review requests as fallback
            if results.isEmpty {
                print("⚠️ No patients from patients table, using review requests as fallback")
                await store.loadReviewRequests()
                let fallbackPatients = patientsFromStore
                await MainActor.run {
                    self.patients = fallbackPatients
                    isLoadingPatients = false
                }
                print("📋 Using \(fallbackPatients.count) patients from review requests")
            } else {
                let mapped: [PatientListItem] = results.map { p in
                    // Use the patient's id as a stable UUID if provided; otherwise generate
                    let uuid = p.id
                    let display = (p.name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Patient"
                    print("   Patient: \(display) (ID: \(uuid), UserID: \(p.userId))")
                    return PatientListItem(id: uuid, userId: p.userId, name: display)
                }
                await MainActor.run {
                    self.patients = mapped
                    isLoadingPatients = false
                    print("📊 Loaded \(mapped.count) patients into menu")
                }
            }
        } catch {
            await MainActor.run { isLoadingPatients = false }
            print("❌ Error fetching patients: \(error)")
            
            // Fallback to review requests if patients table fails
            print("🔄 Falling back to patients from review requests...")
            await store.loadReviewRequests()
            let fallbackPatients = patientsFromStore
            await MainActor.run {
                self.patients = fallbackPatients
            }
            print("📋 Using \(fallbackPatients.count) patients from review requests")
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
