import { test, expect } from "@playwright/test";
import { fileURLToPath } from "node:url";

let errors = [];
const source = (page) => page.getByRole("textbox", { name: "Source typealias", exact: true });
const textTree = (page) => page.getByRole("textbox", { name: "Formatted type tree", exact: true });
const sourceMark = (page) => page.locator("#source-editor .cm-linked-highlight");
const outputMark = (page) => page.locator("#text-editor .cm-linked-highlight");

test.beforeEach(async ({ page }) => {
  errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("console", (message) => { if (message.type() === "error") errors.push(message.text()); });
  await page.goto("./");
  await expect(page.locator("#status")).toHaveText("Paste a type to begin.");
});
test.afterEach(() => expect(errors).toEqual([]));

test("links both text panes and graph nodes without confusing duplicate names", async ({ page }) => {
  await expect(page.getByRole("button", { name: "Copy", exact: true })).toBeDisabled();
  await source(page).fill("typealias Body = Pair<Box<First>, Box<Second>>");
  await expect(page.locator("#status")).toContainText("5 nodes");
  await source(page).press("ControlOrMeta+End");
  for (let i = 0; i < 3; i++) await source(page).press("ArrowLeft");
  await expect(outputMark(page)).toHaveText("Second");
  await page.getByRole("tab", { name: "Graph", exact: true }).click();
  await expect(page.getByRole("button", { name: "Second", exact: true })).toHaveAttribute("aria-pressed", "true");
  await page.getByRole("button", { name: "Box", exact: true }).nth(1).click();
  await expect(sourceMark(page)).toHaveText("Box<Second>");
  await page.getByRole("tab", { name: "Text tree", exact: true }).click();
  await expect(outputMark(page)).toHaveText("Box<Second>");
  await textTree(page).press("ControlOrMeta+Home");
  await textTree(page).press("ArrowDown");
  for (let i = 0; i < 5; i++) await textTree(page).press("ArrowRight");
  await expect(sourceMark(page)).toHaveText("Box<First>");
  const original = await textTree(page).textContent();
  await textTree(page).press("a");
  await expect(textTree(page)).toHaveText(original);
});

test("reveals a source-selected leaf below collapsed ancestors", async ({ page }) => {
  await source(page).fill("Outer<Box<Box<Box<Leaf>>>>");
  await expect(page.locator("#status")).toContainText("5 nodes");
  await page.getByRole("tab", { name: "Graph", exact: true }).click();
  await page.getByRole("button", { name: "Collapse all", exact: true }).click();
  await expect(page.getByRole("button", { name: "Leaf", exact: true })).toHaveCount(0);
  await source(page).press("ControlOrMeta+End");
  for (let i = 0; i < 5; i++) await source(page).press("ArrowLeft");
  const leaf = page.getByRole("button", { name: "Leaf", exact: true });
  await expect(leaf).toHaveAttribute("aria-pressed", "true");
  await expect(leaf).toBeInViewport();
  await expect(sourceMark(page)).toHaveText("Leaf");
});

test("maps Unicode inside Markdown and preserves selection when indentation changes", async ({ page }) => {
  await source(page).fill("```swift\npublic typealias Body = Pair<`😀`, (Modifier in _123ABC)<Value>>\n```");
  await expect(page.locator("#status")).toContainText("4 nodes");
  await page.getByRole("tab", { name: "Graph", exact: true }).click();
  await page.getByRole("button", { name: "`😀`", exact: true }).click();
  await expect(sourceMark(page)).toHaveText("`😀`");
  await page.getByRole("combobox", { name: "Indentation" }).selectOption("0");
  await page.getByRole("tab", { name: "Text tree", exact: true }).click();
  await expect(outputMark(page)).toHaveText("`😀`");
  expect(await textTree(page).textContent()).toContain("\t");
});

test("clears mappings and disables export for invalid or empty input", async ({ page }) => {
  await source(page).fill("Pair<A, B>");
  await expect(page.locator("#status")).toContainText("3 nodes");
  await page.getByRole("tab", { name: "Graph", exact: true }).click();
  await page.getByRole("button", { name: "B", exact: true }).click();
  await expect(sourceMark(page)).toHaveText("B");
  await source(page).fill("Pair<A,");
  await expect(page.locator("#status")).toContainText("Missing closing");
  await expect(sourceMark(page)).toHaveCount(0);
  await expect(page.locator("[data-node-id]")).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Save", exact: true })).toBeDisabled();
  await page.getByRole("button", { name: "Clear", exact: true }).click();
  await expect(page.locator("#status")).toHaveText("Paste a type to begin.");
  const nested = "Box<".repeat(128) + "Leaf" + ">".repeat(128);
  await source(page).fill(nested);
  await expect(page.locator("#status")).toContainText("129 nodes");
  await source(page).fill("Box<" + nested + ">");
  await expect(page.locator("#status")).toContainText("Nesting exceeds 128 levels");
});

test("loads a real fixture and exports the visible graph as SVG", async ({ page }) => {
  const fixture = fileURLToPath(new URL("../../Packages/TypeAliasFormatterCore/Tests/TypeAliasFormatterCoreTests/Fixtures/ResolvedLabelStyle.txt", import.meta.url));
  await page.locator("#file").setInputFiles(fixture);
  await expect(page.locator("#status")).toContainText("27 nodes");
  await page.getByRole("tab", { name: "Graph", exact: true }).click();
  await page.getByRole("button", { name: "Collapse all", exact: true }).click();
  const download = page.waitForEvent("download");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  const file = await download;
  expect(file.suggestedFilename()).toBe("FormattedTypealias.svg");
  const stream = await file.createReadStream();
  let svg = "";
  for await (const chunk of stream) svg += chunk.toString();
  expect(svg).toContain("<svg");
  expect(svg.match(/data-node-id=/g)).toHaveLength(1);
});

test("keeps preferences but starts empty after reload, including mobile layout", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.getByRole("checkbox", { name: "Wrap lines", exact: true }).uncheck();
  await page.getByRole("combobox", { name: "Indentation" }).selectOption("8");
  await source(page).fill("Box<Value>");
  await expect(page.locator("#status")).toContainText("2 nodes");
  await page.reload();
  await expect(page.locator("#status")).toHaveText("Paste a type to begin.");
  await expect(page.getByRole("checkbox", { name: "Wrap lines", exact: true })).not.toBeChecked();
  await expect(page.getByRole("combobox", { name: "Indentation" })).toHaveValue("8");
  await expect(page.getByRole("button", { name: "Clear", exact: true })).toBeDisabled();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});
