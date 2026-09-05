#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const ARTIFACT_TOOL_PATH =
  process.env.CODEX_ARTIFACT_TOOL_PATH ||
  "/Users/jipengcheng/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";
const { SpreadsheetFile, Workbook } = await import(pathToFileURL(ARTIFACT_TOOL_PATH).href);

const OUTPUT_PATH = path.join(SCRIPT_DIR, "us_cross_border_equity_positions.xlsx");
const INSPECT_PATH = `${OUTPUT_PATH}.inspect.ndjson`;
const RENDER_DIR = path.join(SCRIPT_DIR, "tmp", "workbook_renders");

const FONT = "Arial";
const NAVY = "#1F4E78";
const BLUE = "#D9EAF7";
const LIGHT_BLUE = "#EAF2F8";
const GREEN = "#E2F0D9";
const AMBER = "#FFF2CC";
const GRAY = "#667085";
const LIGHT_GRAY = "#F2F4F7";
const WHITE = "#FFFFFF";
const DARK = "#1D2939";

function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = "";
  let quoted = false;
  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    if (quoted) {
      if (char === '"' && text[i + 1] === '"') {
        field += '"';
        i += 1;
      } else if (char === '"') {
        quoted = false;
      } else {
        field += char;
      }
    } else if (char === '"') {
      quoted = true;
    } else if (char === ",") {
      row.push(field);
      field = "";
    } else if (char === "\n") {
      row.push(field);
      rows.push(row);
      row = [];
      field = "";
    } else if (char !== "\r") {
      field += char;
    }
  }
  if (field.length > 0 || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  return rows;
}

function isDateColumn(header) {
  return ["date", "survey_date", "as_of", "query_date"].includes(header);
}

function isNumericColumn(header) {
  return (
    ["rank", "survey_year"].includes(header) ||
    header.includes("usd_millions") ||
    header.includes("usd_billions") ||
    header.includes("share_of_") ||
    header.includes("_over_corporate_gva")
  );
}

function convertCsv(rows) {
  if (rows.length === 0) return { headers: [], records: [] };
  const headers = rows[0];
  const records = rows.slice(1).filter((r) => r.some((cell) => cell !== "")).map((r) =>
    headers.map((header, index) => {
      const value = r[index] ?? "";
      if (value === "") return null;
      if (isDateColumn(header)) return new Date(`${value}T00:00:00Z`);
      if (isNumericColumn(header)) {
        const number = Number(value);
        return Number.isFinite(number) ? number : null;
      }
      return value;
    }),
  );
  return { headers, records };
}

async function readCsv(filename) {
  const text = await fs.readFile(path.join(SCRIPT_DIR, filename), "utf8");
  return convertCsv(parseCsv(text));
}

function excelColumn(index) {
  let n = index + 1;
  let label = "";
  while (n > 0) {
    const remainder = (n - 1) % 26;
    label = String.fromCharCode(65 + remainder) + label;
    n = Math.floor((n - 1) / 26);
  }
  return label;
}

function quoteSheet(name) {
  return `'${name.replaceAll("'", "''")}'`;
}

function selectInspectionLines(ndjson) {
  const selected = [];
  for (const line of String(ndjson || "").split("\n")) {
    if (!line.trim().startsWith("{")) continue;
    try {
      const record = JSON.parse(line);
      const keep =
        record.kind === "workbook" ||
        record.kind === "sheet" ||
        record.kind === "match" ||
        (record.kind === "region" && record.sheet === "Summary") ||
        (record.kind === "formula" && record.sheet === "Summary");
      if (keep) selected.push(JSON.stringify(record));
    } catch {
      // Ignore non-NDJSON diagnostic lines emitted by bounded inspect calls.
    }
  }
  return selected;
}

function sourceCell(sheetName, data, header, dataIndex = 0) {
  const columnIndex = data.headers.indexOf(header);
  if (columnIndex < 0) throw new Error(`Column ${header} not found in ${sheetName}`);
  const row = 5 + dataIndex;
  return `${quoteSheet(sheetName)}!$${excelColumn(columnIndex)}$${row}`;
}

function sourceLastCell(sheetName, data, header) {
  return sourceCell(sheetName, data, header, data.records.length - 1);
}

function setColumnWidth(sheet, columnIndex, header) {
  let width = 14;
  if (["rank", "survey_year"].includes(header)) width = 10;
  else if (isDateColumn(header)) width = 13;
  else if (header === "quarter") width = 11;
  else if (header === "AHP_period") width = 25;
  else if (header === "position_side") width = 39;
  else if (header === "country_code") width = 14;
  else if (["country_or_group", "foreign_group", "holder_sector"].includes(header)) width = 26;
  else if (header === "entity_type") width = 28;
  else if (header.includes("status")) width = 29;
  else if (header === "coverage" || header === "interpretation") width = 55;
  else if (header === "title") width = 72;
  else if (header === "source_url" || header === "download_url") width = 48;
  else if (header === "source_file" || header === "dataset") width = 30;
  else if (header === "classification") width = 42;
  else if (header === "member_or_rule" || header === "treatment" || header === "applies_to") width = 42;
  else if (header.includes("usd_") || header.includes("share") || header.includes("over_corporate")) width = 18;
  sheet.getRange(`${excelColumn(columnIndex)}:${excelColumn(columnIndex)}`).format.columnWidth = width;
}

function applyFormats(sheet, data, startRow = 4) {
  const dataStart = startRow + 1;
  const dataEnd = startRow + data.records.length;
  data.headers.forEach((header, index) => {
    setColumnWidth(sheet, index, header);
    if (data.records.length === 0) return;
    const column = excelColumn(index);
    const range = sheet.getRange(`${column}${dataStart}:${column}${dataEnd}`);
    if (isDateColumn(header)) range.format.numberFormat = "yyyy-mm-dd";
    else if (header.includes("share") || header.includes("_over_corporate_gva")) range.format.numberFormat = "0.0%";
    else if (header.includes("usd_millions") || header.includes("usd_billions") || header === "corporate_gva_usd_billions_saar") {
      range.format.numberFormat = "#,##0.000";
    } else if (["rank", "survey_year"].includes(header)) range.format.numberFormat = "0";
  });
}

function addDataSheet(workbook, config) {
  const { name, title, note, data, tableName, tabColor = NAVY } = config;
  const sheet = workbook.worksheets.add(name);
  const lastColumn = excelColumn(data.headers.length - 1);
  sheet.tabColor = tabColor;
  sheet.mergeCells(`A1:${lastColumn}1`);
  sheet.mergeCells(`A2:${lastColumn}2`);
  sheet.getRange("A1").values = [[title]];
  sheet.getRange("A1").format.font = { name: FONT, size: 16, bold: true, color: DARK };
  sheet.getRange("A2").values = [[note]];
  sheet.getRange("A2").format.font = { name: FONT, size: 10, italic: true, color: GRAY };
  sheet.getRange("A2").format.wrapText = true;
  sheet.getRange("A2").format.rowHeight = 28;

  const matrix = [data.headers, ...data.records];
  const lastRow = 4 + data.records.length;
  sheet.getRangeByIndexes(3, 0, matrix.length, data.headers.length).values = matrix;
  sheet.getRange(`A4:${lastColumn}4`).format = {
    fill: NAVY,
    font: { name: FONT, size: 9, bold: true, color: WHITE },
    horizontalAlignment: "center",
    verticalAlignment: "center",
    wrapText: true,
    borders: { preset: "inside", style: "thin", color: WHITE },
  };
  sheet.getRange(`A4:${lastColumn}4`).format.rowHeight = 34;
  if (data.records.length > 0) {
    sheet.getRange(`A5:${lastColumn}${lastRow}`).format.font = { name: FONT, size: 10, color: DARK };
    const table = sheet.tables.add(`A4:${lastColumn}${lastRow}`, true, tableName);
    table.style = "TableStyleMedium2";
  }
  sheet.freezePanes.freezeRows(4);
  applyFormats(sheet, data, 4);
  if (name === "Sources" && data.records.length > 0) {
    sheet.getRange(`A5:${lastColumn}${lastRow}`).format.wrapText = true;
    sheet.getRange(`A5:${lastColumn}${lastRow}`).format.rowHeight = 46;
    sheet.getRange("B:B").format.columnWidth = 22;
    sheet.getRange("E:E").format.columnWidth = 22;
    sheet.getRange("F:F").format.columnWidth = 26;
  }
  return sheet;
}

function writeSection(sheet, row, title, lastColumn = "E") {
  sheet.getRange(`A${row}:${lastColumn}${row}`).format = {
    fill: BLUE,
    font: { name: FONT, size: 10, bold: true, color: DARK },
    borders: { preset: "outside", style: "thin", color: "#9FBAD0" },
  };
  sheet.getRange(`A${row}`).values = [[title]];
}

function formatSummary(sheet) {
  sheet.showGridLines = false;
  sheet.tabColor = NAVY;
  sheet.getRange("A1").values = [["U.S. cross-border equity positions"]];
  sheet.getRange("A1").format.font = { name: FONT, size: 18, bold: true, color: DARK };
  sheet.getRange("A2").values = [["Gross IMA positions, annual TIC country surveys, and long-run foreign decompositions; updated 2026-09-04"]];
  sheet.getRange("A2").format.font = { name: FONT, size: 10, italic: true, color: GRAY };
  sheet.getRange("A2").format.wrapText = true;
  sheet.getRange("A2").format.rowHeight = 28;
  ["A", "B", "C", "D", "E"].forEach((column, index) => {
    sheet.getRange(`${column}:${column}`).format.columnWidth = [38, 22, 4, 38, 22][index];
  });
  sheet.getRange("A1:E40").format.font = { name: FONT, size: 10, color: DARK };
}

function buildSummary(workbook, datasets, sheet) {
  formatSummary(sheet);
  const aggregate = datasets.aggregate;
  const assetRank = datasets.assetRank;
  const liabilityRank = datasets.liabilityRank;
  const sectors = datasets.sectors;

  writeSection(sheet, 4, "Headline IMA positions (latest quarter; USD billions)");
  sheet.getRange("A5:A11").values = [
    ["Latest IMA observation"],
    ["U.S. equity assets abroad"],
    ["U.S. equity liabilities to foreigners"],
    ["Net foreign equity position (assets - liabilities)"],
    ["Gross cross-border equity position"],
    ["Net equity position / corporate GVA"],
    ["AHP period"],
  ];
  sheet.getRange("B5:B11").formulas = [
    [`=${sourceLastCell("Aggregate history", aggregate, "date")}`],
    [`=${sourceLastCell("Aggregate history", aggregate, "us_equity_assets_abroad_usd_billions")}`],
    [`=${sourceLastCell("Aggregate history", aggregate, "us_equity_liabilities_to_foreigners_usd_billions")}`],
    [`=${sourceLastCell("Aggregate history", aggregate, "net_foreign_equity_position_usd_billions")}`],
    [`=${sourceLastCell("Aggregate history", aggregate, "gross_cross_border_equity_usd_billions")}`],
    [`=${sourceLastCell("Aggregate history", aggregate, "net_equity_position_over_corporate_gva")}`],
    [`=${sourceLastCell("Aggregate history", aggregate, "AHP_period")}`],
  ];
  sheet.getRange("B5").format.numberFormat = "yyyy-mm-dd";
  sheet.getRange("B6:B9").format.numberFormat = "#,##0.0";
  sheet.getRange("B10").format.numberFormat = "0.0%";

  writeSection(sheet, 13, "Latest TIC portfolio-equity country surveys (assets preliminary; liabilities final)");
  sheet.getRange("A14:A18").values = [
    ["Asset survey date"],
    ["U.S. portfolio equity assets abroad (USD billions)"],
    ["Largest issuer location"],
    ["Issuer-location value (USD billions)"],
    ["Issuer-location share"],
  ];
  sheet.getRange("B14:B18").formulas = [
    [`=${sourceCell("Asset ranking", assetRank, "survey_date")}`],
    [`=${sourceCell("Asset ranking", assetRank, "survey_total_equity_usd_millions")}/1000`],
    [`=${sourceCell("Asset ranking", assetRank, "country_or_group")}`],
    [`=${sourceCell("Asset ranking", assetRank, "equity_value_usd_billions")}`],
    [`=${sourceCell("Asset ranking", assetRank, "share_of_survey_equity_total")}`],
  ];
  sheet.getRange("D14:D18").values = [
    ["Liability survey date"],
    ["U.S. portfolio equity liabilities (USD billions)"],
    ["Largest reported holder/custody location"],
    ["Holder-location value (USD billions)"],
    ["Holder-location share"],
  ];
  sheet.getRange("E14:E18").formulas = [
    [`=${sourceCell("Liability ranking", liabilityRank, "survey_date")}`],
    [`=${sourceCell("Liability ranking", liabilityRank, "survey_total_equity_usd_millions")}/1000`],
    [`=${sourceCell("Liability ranking", liabilityRank, "country_or_group")}`],
    [`=${sourceCell("Liability ranking", liabilityRank, "equity_value_usd_billions")}`],
    [`=${sourceCell("Liability ranking", liabilityRank, "share_of_survey_equity_total")}`],
  ];
  sheet.getRange("B14:E14").format.numberFormat = "yyyy-mm-dd";
  sheet.getRange("B15:B17").format.numberFormat = "#,##0.0";
  sheet.getRange("E15:E17").format.numberFormat = "#,##0.0";
  sheet.getRange("B18").format.numberFormat = "0.0%";
  sheet.getRange("E18").format.numberFormat = "0.0%";

  writeSection(sheet, 20, "Private U.S. holder sectors of foreign portfolio equity");
  sheet.getRange("A21:A24").values = [
    ["Sector-panel date"],
    ["Private portfolio-equity total (USD billions)"],
    ["Largest U.S. holder sector"],
    ["Largest-sector value and share"],
  ];
  const sectorEnd = 4 + sectors.records.length;
  sheet.getRange("B21:B24").formulas = [
    [`=${sourceCell("Holder sectors", sectors, "as_of")}`],
    [`=SUM('Holder sectors'!$D$5:$D$${sectorEnd})`],
    [`=${sourceCell("Holder sectors", sectors, "holder_sector")}`],
    [`=${sourceCell("Holder sectors", sectors, "value_usd_billions")}`],
  ];
  sheet.getRange("D24").values = [["Share"]];
  sheet.getRange("E24").formulas = [[`=${sourceCell("Holder sectors", sectors, "share_of_private_portfolio_equity_assets")}`]];
  sheet.getRange("B21").format.numberFormat = "yyyy-mm-dd";
  sheet.getRange("B22:B24").format.numberFormat = "#,##0.0";
  sheet.getRange("E24").format.numberFormat = "0.0%";

  writeSection(sheet, 26, "Accounting checks and interpretation");
  sheet.getRange("A27:A30").values = [
    ["Net identity residual (USD billions)"],
    ["Gross identity residual (USD billions)"],
    ["Net identity status"],
    ["Gross identity status"],
  ];
  sheet.getRange("B27:B30").formulas = [
    ["=B6-B7-B8"],
    ["=B6+B7-B9"],
    ['=IF(ABS(B27)<0.000001,"PASS","REVIEW")'],
    ['=IF(ABS(B28)<0.000001,"PASS","REVIEW")'],
  ];
  sheet.getRange("B27:B28").format.numberFormat = "0.000000";
  sheet.getRange("B29:B30").conditionalFormats.add("containsText", {
    text: "PASS",
    format: { fill: GREEN, font: { bold: true, color: "#1E5631" } },
  });
  sheet.getRange("A32:E32").values = [["Coverage note", "IMA is the broad macro stock; TIC country panels cover portfolio equity and exclude direct investment. Survey totals should therefore not be forced to equal IMA totals.", null, null, null]];
  sheet.getRange("A33:E33").values = [["Geography note", "Asset-side countries are issuer residences. Liability-side countries are reported holder/custody locations, which need not identify the ultimate beneficial owner.", null, null, null]];
  sheet.getRange("A34:E34").values = [["Financial-centre note", "Large Cayman, UK, Luxembourg, Ireland, and similar positions can reflect fund domicile, issuance, or custody chains; they are not mechanically final-demand exposures.", null, null, null]];
  sheet.getRange("A32:A34").format.font = { name: FONT, size: 10, bold: true, color: DARK };
  sheet.getRange("B32:E34").format.wrapText = true;
  sheet.getRange("B32:E34").format.fill = LIGHT_GRAY;
  sheet.getRange("A32:E34").format.rowHeight = 35;
  sheet.mergeCells("B32:E32");
  sheet.mergeCells("B33:E33");
  sheet.mergeCells("B34:E34");
  sheet.getRange("A5:A30").format.font = { name: FONT, size: 10, color: DARK };
  sheet.getRange("B5:B30").format.font = { name: FONT, size: 10, bold: true, color: DARK };
  sheet.getRange("E14:E24").format.font = { name: FONT, size: 10, bold: true, color: DARK };
  return sheet;
}

function addDefinitionsSheet(workbook, functionalCrosswalk, stableCrosswalk) {
  const sheet = workbook.worksheets.add("Definitions");
  sheet.tabColor = GRAY;
  sheet.showGridLines = false;
  sheet.getRange("A1").values = [["Definitions and grouping rules"]];
  sheet.getRange("A1").format.font = { name: FONT, size: 16, bold: true, color: DARK };
  sheet.getRange("A2").values = [["The decomposition is deliberately reported in both economic-function and stable-country-panel forms."]];
  sheet.getRange("A2").format.font = { name: FONT, size: 10, italic: true, color: GRAY };

  sheet.getRange("A4:B10").values = [
    ["Concept", "Definition / treatment"],
    ["IMA gross equity assets", "Rest-of-world equity liabilities; interpreted as U.S. gross foreign equity assets."],
    ["IMA gross equity liabilities", "Rest-of-world equity assets; interpreted as U.S. gross foreign equity liabilities."],
    ["TIC asset geography", "Residence of the foreign issuer of the security."],
    ["TIC liability geography", "Reported foreign holder/custody location; ultimate beneficial ownership may differ."],
    ["Suppressed TIC cells", "An asterisk means less than $0.5 million; recorded at the $0.25 million midpoint and flagged."],
    ["AHP period bands", "1990Q1-2001Q4; 2002Q1-2007Q4; 2008Q1-2023Q3; post-AHP from 2023Q4."],
  ];
  sheet.getRange("A4:B4").format = { fill: NAVY, font: { name: FONT, size: 9, bold: true, color: WHITE } };
  sheet.getRange("A5:A10").format.font = { name: FONT, size: 10, bold: true, color: DARK };
  sheet.getRange("B5:B10").format = { font: { name: FONT, size: 10, color: DARK }, wrapText: true };
  sheet.getRange("A4:B10").format.borders = { preset: "outside", style: "thin", color: "#B8C4CE" };

  const functionalStart = 14;
  sheet.getRange(`A${functionalStart}`).values = [["Functional / location-role grouping"]];
  sheet.getRange(`A${functionalStart}`).format.font = { name: FONT, size: 12, bold: true, color: DARK };
  const functionalHeader = functionalStart + 1;
  sheet.getRangeByIndexes(functionalHeader - 1, 0, functionalCrosswalk.records.length + 1, functionalCrosswalk.headers.length).values = [functionalCrosswalk.headers, ...functionalCrosswalk.records];
  const functionalEnd = functionalHeader + functionalCrosswalk.records.length;
  sheet.getRange(`A${functionalHeader}:D${functionalHeader}`).format = { fill: NAVY, font: { name: FONT, size: 9, bold: true, color: WHITE }, wrapText: true };
  sheet.tables.add(`A${functionalHeader}:D${functionalEnd}`, true, "FunctionalCrosswalkTable").style = "TableStyleMedium2";

  const stableStart = functionalEnd + 4;
  sheet.getRange(`A${stableStart}`).values = [["Stable separately reported panel"]];
  sheet.getRange(`A${stableStart}`).format.font = { name: FONT, size: 12, bold: true, color: DARK };
  const stableHeader = stableStart + 1;
  sheet.getRangeByIndexes(stableHeader - 1, 0, stableCrosswalk.records.length + 1, stableCrosswalk.headers.length).values = [stableCrosswalk.headers, ...stableCrosswalk.records];
  const stableEnd = stableHeader + stableCrosswalk.records.length;
  sheet.getRange(`A${stableHeader}:D${stableHeader}`).format = { fill: NAVY, font: { name: FONT, size: 9, bold: true, color: WHITE }, wrapText: true };
  sheet.tables.add(`A${stableHeader}:D${stableEnd}`, true, "StableCrosswalkTable").style = "TableStyleMedium2";

  [28, 42, 58, 46].forEach((width, index) => {
    sheet.getRange(`${excelColumn(index)}:${excelColumn(index)}`).format.columnWidth = width;
  });
  sheet.getRange(`A${functionalHeader}:D${stableEnd}`).format.font = { name: FONT, size: 9, color: DARK };
  sheet.freezePanes.freezeRows(4);
  return { sheet, renderEnd: stableEnd };
}

async function main() {
  const datasets = {
    aggregate: await readCsv("us_cross_border_equity_positions_quarterly.csv"),
    sectors: await readCsv("latest_us_holder_sector_equity_assets.csv"),
    assetRank: await readCsv("latest_equity_asset_country_ranking.csv"),
    liabilityRank: await readCsv("latest_equity_liability_country_ranking.csv"),
    assetCountry: await readCsv("us_portfolio_equity_assets_by_country.csv"),
    liabilityCountry: await readCsv("us_portfolio_equity_liabilities_by_country.csv"),
    functional: await readCsv("long_run_equity_functional_decomposition.csv"),
    stable: await readCsv("long_run_equity_stable_panel_decomposition.csv"),
    functionalCrosswalk: await readCsv("equity_functional_crosswalk.csv"),
    stableCrosswalk: await readCsv("equity_stable_panel_crosswalk.csv"),
    sources: await readCsv("us_equity_positions_source_metadata.csv"),
  };

  const workbook = Workbook.create();
  const summarySheet = workbook.worksheets.add("Summary");
  addDataSheet(workbook, {
    name: "Holder sectors",
    title: "Private U.S. holders of foreign portfolio equity",
    note: "Treasury/CPIS sector panel, June 2025. Coverage is private U.S. cross-border portfolio equity claims; direct investment is excluded.",
    data: datasets.sectors,
    tableName: "HolderSectorTable",
    tabColor: "#039855",
  });
  addDataSheet(workbook, {
    name: "Asset ranking",
    title: "U.S. portfolio equity assets abroad: latest country ranking",
    note: "Country is the foreign issuer's residence. The 2025 asset survey is preliminary; aggregates and historical bridges are retained and labelled.",
    data: datasets.assetRank,
    tableName: "AssetRankingTable",
    tabColor: "#175CD3",
  });
  addDataSheet(workbook, {
    name: "Liability ranking",
    title: "U.S. portfolio equity liabilities: latest foreign-location ranking",
    note: "Country is the reported foreign holder/custody location, not necessarily the ultimate beneficial owner. The June 2025 liability survey is final.",
    data: datasets.liabilityRank,
    tableName: "LiabilityRankingTable",
    tabColor: "#B42318",
  });
  addDataSheet(workbook, {
    name: "Aggregate history",
    title: "Quarterly U.S. gross and net cross-border equity positions, 1990-present",
    note: "IMA end-of-quarter levels. Assets minus liabilities equals the net foreign equity position; corporate GVA ratios use BEA/FRED A451RC1Q027SBEA.",
    data: datasets.aggregate,
    tableName: "AggregateHistoryTable",
    tabColor: NAVY,
  });
  addDataSheet(workbook, {
    name: "Asset country history",
    title: "U.S. portfolio equity assets abroad by issuer residence",
    note: "Annual or benchmark TIC surveys. The file includes all reported countries, aggregates, historical bridges, observation flags, and survey totals.",
    data: datasets.assetCountry,
    tableName: "AssetCountryHistoryTable",
    tabColor: "#175CD3",
  });
  addDataSheet(workbook, {
    name: "Liability country history",
    title: "U.S. portfolio equity liabilities by reported foreign location",
    note: "Annual or benchmark TIC surveys. Pre-1990 observations are retained in this source table but labelled outside the requested window.",
    data: datasets.liabilityCountry,
    tableName: "LiabilityCountryHistoryTable",
    tabColor: "#B42318",
  });
  addDataSheet(workbook, {
    name: "Functional decomposition",
    title: "Long-run portfolio-equity geography: functional / location-role grouping",
    note: "Separate asset and liability panels; each survey-date side sums exactly to its official survey total. Use for economic interpretation of financial centres and regional blocs.",
    data: datasets.functional,
    tableName: "FunctionalDecompositionTable",
    tabColor: "#7F56D9",
  });
  addDataSheet(workbook, {
    name: "Stable-panel decomposition",
    title: "Long-run portfolio-equity geography: stable named-economy panel",
    note: "Japan, mainland China, United Kingdom, Canada, Hong Kong, Taiwan, Singapore, South Korea, plus an exact all-other-foreign residual.",
    data: datasets.stable,
    tableName: "StablePanelDecompositionTable",
    tabColor: "#F79009",
  });
  const definitions = addDefinitionsSheet(
    workbook,
    datasets.functionalCrosswalk,
    datasets.stableCrosswalk,
  );
  addDataSheet(workbook, {
    name: "Sources",
    title: "Official source register",
    note: "FRED/Federal Reserve IMA aggregates, Treasury TIC portfolio surveys, the Treasury/CPIS holder-sector table, and corporate GVA normalization series.",
    data: datasets.sources,
    tableName: "SourceRegisterTable",
    tabColor: GRAY,
  });
  buildSummary(workbook, datasets, summarySheet);

  const sheetInspection = await workbook.inspect({
    kind: "sheet",
    include: "id,name",
    maxChars: 5000,
  });
  const inspection = await workbook.inspect({
    kind: "region",
    sheetId: "Summary",
    range: "A1:E34",
    include: "values,formulas",
    tableMaxRows: 40,
    tableMaxCols: 8,
    maxChars: 10000,
  });
  const formulaInspection = await workbook.inspect({
    kind: "formula",
    sheetId: "Summary",
    range: "A1:E34",
    maxChars: 8000,
    options: { maxResults: 100 },
  });
  const errorScan = await workbook.inspect({
    kind: "match",
    searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!",
    options: { useRegex: true, maxResults: 300 },
    summary: "final formula error scan",
    maxChars: 8000,
  });
  const summaryRange = workbook.worksheets.getItem("Summary").getRange("A1:E34");
  const compactInspect = [
    ...selectInspectionLines(sheetInspection.ndjson),
    ...selectInspectionLines(inspection.ndjson),
    ...selectInspectionLines(formulaInspection.ndjson),
    ...selectInspectionLines(errorScan.ndjson),
    JSON.stringify({
      kind: "verification",
      check: "summary values and formulas",
      values: summaryRange.values,
      formulas: summaryRange.formulas,
      formulaErrorScanText: String(errorScan.ndjson || "").slice(0, 4000),
    }),
  ];
  await fs.mkdir(RENDER_DIR, { recursive: true });
  const renderSpecs = [
    ["Summary", "A1:E34", 1.35],
    ["Holder sectors", "A1:I12", 1.0],
    ["Asset ranking", "A1:Q24", 0.68],
    ["Liability ranking", "A1:Q24", 0.68],
    ["Aggregate history", "A1:Q24", 0.70],
    ["Asset country history", "A1:P24", 0.72],
    ["Liability country history", "A1:P24", 0.72],
    ["Functional decomposition", "A1:L24", 0.82],
    ["Stable-panel decomposition", "A1:L24", 0.82],
    ["Definitions", `A1:D${definitions.renderEnd}`, 0.90],
    ["Sources", "A1:I12", 0.76],
  ];
  for (const [sheetName, range, scale] of renderSpecs) {
    const preview = await workbook.render({ sheetName, range, scale, format: "png" });
    const safeName = sheetName.toLowerCase().replaceAll(/[^a-z0-9]+/g, "_").replaceAll(/^_|_$/g, "");
    await fs.writeFile(path.join(RENDER_DIR, `${safeName}.png`), new Uint8Array(await preview.arrayBuffer()));
  }

  const output = await SpreadsheetFile.exportXlsx(workbook);
  await output.save(OUTPUT_PATH);
  await fs.writeFile(INSPECT_PATH, `${[...new Set(compactInspect)].join("\n")}\n`, "utf8");
  console.log(`Saved ${OUTPUT_PATH}`);
  console.log(`Saved ${INSPECT_PATH}`);
  console.log(`Saved ${renderSpecs.length} sheet renders to ${RENDER_DIR}`);
}

try {
  await main();
} catch (error) {
  const name = error?.name || "Error";
  const message = error?.message || String(error);
  console.error(`${name}: ${message}`);
  const conciseStack = String(error?.stack || "")
    .split("\n")
    .filter((line) => line.length < 800)
    .slice(1, 12)
    .join("\n");
  if (conciseStack) console.error(conciseStack);
  process.exitCode = 1;
}
