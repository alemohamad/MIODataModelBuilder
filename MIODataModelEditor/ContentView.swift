//
//  ContentView.swift
//  MIODataModelEditor
//
//  Created by Ale Mohamad on 19/08/2026.
//

import SwiftUI

/// The editor window: sidebar, entity detail, inspector.
///
/// Composition and derived bindings only. Every edit flows through
/// `modelBinding` into the document value, which is what gives the app undo and
/// dirty tracking without a line of undo code.
struct ContentView: View {
    @Binding var document: MIODataModelEditorDocument

    @State private var selection = EditorSelection()
    @State private var inspectorShown = true
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var diagnosticsDismissed = false
    @State private var diagnosticsSheetShown = false
    @State private var addVersionSheetShown = false
    @State private var renameVersionSheetShown = false
    @State private var deleteVersionConfirmationShown = false

    /// Which version this window is showing, which is not the same thing as the
    /// version the package marks current. View state, deliberately: looking at
    /// an old version must never change what the model's consumers compile
    /// against. `Set Current Version` is the only thing that does that.
    ///
    /// Seeded in `init` rather than in `task`, or the picker would render blank
    /// for one frame before the first update.
    @State private var viewedVersionName: String

    init(document: Binding<MIODataModelEditorDocument>) {
        _document = document
        _viewedVersionName = State(initialValue: document.wrappedValue.bundle.currentVersionName)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            if let model = modelBinding {
                EntitySidebar(model: model, selection: selection)
                    .navigationSplitViewColumnWidth(min: EditorLayout.sidebarMinWidth,
                                                    ideal: EditorLayout.sidebarIdealWidth)
            }
        } detail: {
            VStack(spacing: 0) {
                if repairableCount > 0 && !diagnosticsDismissed {
                    DiagnosticsBanner(count: repairableCount,
                                      onShow: { diagnosticsSheetShown = true },
                                      onRepair: repairAll,
                                      onIgnore: { diagnosticsDismissed = true })
                    Divider()
                }

                if let model = modelBinding {
                    EditorDetailPane(model: model,
                                     selection: selection,
                                     entityNames: entityNames,
                                     relationshipNames: relationshipNames)
                }
            }
        }
        .inspector(isPresented: $inspectorShown) {
            Group {
                if let model = modelBinding {
                    EditorInspectorPane(model: model,
                                        selection: selection,
                                        entityNames: entityNames,
                                        relationshipNames: relationshipNames,
                                        attributesInEntity: attributes(inEntityNamed:))
                }
            }
            .inspectorColumnWidth(min: EditorLayout.inspectorMinWidth,
                                  ideal: EditorLayout.inspectorIdealWidth,
                                  max: EditorLayout.inspectorMaxWidth)
        }
        .toolbar {
            EditorToolbar(viewedVersionName: $viewedVersionName,
                          currentVersionName: document.bundle.currentVersionName,
                          versions: document.bundle.versions,
                          issueCount: diagnostics.count,
                          onShowIssues: { diagnosticsSheetShown = true },
                          onToggleInspector: { inspectorShown.toggle() })
        }
        .sheet(isPresented: $diagnosticsSheetShown) {
            DiagnosticsSheet(diagnostics: diagnostics, selection: selection, onRepair: repairAll)
        }
        .sheet(isPresented: $addVersionSheetShown) {
            ModelVersionSheet(mode: .add,
                              versions: document.bundle.versions,
                              subject: viewedVersionName,
                              nameForSubject: document.bundle.suggestedVersionName(basedOn:),
                              canUse: document.bundle.canAddVersion(named:),
                              onConfirm: addVersion)
        }
        .sheet(isPresented: $renameVersionSheetShown) {
            ModelVersionSheet(mode: .rename,
                              versions: document.bundle.versions,
                              subject: viewedVersionName,
                              nameForSubject: displayName(ofVersionNamed:),
                              canUse: canRenameViewedVersion,
                              onConfirm: renameVersion)
        }
        // An alert rather than a sheet: there is nothing to fill in, and what
        // the dialog has to carry is which version is about to go.
        .alert("Delete “\(viewedVersionDisplayName)”?",
               isPresented: $deleteVersionConfirmationShown) {
            Button("Delete", role: .destructive) { deleteViewedVersion() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The version and everything in it leaves the package when you save. Undo brings it back.")
        }
        // Two versions of one model are usually near-identical, so the entity
        // that was selected almost always exists in the one just switched to.
        // Only reselect when it does not, or switching back and forth would
        // lose the user's place for no reason.
        .onChange(of: viewedVersionName) {
            reselectIfMissingFromViewedVersion()
        }
        // Undo takes a just-added version back out from under the window, and a
        // picker whose selection names nothing renders blank. Comparing file
        // names rather than versions keeps this off the path of every edit: the
        // list only changes when a version is added or removed.
        .onChange(of: document.bundle.versions.map(\.fileName)) { _, names in
            guard !names.contains(viewedVersionName) else { return }
            viewedVersionName = document.bundle.currentVersionName
            reselectIfMissingFromViewedVersion()
        }
        .focusedSceneValue(\.editorActions, editorActions)
        .clearsInitialFocus()
        .frame(minHeight: EditorLayout.windowMinHeight)
        // Xcode opens on the first entity, and falls back to the Default
        // configuration only when the model has none, which is the case for a
        // document that was just created.
        .task {
            guard selection.item == nil else { return }
            if let first = entityNames.first {
                selection.select(entityNamed: first)
            } else {
                selection.select(configurationNamed: ModelConfiguration.defaultName)
            }
        }
    }

    // MARK: - Menu commands

    private var editorActions: EditorActions {
        EditorActions(toggleSidebar: toggleSidebar,
                      toggleInspector: { inspectorShown.toggle() },
                      toggleOutlineStyle: { selection.outlineStyle.toggle() },
                      isOutlineStyle: selection.outlineStyle,
                      addEntity: addEntity,
                      addConfiguration: addConfiguration,
                      addAttribute: propertyAction(addAttribute),
                      addRelationship: propertyAction(addRelationship),
                      addFetchedProperty: propertyAction(addFetchedProperty),
                      focusFilter: selection.focusFilter,
                      addModelVersion: addVersionAction,
                      setCurrentVersion: setCurrentVersionAction,
                      renameModelVersion: renameVersionAction,
                      deleteModelVersion: deleteVersionAction,
                      deleteSelection: deleteAction,
                      deleteTitle: deleteTitle)
    }

    private func toggleSidebar() {
        columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
    }

    /// Offers an add-property command only while an entity is selected, so the
    /// three menu items grey out together rather than silently doing nothing.
    private func propertyAction(_ add: @escaping () -> Void) -> (() -> Void)? {
        selectedEntityPath == nil ? nil : add
    }

    // MARK: - Versions

    /// `nil` for a bare `.xcdatamodel`: there is no package around it to put a
    /// second version in, so the menu item greys out rather than writing a
    /// layout the document's own file extension would contradict.
    private var addVersionAction: (() -> Void)? {
        document.bundle.isVersionedPackage ? { addVersionSheetShown = true } : nil
    }

    /// `nil` when the viewed version is already the current one, so the menu
    /// item both reads as available and says which state the window is in.
    private var setCurrentVersionAction: (() -> Void)? {
        guard document.bundle.isVersionedPackage,
              document.bundle.currentVersionName != viewedVersionName,
              document.bundle.index(ofVersionNamed: viewedVersionName) != nil
        else { return nil }
        return setCurrentVersion
    }

    private func setCurrentVersion() {
        document.bundle.currentVersionName = viewedVersionName
    }

    /// Adds the version and switches the window to it, which is the only useful
    /// thing to do next. The current-version marker stays where it was.
    private func addVersion(named name: String, basedOn fileName: String) {
        guard let added = document.bundle.addVersion(named: name, copying: fileName) else { return }
        viewedVersionName = added
    }

    /// Renaming acts on the version the window is showing, so there is nothing
    /// to pick in the sheet. `nil` for a bare `.xcdatamodel`, whose one version
    /// is the document file and would have to be renamed in the Finder.
    private var renameVersionAction: (() -> Void)? {
        guard document.bundle.isVersionedPackage,
              document.bundle.index(ofVersionNamed: viewedVersionName) != nil
        else { return nil }
        return { renameVersionSheetShown = true }
    }

    /// `nil` for the last version and for the current one. Both are refused by
    /// the bundle, and greying the item out is how that reads in the menu.
    private var deleteVersionAction: (() -> Void)? {
        guard document.bundle.canDeleteVersion(viewedVersionName) else { return nil }
        return { deleteVersionConfirmationShown = true }
    }

    /// The current version cannot be the one going, so it is always there to
    /// fall back to.
    private func deleteViewedVersion() {
        guard document.bundle.deleteVersion(viewedVersionName) else { return }
        viewedVersionName = document.bundle.currentVersionName
        reselectIfMissingFromViewedVersion()
    }

    private var viewedVersionDisplayName: String {
        displayName(ofVersionNamed: viewedVersionName)
    }

    private func displayName(ofVersionNamed fileName: String) -> String {
        document.bundle.index(ofVersionNamed: fileName)
            .map { document.bundle.versions[$0].displayName } ?? ""
    }

    private func canRenameViewedVersion(to name: String) -> Bool {
        document.bundle.canRenameVersion(viewedVersionName, to: name)
    }

    /// The window has to follow the rename, or it would be left viewing a name
    /// that no longer exists and fall back to the current version.
    private func renameVersion(to name: String, _ fileName: String) {
        guard let renamed = document.bundle.renameVersion(fileName, to: name) else { return }
        viewedVersionName = renamed
    }

    /// Keeps the selection pointing at something that exists after a version
    /// switch, since the two versions need not hold the same entities.
    private func reselectIfMissingFromViewedVersion() {
        guard let model = viewedModel else { return }

        if let name = selection.entityName, let entity = model.entity(named: name) {
            // The entity survived; a property of it need not have.
            if let property = selection.property, !entity.propertyNames.contains(property.name) {
                selection.clearProperty()
            }
            return
        }
        if let name = selection.configurationName, model.configuration(named: name) != nil { return }

        if let first = entityNames.first {
            selection.select(entityNamed: first)
        } else {
            selection.select(configurationNamed: ModelConfiguration.defaultName)
        }
    }

    // MARK: - Editing

    /// The Editor menu's add commands, which do exactly what the `+` under each
    /// table does and then select what they made, so the inspector is ready for
    /// a rename. The shapes live in `DataModel+Adding`.
    private func addEntity() {
        guard let index = viewedVersionIndex else { return }
        selection.select(entityNamed: document.bundle.versions[index].model.addEntity())
    }

    private func addConfiguration() {
        guard let index = viewedVersionIndex else { return }
        selection.select(configurationNamed: document.bundle.versions[index].model.addConfiguration())
    }

    private func addAttribute() {
        guard let path = selectedEntityPath else { return }
        let name = document.bundle.versions[path.version].model.entities[path.entity].addAttribute()
        selection.select(propertyNamed: name, kind: .attribute)
    }

    private func addRelationship() {
        guard let path = selectedEntityPath else { return }
        let name = document.bundle.versions[path.version].model.entities[path.entity].addRelationship()
        selection.select(propertyNamed: name, kind: .relationship)
    }

    private func addFetchedProperty() {
        guard let path = selectedEntityPath else { return }
        let name = document.bundle.versions[path.version].model.entities[path.entity].addFetchedProperty()
        selection.select(propertyNamed: name, kind: .fetchedProperty)
    }

    /// Where the selected entity lives, which the three property commands all
    /// need. `nil` when the sidebar is on a configuration or on nothing, and
    /// that is what greys those three out.
    private var selectedEntityPath: (version: Int, entity: Int)? {
        guard let version = viewedVersionIndex,
              let name = selection.entityName,
              let entity = document.bundle.versions[version].model.index(ofEntityNamed: name)
        else { return nil }
        return (version, entity)
    }

    /// A property beats the entity: with an attribute selected, Delete removes
    /// the attribute rather than the entity containing it.
    private var deleteAction: (() -> Void)? {
        guard viewedVersionIndex != nil else { return nil }
        if selection.property != nil { return deleteSelectedProperty }
        if selection.entityName != nil { return deleteSelectedEntity }
        return nil
    }

    private var deleteTitle: String {
        switch selection.property?.kind {
        case .attribute: "Delete Attribute"
        case .relationship: "Delete Relationship"
        case .fetchedProperty: "Delete Fetched Property"
        case nil: selection.entityName == nil ? "Delete" : "Delete Entity"
        }
    }

    private func deleteSelectedEntity() {
        guard let version = viewedVersionIndex,
              let name = selection.entityName
        else { return }
        document.bundle.versions[version].model.entities.removeAll { $0.name == name }
        selection.selectSidebarItem(nil)
    }

    private func deleteSelectedProperty() {
        guard let version = viewedVersionIndex,
              let property = selection.property,
              let name = selection.entityName,
              let index = document.bundle.versions[version].model.index(ofEntityNamed: name)
        else { return }

        switch property.kind {
        case .attribute:
            document.bundle.versions[version].model.entities[index]
                .attributes.removeAll { $0.name == property.name }
        case .relationship:
            document.bundle.versions[version].model.entities[index]
                .relationships.removeAll { $0.name == property.name }
        case .fetchedProperty:
            document.bundle.versions[version].model.entities[index]
                .fetchedProperties.removeAll { $0.name == property.name }
        }
        selection.clearProperty()
    }

    // MARK: - Derived bindings

    /// Falls back to the current version when the viewed name names nothing,
    /// which is what a bare `.xcdatamodel` and a freshly opened document both
    /// look like for an instant.
    private var viewedVersionIndex: Int? {
        document.bundle.index(ofVersionNamed: viewedVersionName) ?? document.bundle.currentVersionIndex
    }

    private var viewedModel: DataModel? {
        viewedVersionIndex.map { document.bundle.versions[$0].model }
    }

    private var modelBinding: Binding<DataModel>? {
        guard let index = viewedVersionIndex else { return nil }
        return $document.bundle.versions[index].model
    }

    private var entityNames: [String] {
        (viewedModel?.entities ?? [])
            .map(\.name)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func relationshipNames(inEntityNamed name: String) -> [String] {
        guard let target = viewedModel?.entity(named: name) else { return [] }
        return target.relationships
            .map(\.name)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func attributes(inEntityNamed name: String) -> [ModelAttribute] {
        viewedModel?.attributes(inEntityNamed: name) ?? []
    }

    // MARK: - Diagnostics

    private var diagnostics: [Diagnostic] {
        viewedModel.map(ModelValidator.validate) ?? []
    }

    private var repairableCount: Int {
        diagnostics.filter(\.kind.isRepairable).count
    }

    private func repairAll() {
        guard let index = viewedVersionIndex else { return }
        ModelValidator.repairStrayAttributes(in: &document.bundle.versions[index].model)
        diagnosticsSheetShown = false
    }
}

#Preview("Loaded model") {
    @Previewable @State var document = PreviewSamples.document

    ContentView(document: $document)
}

#Preview("Two versions") {
    @Previewable @State var document = PreviewSamples.versionedDocument

    ContentView(document: $document)
}

#Preview("New document") {
    @Previewable @State var document = MIODataModelEditorDocument()

    ContentView(document: $document)
}
