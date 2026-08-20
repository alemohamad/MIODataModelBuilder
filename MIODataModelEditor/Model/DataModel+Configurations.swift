//
//  DataModel+Configurations.swift
//  MIODataModelEditor
//
//  Created by MIO Research Labs on 2026.
//

import Foundation

nonisolated extension DataModel {
    /// The configurations to show in the sidebar: the implicit `Default`
    /// followed by any the file actually declares.
    ///
    /// `Default` is synthesised when the file has no element for it, which is
    /// the normal case.
    var sidebarConfigurations: [ModelConfiguration] {
        let named = configurations
            .filter { !$0.isDefault }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        let stored = configurations.first { $0.isDefault }
        return [stored ?? ModelConfiguration(name: ModelConfiguration.defaultName)] + named
    }

    func configuration(named name: String) -> ModelConfiguration? {
        sidebarConfigurations.first { $0.name == name }
    }

    /// The index of a configuration in `configurations`, creating the element
    /// if it is the implicit `Default` and does not exist yet.
    ///
    /// Call this only when about to change something. The encoder drops an
    /// untouched `Default` again, so materialising it here does not by itself
    /// put anything in the file.
    mutating func indexOfConfiguration(named name: String, creatingDefault: Bool = false) -> Int? {
        if let index = configurations.firstIndex(where: { $0.name == name }) { return index }
        guard creatingDefault, name == ModelConfiguration.defaultName else { return nil }
        configurations.append(ModelConfiguration(name: ModelConfiguration.defaultName))
        return configurations.count - 1
    }

    /// Entities belonging to a configuration.
    ///
    /// `Default` holds every entity by definition, so it is not a membership
    /// list; a named configuration is.
    func entities(inConfigurationNamed name: String) -> [ModelEntity] {
        let sorted = entities.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        guard name != ModelConfiguration.defaultName,
              let configuration = configuration(named: name)
        else { return sorted }
        return sorted.filter { configuration.memberEntityNames.contains($0.name) }
    }
}

nonisolated extension ModelConfiguration {
    init(name: String) {
        self.init()
        self.name = name
    }
}
