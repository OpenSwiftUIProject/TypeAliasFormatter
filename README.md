<p align="center">
  <img src="Documentation/Images/app-icon-composer.png" alt="TypeAlias Formatter app icon" width="128" height="128">
</p>

<h1 align="center">TypeAlias Formatter</h1>

A native macOS app, browser app, and command-line tool that format nested Swift
typealiases and demangled type names. All three use the same Core Swift package and preserve
private names such as `(Modifier in _123ABC)<Style>`.

[Open the web app](https://openswiftuiproject.github.io/TypeAliasFormatter/) ·
[Download the macOS app and CLI](https://github.com/OpenSwiftUIProject/TypeAliasFormatter/releases/latest)

![TypeAlias Formatter with wrapped source and formatted text](Documentation/Images/typealias-formatter.png)

## GUI

Paste one typealias or type in the source pane. The output updates as you type.
The converter removes a leading `typealias Name =` declaration before parsing.
The app opens with an empty source pane.

- Multiple generic arguments use separate lines and four-space indentation.
- Choose **2 spaces**, **4 spaces**, **8 spaces**, or **Tab** for indentation.
  Tab uses one tab character per level and displays at four-space tab stops.
- Single-argument generics stay on one line unless a child needs multiple lines.
- Use **Expand generics** to expand single-argument generics in text too.
- **Text tree** shows the formatted type without a declaration header or code fence.
- Select a type in either text pane to highlight its matching range in the other
  pane. The same selection appears in **Graph** and survives a mode change.
- **Graph** shows connected type nodes in argument order. Click a node to
  highlight its source. Use its arrow to expand or collapse children, and the
  zoom controls or **Fit** to inspect the tree. Source selection reveals nodes
  below collapsed ancestors.
- Graphs initially show two levels of arguments. **Expand all** shows every node.
- Copy or save Text as plain text (`.txt`), or the visible Graph as SVG (`.svg`).
- Use **Open** to load a UTF-8 `.swift`, `.md`, or `.txt` file.
- The source editor wraps lines by default. Turn off **Wrap lines** to scroll
  horizontally. This setting and the indentation choice persist across launches.
  The output editor scrolls horizontally to preserve deep indentation.

Shortcuts: **⌘O** opens a file, **⌘Return** formats the input, **⇧⌘C** copies
the output, and **⌘S** saves it.

The formatter checks delimiters, empty arguments, and Markdown fences. It keeps
function arrows, tuples, collection types, and type suffixes intact. This is a
type layout tool, not a Swift syntax validator. Format one declaration at a time
and remove comments first. Input is limited to 200 KB and 128 nesting levels.
All formatting runs locally. The native app has no network dependency.

## Web app

The [web app](https://openswiftuiproject.github.io/TypeAliasFormatter/) runs Core
as WebAssembly with JavaScriptKit. It supports the same linked source, Text tree,
and Graph selection as the native app, plus file import, text/SVG export, zoom,
and collapse controls. Input stays in the browser and is never uploaded. Only
display preferences persist; each new session starts with empty input.

## CLI

Run the CLI with Swift 6 or later, or extract `typealias-formatter` from the CLI
ZIP on GitHub Releases. The CLI does not require Tuist or Icon Composer.

```sh
swift run typealias-formatter --help
printf '%s\n' 'typealias Body = Pair<A, Box<B>>' | swift run typealias-formatter
swift run typealias-formatter input.txt --indent tab -o output.txt
swift run typealias-formatter input.txt --format graph -o graph.svg
```

| Option | Behavior |
| --- | --- |
| `input.txt` | Read one UTF-8 file. Omit the path or use `-` to read stdin. |
| `-o`, `--output` | Write to a file. Omit the path or use `-` to write to stdout. |
| `--format text` | Format plain text. This is the default. |
| `--format graph` | Export the full graph as SVG. |
| `--indent 2/4/8/tab` | Set text indentation. The default is `4`. |
| `--expand-generics` | Expand single-argument generics in text output. |

The CLI uses the same 200 KB input limit and parsing rules as the GUI. It writes
errors to stderr and exits with a nonzero status. It reads and formats the input
before writing an output file, so a format error does not overwrite that file.
Use `--` before an input path that begins with a dash.

Build an optimized CLI binary without generating an Xcode project:

```sh
swift build -c release --product typealias-formatter
.build/release/typealias-formatter input.txt
```

## Project structure

| Component | Location | Dependencies |
| --- | --- | --- |
| `TypeAliasFormatterCore` Swift package | `Packages/TypeAliasFormatterCore` | Foundation |
| `TypeAliasFormatterApp` target | `App` | `TypeAliasFormatterCore` |
| `TypeAliasFormatterCLI` target | `CLI` | `TypeAliasFormatterCore`, ArgumentParser |
| `TypeAliasFormatterWeb` Swift package and browser UI | `Web` | `TypeAliasFormatterCore`, JavaScriptKit, CodeMirror |

Core contains parsing, text formatting, graph layout, SVG export, UTF-16 source
and output mappings, and their tests. Stable node IDs link all three views,
including repeated type names and Unicode input.
It has no SwiftUI or AppKit dependency. The root `Package.swift` builds and tests
the CLI with the local Core package. `Project.swift` defines the GUI and CLI
Xcode targets; both depend on the Core package through Tuist's Swift Package
integration. Tuist reads the dependencies from the root `Package.swift`, so
package paths and versions have one definition. Core sources belong only to the
Core package.

The separate Web package keeps JavaScriptKit out of the native app and CLI
dependency graph. JavaScript manages the browser UI; Swift handles conversion,
selection lookup, graph layout, and SVG generation.

The CLI uses Apple's [ArgumentParser](https://github.com/apple/swift-argument-parser).
Its license is available in `Licenses/SwiftArgumentParser.txt` in this repository.
The Core package has no third-party dependencies.

## Develop

Requires macOS 14 or later, Xcode 26 or later, and Tuist 4 with buildable folder
support. The initial project was verified with Tuist 4.206.0 and Xcode 26.6.

```sh
tuist install
tuist generate --no-open
open TypeAliasFormatter.xcworkspace
```

Select the `TypeAliasFormatterApp` or `TypeAliasFormatterCLI` scheme to run the
corresponding target. Edit `Project.swift` to change the project. Generated Xcode
files and build products are ignored by Git. The GUI and CLI use buildable
folders, so new files in those source folders do not need regeneration. Regenerate
the workspace after adding Core files or changing target settings. Run
`tuist install` when package dependencies change.

The app icon source is `App/Resources/AppIcon.icon`. Open it in Icon Composer to
edit the four SVG layers, the background, or the material effects. Xcode generates
all icon sizes and appearances, including icons for older macOS releases, from
this file. See [Apple's Icon Composer documentation](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer).

`AccentColor` in `App/Resources/Assets.xcassets` defines the app's blue accent for
light and dark appearances. The README icon is exported from Icon Composer to
`Documentation/Images/app-icon-composer.png`.

```sh
xcodebuild build \
  -workspace TypeAliasFormatter.xcworkspace \
  -scheme TypeAliasFormatterApp \
  -destination 'platform=macOS' \
  -derivedDataPath DerivedData
```

Run the Core and CLI tests with SwiftPM:

```sh
swift test --package-path Packages/TypeAliasFormatterCore
swift test
bash Scripts/test-cli.sh "$(swift build --show-bin-path)/typealias-formatter"
```

Core fixtures verify the full reference layout after removing its declaration
header and code fence. Core tests also cover graph structure, node layout,
collapse behavior, SVG output, and source/output mappings. CLI tests cover file output, indentation,
input limits, invalid UTF-8, and safe output handling. The integration script
checks stdin, stdout, error exits, and SVG output with the built executable.

### Web development

Use Swift 6.2.3 with a compatible `wasm32-unknown-wasip1` Swift SDK, plus Node.js
24. Install the SDK with [setup-swiftwasm](https://github.com/swiftwasm/setup-swiftwasm)
or the [Swift SDK instructions](https://book.swiftwasm.org/getting-started/setup.html).
Check `swift --version` and `swift sdk list` before building.

```sh
cd Web
npm ci
PATH="$PWD/node_modules/.bin:$PATH" swift package --swift-sdk <installed-sdk-id> js -c release
npm run build
npm run preview
```

Open `http://127.0.0.1:4173/TypeAliasFormatter/`. For browser UI edits, use
`npm run dev`; rebuild the Swift package after changing Core or the Web bridge.

Run the browser tests after building the site:

```sh
npx playwright install --only-shell chromium
npm test
```

The tests load the real WebAssembly module. They check linked selection in both
directions, repeated names, collapsed ancestors, Unicode, file import, SVG
export, invalid input, persisted settings, and mobile layout.

The **Deploy to GitHub Pages** workflow tests Core on Linux, builds WebAssembly,
and runs the browser tests before deploying. Pushes to `main` deploy the site;
app and CLI releases still require a version tag. Set the repository's Pages
source to **GitHub Actions** when deploying a fork.

## Release

Push a tag in `vMAJOR.MINOR.PATCH` format, such as `v0.2.1`, to run the Release
workflow. It uses Xcode 26.6 and Tuist 4.206.0 to test Core and the CLI, then
build the universal GUI and CLI for Apple Silicon and Intel. The app version
comes from the tag, and the build number comes from the workflow run number.

The workflow creates a GitHub Release and uploads two assets:

- `TypeAliasFormatter-v<version>-macOS.zip` contains the GUI app.
- `TypeAliasFormatterCLI-v<version>-macOS.zip` contains only the universal
  `typealias-formatter` executable at the archive root, with no nested ZIP.

The GUI and CLI require macOS 14 or later. Release builds use ad-hoc signing and
are not notarized.

For a build check before tagging, run **Release** manually from the Actions tab
and enter the app version. Manual runs store all assets as a workflow artifact and
do not publish a GitHub Release.
