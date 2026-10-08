import { init } from "./.build/plugins/PackageToJS/outputs/Package/index.js";
import { EditorSelection, EditorState, StateEffect, StateField, Compartment } from "@codemirror/state";
import { Decoration, EditorView, drawSelection, keymap, lineNumbers, placeholder } from "@codemirror/view";
import { defaultKeymap, history, historyKeymap, indentWithTab } from "@codemirror/commands";
import { bracketMatching } from "@codemirror/language";
import icon from "../Documentation/Images/app-icon-composer.png";
import "./styles.css";

const $ = (id) => document.getElementById(id);
$("app-icon").src = icon;
let preferences = {};
try { preferences = JSON.parse(localStorage.getItem("typealias-preferences") || "{}"); } catch { /* Use defaults when storage is unavailable. */ }
if (!preferences || typeof preferences !== "object" || Array.isArray(preferences)) preferences = {};
if (![0, 2, 4, 8].includes(preferences.indentation)) preferences.indentation = 4;
$("indent").value = String(preferences.indentation);
$("wrap").checked = preferences.wrap !== false;
$("expand-generics").checked = preferences.expand === true;
let mode = preferences.mode === "graph" ? "graph" : "text";
let ready = false;
let result = null;
let latestSource = "";
let selectedID = null;
let collapsed = new Set();
let graphData = null;
let zoom = 0.8;
let timer;
let programmatic = false;
const wrapping = new Compartment();
const editable = new Compartment();
const mark = StateEffect.define();
const marks = StateField.define({
  create: () => Decoration.none,
  update(value, transaction) {
    if (transaction.docChanged) value = Decoration.none;
    for (const effect of transaction.effects) {
      if (effect.is(mark)) value = effect.value
        ? Decoration.set([Decoration.mark({ class: "cm-linked-highlight" }).range(effect.value.lowerBound, effect.value.upperBound)])
        : Decoration.none;
    }
    return value;
  },
  provide: (field) => EditorView.decorations.from(field),
});

function createEditor(id, source) {
  return new EditorView({
    parent: $(id),
    state: EditorState.create({
      extensions: [
        lineNumbers(), drawSelection(), bracketMatching(), marks,
        EditorState.tabSize.of(4),
        placeholder(source ? "Paste a typealias or type here…" : "Converted output appears here."),
        EditorView.contentAttributes.of({ "aria-label": source ? "Source typealias" : "Formatted type tree", spellcheck: "false", autocapitalize: "off" }),
        ...(source ? [history(), keymap.of([...defaultKeymap, ...historyKeymap, indentWithTab]),
          wrapping.of($("wrap").checked ? EditorView.lineWrapping : []), editable.of(EditorView.editable.of(false))]
          : [EditorState.readOnly.of(true), keymap.of(defaultKeymap)]),
        EditorView.domEventHandlers({
          click(event, view) {
            const position = view.posAtCoords({ x: event.clientX, y: event.clientY });
            if (position !== null && view.state.selection.main.empty) selectRange(position, position, source ? "source" : "formatted");
          },
        }),
        EditorView.updateListener.of((update) => {
          if (programmatic) return;
          // Apply linked decorations after CodeMirror finishes its current update.
          queueMicrotask(() => {
            if (source && update.docChanged) {
              invalidate();
              clearTimeout(timer);
              timer = setTimeout(format, 180);
            } else if (update.selectionSet) {
              const selection = update.view.state.selection.main;
              selectRange(selection.from, selection.to, source ? "source" : "formatted");
            }
          });
        }),
      ],
    }),
  });
}

const sourceEditor = createEditor("source-editor", true);
const textEditor = createEditor("text-editor", false);

function setDocument(view, text) {
  programmatic = true;
  try { view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: text } }); }
  finally { programmatic = false; }
}

function status(message, error = false) {
  $("status").textContent = message;
  $("status").classList.toggle("error", error);
}

function updateControls() {
  const count = sourceEditor.state.doc.length;
  $("character-count").textContent = `${count.toLocaleString()} characters`;
  $("clear").disabled = !count;
  for (const id of ["copy", "save", "expand-all", "collapse-all", "zoom-in", "zoom-out", "fit"]) $(id).disabled = !result;
  $("expand-all").disabled = !result || !collapsed.size;
  $("collapse-all").disabled = !result || collapsed.has("root");
  $("copy").textContent = "Copy";
}

function invalidate() {
  result = null;
  selectedID = null;
  graphData = null;
  setDocument(textEditor, "");
  sourceEditor.dispatch({ effects: mark.of(null) });
  $("graph-canvas").replaceChildren();
  $("graph-placeholder").hidden = false;
  $("selection-info").textContent = "Select a type in either pane";
  updateControls();
  status(sourceEditor.state.doc.length ? "Formatting…" : "Paste a type to begin.");
}

function branchIDs(node, id = "root") {
  return [...(node.children.length ? [id] : []), ...node.children.flatMap((child, index) => branchIDs(child, `${id}.${index}`))];
}

function format() {
  clearTimeout(timer);
  if (!ready) return;
  const source = sourceEditor.state.doc.toString();
  if (!source.trim()) { invalidate(); return; }
  try {
    const value = JSON.parse(globalThis.typeAliasConvert(source, Number($("indent").value), $("expand-generics").checked));
    if (value.error) throw new Error(value.error);
    result = value;
    if (latestSource !== source) {
      selectedID = null;
      collapsed = new Set(branchIDs(value.graph).filter((id) => id.split(".").length >= 3));
    }
    latestSource = source;
    setDocument(textEditor, result.text);
    renderGraph();
    selectNode(selectedID);
    updateControls();
    status(`${result.mappings.length} nodes · ${result.text.split("\n").length} lines`);
  } catch (error) {
    invalidate();
    status(error.message, true);
  }
}

function selectRange(from, to, origin) {
  if (!result) return;
  selectNode(globalThis.typeAliasSelect(from, to, origin), origin);
}

function markEditor(view, range, reveal) {
  const effects = [mark.of(range?.upperBound > range?.lowerBound ? range : null)];
  if (range && reveal) effects.push(EditorView.scrollIntoView(EditorSelection.range(range.upperBound, range.lowerBound), { y: "nearest", x: "nearest" }));
  view.dispatch({ effects });
}

function selectNode(id, origin) {
  const mapping = result?.mappings.find((item) => item.id === id);
  selectedID = mapping?.id ?? null;
  if (mapping) {
    const parts = id.split(".");
    let changed = false;
    for (let length = 1; length < parts.length; length++) changed = collapsed.delete(parts.slice(0, length).join(".")) || changed;
    if (changed) renderGraph();
  }
  markEditor(sourceEditor, mapping?.sourceRange, origin !== "source");
  markEditor(textEditor, mapping?.formattedRange, origin !== "formatted");
  for (const node of $("graph-canvas").querySelectorAll("g[data-node-id]")) {
    const selected = node.dataset.nodeId === selectedID;
    node.classList.toggle("is-selected", selected);
    node.setAttribute("aria-pressed", String(selected));
  }
  $("selection-info").textContent = mapping
    ? `Source ${mapping.sourceRange.lowerBound + 1}–${mapping.sourceRange.upperBound}`
    : "Select a type in either pane";
  if (mode === "graph" && origin !== "graph") revealGraphSelection();
}

function revealGraphSelection() {
  const node = graphData?.layout.nodes.find((item) => item.id === selectedID);
  if (!node) return;
  const viewport = $("graph-scroll");
  viewport.scrollTo({ left: (node.x + 128) * zoom - viewport.clientWidth / 2, top: (node.y + 42) * zoom - viewport.clientHeight / 2 });
}

function svgElement(name, attributes) {
  const element = document.createElementNS("http://www.w3.org/2000/svg", name);
  for (const [key, value] of Object.entries(attributes)) element.setAttribute(key, value);
  return element;
}

function renderGraph() {
  if (!result) return;
  graphData = JSON.parse(globalThis.typeAliasDiagram(JSON.stringify([...collapsed])));
  $("graph-placeholder").hidden = true;
  $("graph-canvas").innerHTML = graphData.svg;
  const svg = $("graph-canvas").firstElementChild;
  svg.setAttribute("width", graphData.layout.width * zoom);
  svg.setAttribute("height", graphData.layout.height * zoom);
  svg.setAttribute("aria-label", "Type structure");
  for (const placement of graphData.layout.nodes) {
    const node = svg.querySelector(`[data-node-id="${placement.id}"]`);
    node.setAttribute("role", "button");
    node.setAttribute("tabindex", "0");
    node.setAttribute("aria-label", placement.label);
    node.setAttribute("aria-pressed", String(placement.id === selectedID));
    node.classList.toggle("is-selected", placement.id === selectedID);
    if (!placement.childCount) continue;
    const folded = collapsed.has(placement.id);
    const toggle = svgElement("g", { "data-collapse-id": placement.id, role: "button", tabindex: "0",
      "aria-label": `${folded ? "Expand" : "Collapse"} ${placement.label}`, "aria-expanded": String(!folded),
      transform: `translate(${placement.x + 222}, ${placement.y + 26})` });
    toggle.append(svgElement("rect", { x: "0", y: "-26", width: "34", height: "84", rx: "8", fill: "transparent" }));
    toggle.append(svgElement("path", { d: folded ? "M 12 8 L 17 13 L 12 18" : "M 10 10 L 15 15 L 20 10", fill: "none", stroke: "#1766dc", "stroke-width": "1.5" }));
    const count = svgElement("text", { x: "15", y: "37", "text-anchor": "middle", fill: "#778399", "font-size": "10", "font-family": "system-ui" });
    count.textContent = placement.childCount;
    toggle.append(count);
    svg.append(toggle);
  }
  $("zoom-level").textContent = `${Math.round(zoom * 100)}%`;
  updateControls();
}

function graphAction(event) {
  if (event.type === "keydown" && event.key !== "Enter" && event.key !== " ") return;
  const toggle = event.target.closest("[data-collapse-id]");
  const node = event.target.closest("[data-node-id]");
  if (!toggle && !node) return;
  event.preventDefault();
  if (toggle) {
    const id = toggle.dataset.collapseId;
    if (!collapsed.delete(id)) collapsed.add(id);
    if (collapsed.has(id) && selectedID?.startsWith(id + ".")) selectNode(id, "graph");
    renderGraph();
    $("graph-canvas").querySelector(`[data-collapse-id="${id}"]`)?.focus({ preventScroll: true });
  } else selectNode(node.dataset.nodeId, "graph");
}

function persist() {
  try { localStorage.setItem("typealias-preferences", JSON.stringify({ indentation: Number($("indent").value), wrap: $("wrap").checked, expand: $("expand-generics").checked, mode })); } catch { /* Settings remain active for this session. */ }
}

function setMode(value) {
  mode = value;
  for (const name of ["text", "graph"]) {
    $(name + "-panel").hidden = mode !== name;
    $(name + "-tab").setAttribute("aria-selected", String(mode === name));
    $(name + "-tab").tabIndex = mode === name ? 0 : -1;
  }
  if (mode === "graph") { renderGraph(); revealGraphSelection(); }
  else textEditor.requestMeasure();
  persist();
}

async function copy() {
  if (!result) return;
  try {
    await navigator.clipboard.writeText(mode === "text" ? result.text : graphData.svg);
    $("copy").textContent = "Copied";
  } catch { status("Clipboard access failed. Use Save to export the result.", true); }
}

function save() {
  if (!result) return;
  const graph = mode === "graph";
  const url = URL.createObjectURL(new Blob([graph ? graphData.svg : result.text + "\n"], { type: graph ? "image/svg+xml" : "text/plain;charset=utf-8" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = `FormattedTypealias.${graph ? "svg" : "txt"}`;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

$("graph-canvas").addEventListener("click", graphAction);
$("graph-canvas").addEventListener("keydown", graphAction);
$("text-tab").onclick = () => setMode("text");
$("graph-tab").onclick = () => setMode("graph");
document.querySelector(".tabs").onkeydown = (event) => {
  if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
  event.preventDefault();
  setMode(event.key === "Home" ? "text" : event.key === "End" ? "graph" : mode === "text" ? "graph" : "text");
  $(mode + "-tab").focus();
};
$("indent").onchange = $("expand-generics").onchange = () => { persist(); format(); };
$("wrap").onchange = () => { sourceEditor.dispatch({ effects: wrapping.reconfigure($("wrap").checked ? EditorView.lineWrapping : []) }); persist(); };
$("clear").onclick = () => { setDocument(sourceEditor, ""); invalidate(); sourceEditor.focus(); };
$("copy").onclick = copy;
$("save").onclick = save;
$("open").onclick = () => $("file").click();
$("file").onchange = async () => {
  const file = $("file").files[0];
  if (!file) return;
  try {
    if (file.size > 200_000) throw new Error("Input exceeds 200 KB. Open a file that contains one type.");
    const text = new TextDecoder("utf-8", { fatal: true }).decode(await file.arrayBuffer());
    setDocument(sourceEditor, text);
    invalidate();
    format();
    sourceEditor.focus();
  } catch (error) { status(error.message, true); }
  finally { $("file").value = ""; }
};
$("expand-all").onclick = () => { collapsed.clear(); renderGraph(); revealGraphSelection(); };
$("collapse-all").onclick = () => { collapsed = new Set(branchIDs(result.graph)); if (selectedID) selectNode("root", "graph"); renderGraph(); };
$("zoom-in").onclick = () => { zoom = Math.min(1.5, zoom + 0.1); renderGraph(); revealGraphSelection(); };
$("zoom-out").onclick = () => { zoom = Math.max(0.1, zoom - 0.1); renderGraph(); revealGraphSelection(); };
$("fit").onclick = () => { zoom = Math.min(1, Math.max(0.05, Math.min($("graph-scroll").clientWidth / graphData.layout.width, $("graph-scroll").clientHeight / graphData.layout.height))); renderGraph(); };
document.addEventListener("keydown", (event) => {
  if (!(event.metaKey || event.ctrlKey)) return;
  const key = event.key.toLowerCase();
  if (key === "o") { event.preventDefault(); if (ready) $("file").click(); }
  else if (key === "s") { event.preventDefault(); save(); }
  else if (key === "c" && event.shiftKey) { event.preventDefault(); copy(); }
  else if (key === "enter") { event.preventDefault(); format(); }
});
setMode(mode);

try {
  await init();
  ready = true;
  for (const id of ["open", "indent", "expand-generics"]) $(id).disabled = false;
  sourceEditor.dispatch({ effects: editable.reconfigure(EditorView.editable.of(true)) });
  status("Paste a type to begin.");
} catch (error) {
  status("The formatter could not load. Reload the page to try again.", true);
  console.error(error);
}
