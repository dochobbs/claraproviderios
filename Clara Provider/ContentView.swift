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

struct ContentView: View {
    @EnvironmentObject var store: ProviderConversationStore
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
        ZStack(alignment: .leading) {
            // Main background
            Color.adaptiveBackground(for: colorScheme)
                .ignoresSafeArea()
            
            NavigationStack(path: $path) {
                ConversationListView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isMenuOpen.toggle() } }) {
                                Image(systemName: "line.3.horizontal")
                                    .imageScale(.large)
                                    .foregroundColor(.primaryCoral)
                            }
                            .accessibilityLabel("Open menu")
                        }
                    }
                    .navigationDestination(for: PatientListItem.self) { patient in
                        PatientChartView(
                            userId: patient.userId,
                            name: patient.name
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
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                            .onTapGesture { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isMenuOpen = false } }
                    }
                }
            )
            .task {
                await loadPatients()
            }

            // Simple slide-in side menu with rounded trailing edge
            SideMenuView(
                close: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isMenuOpen = false }
                },
                patients: patients,
                onSelectPatient: { patient in
                    path.append(patient)
                }
            )
            .frame(maxWidth: 280)
            .offset(x: isMenuOpen ? 0 : -320)
            .transition(.move(edge: .leading))
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 4, y: 0)
            .clipShape(
                .rect(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 16,
                    topTrailingRadius: 16
                )
            )
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
        ZStack(alignment: .topLeading) {
            // Background panel - match app aesthetic
            Rectangle()
                .fill(Color.adaptiveBackground(for: colorScheme))
                .ignoresSafeArea()

            // Menu content
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .imageScale(.large)
                        .foregroundColor(.primaryCoral)
                        .shadow(color: .clear, radius: 0)
                    Text("Patients")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.adaptiveLabel(for: colorScheme))
                        .shadow(color: .clear, radius: 0)
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark.circle.fill")
                            .imageScale(.medium)
                            .foregroundColor(.secondary)
                            .shadow(color: .clear, radius: 0)
                    }
                    .accessibilityLabel("Close menu")
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 12)

                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search patients", text: $searchText)
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
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                Divider()
                    .padding(.bottom, 0)

                // Patients list
                if patients.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Patients")
                            .font(.headline)
                        Text("No patients found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredPatients, id: \.self) { item in
                                Button {
                                    onSelectPatient(item)
                                    close()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "person.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.primaryCoral)
                                            .shadow(color: .clear, radius: 0)
                                        
                                        Text(item.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(Color.adaptiveLabel(for: colorScheme))
                                            .shadow(color: .clear, radius: 0)
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .shadow(color: .clear, radius: 0)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color.clear)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if item.id != filteredPatients.last?.id {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
        }
        .frame(width: 280)
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
