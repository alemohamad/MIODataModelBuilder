# Data Model Editor

A native macOS editor for Core Data models, `.xcdatamodeld` and `.xcdatamodel`,
built so you can edit a model without opening Xcode.

## Why

A Core Data model lives in git next to your source. An editor that reformats on
save turns a one-field change into a four-thousand-line diff, and an editor that
drops constructs it does not understand destroys data silently.

So the central promise here is that **opening a model and saving it without
touching anything produces the identical file, byte for byte**. Everything else
is built on top of that.

That means the editor preserves what it does not model: unknown attributes,
unknown elements, comments and their position among live siblings, the XML
declaration, and whether the file ends with a newline. Tri-state flags stay
absent rather than materialising `optional="NO"` on every attribute in the file.

## What it does

- **Entities** in a flat list or a parent/child outline, with a filter field
- **Attributes, relationships and fetched properties** as three collapsible
  tables, with inline editing
- **Inspectors** for the entity, attribute, relationship, fetched property and
  configuration, covering the fields Xcode exposes
- **Configurations**, including the implicit `Default` that Xcode shows for
  every model and writes for none
- **Versioned packages**: every version of an `.xcdatamodeld` is loaded, new
  versions are added from the Editor menu, and which version is current is set
  explicitly rather than by looking at one
- **Diagnostics** for problems Core Data will not tell you about, with a repair
  for the ones that are mechanical

### Diagnostics

Two of these are worth calling out, because Core Data ignores them silently:

| Written in the file | What Core Data reads | Effect |
| --- | --- | --- |
| `defaultValue` | `defaultValueString` | The attribute has no default |
| `abstract` | `isAbstract` | The entity is not abstract |

Both are reported as repairable, and the repair moves the value onto the
spelling Core Data actually reads. The editor also flags dangling relationship
destinations, missing inverses, duplicate names and missing parent entities.

### Model versions

The toolbar's version picker changes **what this window is showing**. It does
not change which version the package marks current, because that is what every
consumer of the model compiles against and switching it is a decision, not a
side effect of looking at an old version. The current one carries a checkmark in
the picker, and `Editor > Set Current Version` (⌘⇧C) is what moves it.

`Editor > Add Model Version...` asks for a name and a version to copy, exactly
as Xcode does. The name it offers counts on from the version you are basing it
on, so a new version of `DualLinkDB 63` is `DualLinkDB 64`. Adding a version
leaves the current-version marker where it was.

`Editor > Rename Version...` renames the version the window is showing. If that
version is the current one, `.xccurrentversion` follows the new name, since a
marker naming a directory that is no longer there would silently load the wrong
version. Xcode has no such command; you rename the `.xcdatamodel` in the
navigator.

`Editor > Delete Version...` removes the version the window is showing, after a
confirmation. It refuses two cases outright, so the item is greyed rather than
failing: the **last** version, since a package with no `.xcdatamodel` will not
load at all, and the **current** version, since removing it would have to
repoint `.xccurrentversion` at something else. Set another version current
first. Xcode has no such command either; there you delete the `.xcdatamodel`
from the project navigator, which this app has no equivalent of. The deletion
reaches disk only on save, and undo brings the version back.

None of the three applies to a bare `.xcdatamodel` with no package around it, so
all are disabled for one.

### Configurations

A configuration is a named subset of the model's entities. You pass its name to
`addPersistentStore(ofType:configurationName:at:)`, and that store then holds
only those entities, which is how one model is split across several stores: a
read-only seed store alongside a writable one, say. `Default` is implicit,
contains every entity, and is never written to the file. Relationships cannot
cross stores, which is what fetched properties exist for.

Worth knowing before reaching for one: **MIOCoreData ignores configurations.**
Its `entities(forConfigurationName:)` returns every entity whatever you pass,
and `NSPersistentContainer` always passes `nil`. They only do anything under
Apple's Core Data, behind the `APPLE_CORE_DATA` switch. The editor reads and
writes them faithfully either way, because Xcode does.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ⌘1 / ⌘2 | Toggle the navigator / the inspector |
| ⌘⇧N | New model |
| ⌘N | Add entity |
| ⌥⌘A / ⌥⌘R | Add attribute / relationship |
| ⌘⌫ | Delete the selected entity or property |
| ⌘F | Focus the filter field |
| ⌘S | Save |
| ⌘Z / ⌘⇧Z | Undo / redo |
| ⌘⇧R | Revert to saved |
| ⌘⇧C | Set the viewed version as the current one |

Everything that adds to the model lives in the **Editor** menu, in three groups:
what the model holds (entity, configuration), what the selected entity holds
(attribute, relationship, fetched property), and the package of versions around
both. Add Fetched Property, Add Configuration and the four version commands
carry no shortcut, apart from Set Current Version. The three property commands are enabled only while an
entity is selected.

## Requirements

- macOS 26.0 or later
- Xcode 26 or later, Swift 6

## License

MIT. See [LICENSE](LICENSE).

Copyright © 2026 MIO Research Labs. <https://www.miolabs.com>
