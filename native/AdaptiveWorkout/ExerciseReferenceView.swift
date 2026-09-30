import SwiftUI
import WorkoutDomain

struct ExerciseReferenceView: View {
  let entries: [WgerReference]
  @State private var query = ""
  var body: some View {
    List {
      Section {
        Text(
          "Exercise names from wger, available offline. These community records are references, not reviewed instructions or replacements for your program."
        )
        .font(.footnote)
        Text("Snapshot: September 25, 2026 · \(entries.count) exercises").font(.caption)
      }
      ForEach(entries.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) {
        entry in
        NavigationLink(entry.name) {
          List {
            Section {
              Text(entry.name).font(.headline)
              Link("View exercise on wger", destination: entry.sourceURL)
              Text("Opening the source requires internet access.").font(.caption)
            }
            Section("Source and license") {
              Text(
                "Exercise base: \(entry.baseAuthor.isEmpty ? "Author not supplied (CC0)" : entry.baseAuthor)"
              )
              if let url = WgerReference.licenseURL(entry.baseLicense) {
                Link(entry.baseLicense.uppercased(), destination: url)
              }
              Text(
                "English name: \(entry.translationAuthor.isEmpty ? "Author not supplied (CC0)" : entry.translationAuthor)"
              )
              if let url = WgerReference.licenseURL(entry.translationLicense) {
                Link(entry.translationLicense.uppercased(), destination: url)
              }
              Text(
                "Changes: English names selected and text normalized. Instructions, images and videos are excluded. Content retains its source license. This reference does not provide reviewed exercise instructions."
              )
              .font(.footnote)
            }
          }.navigationTitle("Exercise reference").navigationBarTitleDisplayMode(.inline)
        }
      }
      if entries.isEmpty { Text("The exercise reference could not be loaded.") }
    }.navigationTitle("Exercise library")
      .searchable(
        text: $query, placement: .navigationBarDrawer(displayMode: .always),
        prompt: "Search exercise names")
  }
}
