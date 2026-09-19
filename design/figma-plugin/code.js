/* TT App Screens — Figma generator
 * Content derived from TT/lib (Flutter / Material 3).
 * Run via Plugins > Development > Import plugin from manifest.
 */

// ---------------------------------------------------------------- tokens

const PINE = "#14532D";
const PINE_DARK = "#0F3D22";
const PINE_TINT = "#E7F0E9";
const SAND = "#F7F4EF";
const WHITE = "#FFFFFF";
const INK = "#1F2937";
const MUTED = "#6B7280";
const BORDER = "#E5E7EB";
const EMBER = "#F97316";
const SOS = "#DC2626";
const BLUE = "#2563EB";
const AMBER = "#F59E0B";
const GREEN = "#16A34A";
const MAP_BASE = "#E9E4D9";

const W = 360;
const H = 800;
const STATUS_H = 28;
const APPBAR_H = 60;
const NAV_H = 76;
const PAD = 24;
const CONTENT_W = W - PAD * 2;

const Y_APPBAR = STATUS_H;
const Y_BODY = STATUS_H + APPBAR_H;
const Y_NAV = H - NAV_H;
const BODY_NAV_H = Y_NAV - Y_BODY;

let FONT = { family: "Roboto", regular: "Regular", medium: "Medium", semibold: "Medium", bold: "Bold" };

const TS = {
  display: { size: 28, weight: "bold", color: INK },
  h1: { size: 24, weight: "bold", color: INK },
  h2: { size: 20, weight: "semibold", color: INK },
  title: { size: 16, weight: "semibold", color: INK },
  bodyStrong: { size: 14, weight: "medium", color: INK },
  body: { size: 14, weight: "regular", color: MUTED },
  label: { size: 13, weight: "medium", color: INK },
  caption: { size: 12, weight: "regular", color: MUTED },
  button: { size: 15, weight: "semibold", color: WHITE },
  dialogTitle: { size: 18, weight: "semibold", color: INK },
  coverTitle: { size: 52, weight: "bold", color: WHITE },
  coverSub: { size: 18, weight: "regular", color: "#C8D9CE" },
};

// ---------------------------------------------------------------- icons

const ICONS = {
  map: "M20.5 3l-.16.03L15 5.1 9 3 3.38 4.9c-.23.07-.38.28-.38.52V21c0 .28.22.5.5.5l.16-.03L9 19.4l6 2.1 5.62-1.9c.23-.07.38-.28.38-.52V3.5c0-.28-.22-.5-.5-.5zM15 19l-6-2.1V5l6 2.1V19z",
  groups: "M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z",
  radar: "M19.07 4.93l-1.41 1.41C19.1 7.79 20 9.79 20 12c0 4.42-3.58 8-8 8s-8-3.58-8-8c0-4.08 3.05-7.44 7-7.93v2.02C8.16 6.57 6 9.03 6 12c0 3.31 2.69 6 6 6s6-2.69 6-6c0-1.66-.67-3.16-1.76-4.24l-1.41 1.41C15.55 9.9 16 10.9 16 12c0 2.21-1.79 4-4 4s-4-1.79-4-4c0-1.86 1.28-3.41 3-3.86v2.14c-.6.35-1 .98-1 1.72 0 1.1.9 2 2 2s2-.9 2-2c0-.74-.4-1.38-1-1.72V2h-1C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10c0-2.76-1.12-5.26-2.93-7.07z",
  warning: "M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z",
  navigation: "M12 2L4.5 20.29l.71.71L12 18l6.79 3 .71-.71z",
  download: "M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z",
  logout: "M17 7l-1.41 1.41L18.17 11H8v2h10.17l-2.58 2.58L17 17l5-5zM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5z",
  terrain: "M14 6l-3.75 5 2.85 3.8-1.6 1.2C9.81 13.75 7 10 7 10l-6 8h22L14 6z",
  bluetooth: "M17.71 7.71L12 2h-1v7.59L6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 11 14.41V22h1l5.71-5.71-4.3-4.29 4.3-4.29zM13 5.83l1.88 1.88L13 9.59V5.83zm1.88 10.46L13 18.17v-3.76l1.88 1.88z",
  refresh: "M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z",
  person: "M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z",
  lock: "M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zM9 6c0-1.66 1.34-3 3-3s3 1.34 3 3v2H9V6zm9 14H6V10h12v10zm-6-3c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2z",
  email: "M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z",
  phone: "M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z",
  back: "M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z",
  add: "M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z",
  groupAdd: "M8 10H5V7H3v3H0v2h3v3h2v-3h3v-2zm10 1c1.66 0 3-1.34 3-3s-1.34-3-3-3-3 1.34-3 3 1.34 3 3 3zm-9 1c-2.33 0-7 1.17-7 3.5V19h14v-2.5C16 14.17 11.33 13 9 13zm10 0h-2c1.17.83 2 2 2 3.5V19h5v-2.5c0-2.33-4.67-3.5-5-3.5z",
  chevronRight: "M8.59 16.59L13.17 12 8.59 7.41 10 6l6 6-6 6z",
  chevronDown: "M16.59 8.59L12 13.17 7.41 8.59 6 10l6 6 6-6z",
  eye: "M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z",
};

// ---------------------------------------------------------------- helpers

function hexToRgb(hex) {
  const h = hex.replace("#", "");
  const full = h.length === 3 ? h[0] + h[0] + h[1] + h[1] + h[2] + h[2] : h;
  const n = parseInt(full, 16);
  return { r: ((n >> 16) & 255) / 255, g: ((n >> 8) & 255) / 255, b: (n & 255) / 255 };
}

function solid(hex, opacity) {
  return { type: "SOLID", color: hexToRgb(hex), opacity: opacity === undefined ? 1 : opacity };
}

function cssColor(hex) {
  const c = hexToRgb(hex);
  return "rgb(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + ")";
}

function shadow(strength) {
  return {
    type: "DROP_SHADOW",
    color: { r: 0.06, g: 0.09, b: 0.16, a: strength || 0.12 },
    offset: { x: 0, y: 6 },
    radius: 16,
    spread: 0,
    visible: true,
  };
}

function fixedFrame(name, w, h, fill) {
  const f = figma.createFrame();
  f.name = name;
  f.layoutMode = "NONE";
  f.resize(w, h);
  f.fills = fill ? [solid(fill)] : [];
  f.clipsContent = false;
  return f;
}

function stack(name, w, spacing, opts) {
  const o = opts || {};
  const f = figma.createFrame();
  f.name = name;
  f.layoutMode = "VERTICAL";
  f.primaryAxisSizingMode = "AUTO";
  f.counterAxisSizingMode = "FIXED";
  f.resize(w, 10);
  f.itemSpacing = spacing || 0;
  f.fills = o.fills === undefined ? [] : o.fills;
  f.clipsContent = o.clip === true;
  if (o.padX !== undefined) { f.paddingLeft = f.paddingRight = o.padX; }
  if (o.padY !== undefined) { f.paddingTop = f.paddingBottom = o.padY; }
  if (o.align) f.primaryAxisAlignItems = o.align;
  if (o.valign) f.counterAxisAlignItems = o.valign;
  return f;
}

function row(name, w, h, opts) {
  const o = opts || {};
  const f = figma.createFrame();
  f.name = name;
  f.layoutMode = "HORIZONTAL";
  f.primaryAxisSizingMode = "FIXED";
  f.counterAxisSizingMode = "FIXED";
  f.resize(w, h);
  f.itemSpacing = o.spacing || 0;
  f.fills = o.fills === undefined ? [] : o.fills;
  f.clipsContent = o.clip === true;
  if (o.padX !== undefined) { f.paddingLeft = f.paddingRight = o.padX; }
  if (o.padY !== undefined) { f.paddingTop = f.paddingBottom = o.padY; }
  if (o.align) f.primaryAxisAlignItems = o.align;
  if (o.valign) f.counterAxisAlignItems = o.valign;
  return f;
}

function text(chars, key, colorOverride) {
  const s = TS[key];
  const t = figma.createText();
  t.fontName = { family: FONT.family, style: FONT[s.weight] };
  t.characters = chars;
  t.fontSize = s.size;
  t.fills = [solid(colorOverride || s.color)];
  t.textAutoResize = "WIDTH_AND_HEIGHT";
  return t;
}

function wrapText(chars, key, width, colorOverride) {
  const t = text(chars, key, colorOverride);
  t.textAutoResize = "HEIGHT";
  t.resize(width, t.height);
  return t;
}

function iconNode(path, size, color) {
  const svg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="' + size + '" height="' + size +
    '" viewBox="0 0 24 24"><path d="' + path + '" fill="' + cssColor(color) + '"/></svg>';
  const n = figma.createNodeFromSvg(svg);
  n.name = "Icon";
  return n;
}

function gap(h) {
  const f = fixedFrame("Gap", 1, h, null);
  f.fills = [];
  return f;
}

function grow() {
  const f = fixedFrame("Spacer", 1, 1, null);
  f.fills = [];
  f.layoutGrow = 1;
  return f;
}

function add(parent, child) {
  parent.appendChild(child);
  return child;
}

function addFull(parent, child) {
  parent.appendChild(child);
  child.layoutAlign = "STRETCH";
  return child;
}

function at(node, x, y) {
  node.x = x;
  node.y = y;
  return node;
}

function stroke(node, hex, weight, sides) {
  node.strokes = [solid(hex)];
  node.strokeWeight = weight;
  node.strokeAlign = "INSIDE";
  if (sides) {
    node.strokeTopWeight = sides.top ? weight : 0;
    node.strokeBottomWeight = sides.bottom ? weight : 0;
    node.strokeLeftWeight = sides.left ? weight : 0;
    node.strokeRightWeight = sides.right ? weight : 0;
  }
  return node;
}

// ---------------------------------------------------------------- fonts & styles

async function resolveFont() {
  const attempts = [
    { family: "Inter", regular: "Regular", medium: "Medium", semibold: "Semi Bold", bold: "Bold" },
    { family: "Roboto", regular: "Regular", medium: "Medium", semibold: "Medium", bold: "Bold" },
  ];
  for (let i = 0; i < attempts.length; i++) {
    const a = attempts[i];
    try {
      const styles = [a.regular, a.medium, a.semibold, a.bold];
      for (let j = 0; j < styles.length; j++) {
        await figma.loadFontAsync({ family: a.family, style: styles[j] });
      }
      FONT = a;
      return;
    } catch (e) {
      /* next candidate */
    }
  }
}

function createStyles() {
  const paints = [
    ["Deep Pine", PINE], ["Pine Dark", PINE_DARK], ["Pine Tint", PINE_TINT],
    ["Sand", SAND], ["White", WHITE], ["Ink", INK], ["Muted", MUTED], ["Border", BORDER],
    ["Ember", EMBER], ["SOS Red", SOS], ["Tracking Blue", BLUE], ["Warm Amber", AMBER],
    ["Safe Green", GREEN], ["Map Base", MAP_BASE],
  ];
  for (let i = 0; i < paints.length; i++) {
    const s = figma.createPaintStyle();
    s.name = "TT/Color/" + paints[i][0];
    s.paints = [solid(paints[i][1])];
  }
  const keys = Object.keys(TS);
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i];
    const s = figma.createTextStyle();
    s.name = "TT/Text/" + key;
    s.fontName = { family: FONT.family, style: FONT[TS[key].weight] };
    s.fontSize = TS[key].size;
    s.fills = [solid(TS[key].color)];
  }
}

// ---------------------------------------------------------------- shell parts

function statusBar() {
  const f = row("Status Bar", W, STATUS_H, { padX: 20, align: "SPACE_BETWEEN", fills: [solid(SAND)] });
  const time = text("9:41", "caption", INK);
  time.fontSize = 13;
  add(f, time);

  const right = row("Status Icons", 0, STATUS_H, { spacing: 7, align: "MAX", valign: "CENTER", fills: [] });
  right.primaryAxisSizingMode = "AUTO";
  const bars = row("Signal", 20, STATUS_H, { spacing: 2, align: "MAX", valign: "MAX", fills: [] });
  const hs = [4, 6, 8, 10];
  for (let i = 0; i < hs.length; i++) add(bars, fixedFrame("bar", 3, hs[i], INK));
  add(right, bars);

  add(right, iconNode(
    "M12 21l3.5-4.5c-.9-.7-2.1-1.1-3.5-1.1s-2.6.4-3.5 1.1L12 21zm0-18C7.9 3 4.2 4.6 1.6 7.2l1.4 1.4C5.4 6.2 8.5 4.9 12 4.9s6.6 1.3 9 3.7l1.4-1.4C19.8 4.6 16.1 3 12 3z",
    15, INK));

  const batt = fixedFrame("Battery", 22, 11, WHITE);
  batt.cornerRadius = 2.5;
  stroke(batt, INK, 1);
  at(add(batt, fixedFrame("level", 15, 7, INK)), 2, 2);
  batt.children[0].cornerRadius = 1;
  add(right, batt);

  add(f, right);
  return f;
}

function appBar(titleText, opts) {
  const o = opts || {};
  const f = row("App Bar", W, APPBAR_H, { padX: 14, align: "SPACE_BETWEEN", fills: [solid(o.bg || SAND)] });
  stroke(f, BORDER, 1, { bottom: true });

  const left = row("Left", 0, APPBAR_H, { spacing: 6, align: "MIN", valign: "CENTER", fills: [] });
  left.primaryAxisSizingMode = "AUTO";
  if (o.back) add(left, iconNode(ICONS.back, 22, o.fg || INK));
  add(left, text(titleText, o.titleKey || "h2", o.fg));
  add(f, left);

  const right = row("Actions", 0, APPBAR_H, { spacing: 6, align: "MAX", valign: "CENTER", fills: [] });
  right.primaryAxisSizingMode = "AUTO";
  const actions = o.actions || [];
  for (let i = 0; i < actions.length; i++) {
    const a = actions[i];
    const size = a.size || 22;
    const wrap = fixedFrame("Action", 34, 34, null);
    wrap.cornerRadius = 10;
    at(add(wrap, iconNode(a.path, size, a.color || INK)), (34 - size) / 2, (34 - size) / 2);
    add(right, wrap);
  }
  if (actions.length) add(f, right);
  return f;
}

function bottomNav(active) {
  const f = row("Bottom Navigation", W, NAV_H, { padX: 12, align: "SPACE_BETWEEN", valign: "CENTER", fills: [solid(WHITE)] });
  stroke(f, BORDER, 1, { top: true });
  f.effects = [{
    type: "DROP_SHADOW",
    color: { r: 0.06, g: 0.09, b: 0.16, a: 0.08 },
    offset: { x: 0, y: -4 },
    radius: 12,
    spread: 0,
    visible: true,
  }];

  const items = [
    { label: "Map", icon: ICONS.map },
    { label: "Expeditions", icon: ICONS.groups },
    { label: "Radar", icon: ICONS.radar },
  ];
  for (let i = 0; i < items.length; i++) {
    const on = i === active;
    const tint = on ? PINE : MUTED;
    const cell = stack("Tab / " + items[i].label, 104, 4, { align: "CENTER", valign: "CENTER", fills: [] });
    cell.primaryAxisSizingMode = "FIXED";
    cell.counterAxisSizingMode = "FIXED";
    cell.resize(104, NAV_H - 10);
    add(cell, iconNode(items[i].icon, 24, tint));
    add(cell, text(items[i].label, "caption", tint));
    const pill = fixedFrame("Indicator", 44, 4, on ? PINE : null);
    pill.fills = on ? [solid(PINE)] : [];
    pill.cornerRadius = 2;
    add(cell, pill);
    add(f, cell);
  }
  return f;
}

function screenFrame(name) {
  const s = fixedFrame(name, W, H, SAND);
  s.clipsContent = true;
  return s;
}

function body(height, spacing, opts) {
  const o = opts || {};
  const b = stack("Body", W, spacing || 0, {
    padX: o.padX === undefined ? PAD : o.padX,
    padY: o.padY === undefined ? 0 : o.padY,
    fills: [solid(o.fill || SAND)],
    align: o.align,
    clip: true,
  });
  b.primaryAxisSizingMode = "FIXED";
  b.counterAxisSizingMode = "FIXED";
  b.resize(W, height);
  return b;
}

// ---------------------------------------------------------------- components

function inputField(label, value, opts) {
  const o = opts || {};
  const w = o.width || CONTENT_W;
  const st = stack("Field / " + label, w, 6, { fills: [] });
  add(st, text(label, "label"));
  const box = row("Input", w, 52, { padX: 14, align: "MIN", valign: "CENTER", spacing: 10, fills: [solid(WHITE)] });
  box.cornerRadius = 12;
  stroke(box, o.focused ? PINE : BORDER, o.focused ? 2 : 1);
  if (o.icon) add(box, iconNode(o.icon, 20, o.focused ? PINE : MUTED));
  add(box, text(value || o.placeholder || "", value ? "bodyStrong" : "body", value ? INK : MUTED));
  if (o.trailing === "chevron") {
    add(box, grow());
    add(box, iconNode(ICONS.chevronDown, 22, MUTED));
  }
  if (o.trailingIcon) {
    add(box, grow());
    add(box, iconNode(o.trailingIcon, 22, MUTED));
  }
  add(st, box);
  return st;
}

function primaryButton(label, opts) {
  const o = opts || {};
  const b = row("Button / " + label, o.width || CONTENT_W, 52, { align: "CENTER", valign: "CENTER", fills: [solid(o.color || PINE)] });
  b.cornerRadius = 12;
  b.effects = [shadow(0.16)];
  add(b, text(label, "button"));
  return b;
}

function fab(path, color, label) {
  const f = label
    ? row("FAB / " + label, 0, 56, { padX: 20, spacing: 10, align: "CENTER", valign: "CENTER", fills: [solid(color)] })
    : row("FAB", 56, 56, { align: "CENTER", valign: "CENTER", fills: [solid(color)] });
  if (label) f.primaryAxisSizingMode = "AUTO";
  f.cornerRadius = 16;
  f.effects = [shadow(0.28)];
  add(f, iconNode(path, 24, WHITE));
  if (label) add(f, text(label, "button"));
  return f;
}

function badgeIcon(path, color, bg, size) {
  const s = size || 44;
  const inner = Math.round(s * 0.52);
  const box = fixedFrame("Icon Badge", s, s, bg);
  box.cornerRadius = Math.round(s * 0.3);
  at(add(box, iconNode(path, inner, color)), (s - inner) / 2, (s - inner) / 2);
  return box;
}

function signalBars(level, color) {
  const cell = row("Signal Bars", 26, 18, { spacing: 3, align: "MIN", valign: "MAX", fills: [] });
  for (let i = 0; i < 4; i++) {
    const bar = fixedFrame("bar", 4, 5 + i * 3.5, i < level ? color : BORDER);
    bar.cornerRadius = 2;
    add(cell, bar);
  }
  return cell;
}

function chip(label, color) {
  const c = row("Chip / " + label, 0, 24, { padX: 10, align: "CENTER", valign: "CENTER", fills: [solid(color, 0.12)] });
  c.primaryAxisSizingMode = "AUTO";
  c.cornerRadius = 12;
  add(c, text(label, "caption", color));
  return c;
}

function card(w, h, opts) {
  const o = opts || {};
  const c = row(o.name || "Card", w, h, {
    padX: o.padX === undefined ? 14 : o.padX,
    align: "MIN",
    valign: "CENTER",
    spacing: o.spacing === undefined ? 14 : o.spacing,
    fills: [solid(WHITE)],
  });
  c.cornerRadius = o.radius || 14;
  stroke(c, BORDER, 1);
  if (o.effects !== false) c.effects = [shadow(0.08)];
  return c;
}

function divider() {
  return fixedFrame("Divider", CONTENT_W, 1, BORDER);
}

function dialogScaffold(name, cardNode) {
  const s = fixedFrame(name, W, H, null);
  s.clipsContent = true;
  const dim = fixedFrame("Scrim", W, H, "#0B1220");
  dim.fills = [solid("#0B1220", 0.45)];
  add(s, dim);
  add(s, cardNode);
  at(cardNode, (W - cardNode.width) / 2, (H - cardNode.height) / 2);
  return s;
}

function dialogCard(titleText) {
  const card = stack("Dialog", 300, 0, { padX: 20, padY: 20, fills: [solid(WHITE)] });
  card.cornerRadius = 20;
  card.effects = [shadow(0.32)];
  add(card, wrapText(titleText, "dialogTitle", 260));
  return card;
}

function dialogActions(card, confirmLabel, confirmColor) {
  add(card, gap(20));
  const actions = row("Actions", 260, 40, { align: "MAX", valign: "CENTER", spacing: 8, fills: [] });
  const cancel = row("Cancel", 0, 40, { padX: 14, align: "CENTER", valign: "CENTER", fills: [] });
  cancel.primaryAxisSizingMode = "AUTO";
  cancel.cornerRadius = 10;
  add(cancel, text("Cancel", "bodyStrong", MUTED));
  add(actions, cancel);
  const ok = row("Confirm", 0, 40, { padX: 18, align: "CENTER", valign: "CENTER", fills: [solid(confirmColor || PINE)] });
  ok.primaryAxisSizingMode = "AUTO";
  ok.cornerRadius = 10;
  add(ok, text(confirmLabel, "bodyStrong", WHITE));
  add(actions, ok);
  add(card, actions);
  return card;
}

// ---------------------------------------------------------------- map artwork

function mapArtwork(height) {
  const svg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="' + W + '" height="' + height + '" viewBox="0 0 ' + W + " " + height + '">' +
    '<rect width="' + W + '" height="' + height + '" fill="' + MAP_BASE + '"/>' +
    '<path d="M20 520 L150 455 L250 530 L200 ' + (height - 10) + " L40 " + (height - 20) + ' Z" fill="#CFE0C3"/>' +
    '<path d="M-10 110 C 80 150, 95 250, 185 295 C 265 335, 300 410, 380 430" fill="none" stroke="#A9C7E0" stroke-width="12" stroke-linecap="round"/>' +
    '<g stroke="#FFFFFF" stroke-width="9" stroke-linecap="round" fill="none">' +
    '<path d="M-10 195 L120 240 L200 175 L380 205"/>' +
    '<path d="M65 -10 L85 180 L150 300 L160 ' + (height + 10) + '"/>' +
    '<path d="M300 -10 L280 200 L322 380 L300 ' + (height + 10) + '"/>' +
    '<path d="M-10 415 L160 375 L300 425"/>' +
    "</g>" +
    '<g stroke="#D8D2C6" stroke-width="3" stroke-linecap="round" fill="none">' +
    '<path d="M-10 195 L120 240 L200 175 L380 205"/>' +
    '<path d="M65 -10 L85 180 L150 300 L160 ' + (height + 10) + '"/>' +
    "</g>" +
    '<path d="M70 140 L110 210 L160 250 L210 340 L250 400 L232 498" fill="none" stroke="' + PINE + '" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>' +
    '<path d="M272 448 L234 492" fill="none" stroke="' + SOS + '" stroke-width="3" stroke-dasharray="6 6" stroke-linecap="round"/>' +
    '<circle cx="205" cy="335" r="7" fill="' + GREEN + '" stroke="#FFFFFF" stroke-width="2"/>' +
    '<circle cx="150" cy="255" r="7" fill="' + GREEN + '" stroke="#FFFFFF" stroke-width="2"/>' +
    '<circle cx="272" cy="448" r="17" fill="' + BLUE + '" opacity="0.2"/>' +
    '<circle cx="272" cy="448" r="8" fill="' + BLUE + '" stroke="#FFFFFF" stroke-width="2.5"/>' +
    '<g transform="translate(232,498)">' +
    '<path d="M0 0 C -10 -14, -14 -20, -14 -28 A14 14 0 1 1 14 -28 C14 -20, 10 -14, 0 0 Z" fill="' + EMBER + '" stroke="#FFFFFF" stroke-width="2"/>' +
    '<circle cx="0" cy="-28" r="4.5" fill="#FFFFFF"/>' +
    "</g>" +
    "</svg>";
  const n = figma.createNodeFromSvg(svg);
  n.name = "Map Canvas";
  return n;
}

function mapLegend() {
  const f = stack("Map Legend", 200, 6, { padX: 12, padY: 10, fills: [solid(WHITE)] });
  f.counterAxisSizingMode = "FIXED";
  f.primaryAxisSizingMode = "FIXED";
  f.resize(200, 94);
  f.cornerRadius = 12;
  f.effects = [shadow(0.16)];
  const rows = [[PINE, "Active route"], [GREEN, "Peer check-in"], [BLUE, "Your position"], [EMBER, "Destination"]];
  for (let i = 0; i < rows.length; i++) {
    const line = row("Legend Row", 176, 14, { spacing: 8, align: "MIN", valign: "CENTER", fills: [] });
    const dot = fixedFrame("dot", 8, 8, rows[i][0]);
    dot.cornerRadius = 4;
    add(line, dot);
    add(line, text(rows[i][1], "caption", INK));
    add(f, line);
  }
  return f;
}

// ---------------------------------------------------------------- screens

function screenLogin() {
  const s = screenFrame("1 · Login");
  at(add(s, statusBar()), 0, 0);
  at(add(s, appBar("Login")), 0, Y_APPBAR);

  const b = body(H - Y_BODY, 0, { align: "CENTER" });
  const logo = fixedFrame("Logo Mark", 68, 68, PINE);
  logo.cornerRadius = 20;
  logo.effects = [shadow(0.2)];
  at(add(logo, iconNode(ICONS.terrain, 36, WHITE)), 16, 16);
  add(b, logo);
  add(b, gap(20));
  add(b, text("Welcome back", "display"));
  add(b, gap(6));
  const sub = wrapText("Sign in to continue your expedition.", "body", CONTENT_W);
  sub.textAlignHorizontal = "CENTER";
  add(b, sub);
  add(b, gap(28));
  add(b, inputField("Email", "maya@trailtrace.app", { icon: ICONS.email, focused: true }));
  add(b, gap(16));
  add(b, inputField("Password", "••••••••", { icon: ICONS.lock, trailingIcon: ICONS.eye }));
  add(b, gap(24));
  addFull(b, primaryButton("Login"));
  add(b, gap(14));
  const link = row("Register Link", CONTENT_W, 24, { align: "CENTER", valign: "CENTER", spacing: 5, fills: [] });
  add(link, text("Don't have an account?", "body"));
  add(link, text("Register", "bodyStrong", PINE));
  addFull(b, link);
  at(b, 0, Y_BODY);
  add(s, b);
  return s;
}

function screenRegister() {
  const s = screenFrame("2 · Register");
  at(add(s, statusBar()), 0, 0);
  at(add(s, appBar("Register", { back: true })), 0, Y_APPBAR);

  const b = body(H - Y_BODY, 0, { padY: 20, align: "MIN" });
  add(b, text("Create your account", "h1"));
  add(b, gap(6));
  add(b, wrapText("Join an expedition or lead one as a guide.", "body", CONTENT_W));
  add(b, gap(22));
  const fields = stack("Fields", CONTENT_W, 14, { fills: [] });
  addFull(fields, inputField("Full Name", "Maya Sherpa", { icon: ICONS.person }));
  addFull(fields, inputField("Email", "maya@trailtrace.app", { icon: ICONS.email }));
  addFull(fields, inputField("Password", "••••••••", { icon: ICONS.lock }));
  addFull(fields, inputField("Phone Number", "+977 98•• ••••••", { icon: ICONS.phone }));
  addFull(fields, inputField("Role", "Member", { trailing: "chevron" }));
  add(b, fields);
  add(b, gap(26));
  addFull(b, primaryButton("Register"));
  at(b, 0, Y_BODY);
  add(s, b);
  return s;
}

function screenOnboarding() {
  const s = screenFrame("3 · Onboarding");
  at(add(s, statusBar()), 0, 0);
  at(add(s, appBar("Travel Onboarding", { back: true })), 0, Y_APPBAR);

  const b = body(BODY_NAV_H, 0, { padY: 22, align: "MIN" });
  add(b, wrapText("Where would you like to travel?", "h1", CONTENT_W));
  add(b, gap(8));
  add(b, wrapText("Select a region to download offline maps.", "body", CONTENT_W));
  add(b, gap(20));
  const regions = [
    ["Kathmandu Valley", "27.57, 85.16 → 27.80, 85.50", PINE_TINT],
    ["Pokhara", "28.16, 83.90 → 28.30, 84.10", "#E9EEF7"],
    ["Everest Region", "27.70, 86.60 → 28.10, 87.00", "#F3EBE3"],
  ];
  const list = stack("Region List", CONTENT_W, 12, { fills: [] });
  for (let i = 0; i < regions.length; i++) {
    const r = regions[i];
    const c = card(CONTENT_W, 76, { name: "Region / " + r[0] });
    add(c, badgeIcon(ICONS.terrain, PINE, r[2]));
    const col = stack("Text", 172, 3, { fills: [] });
    add(col, wrapText(r[0], "title", 172));
    add(col, wrapText("Bounds: " + r[1], "caption", 172));
    add(c, col);
    add(c, grow());
    add(c, iconNode(ICONS.chevronRight, 22, MUTED));
    addFull(list, c);
  }
  add(b, list);
  add(b, gap(18));
  const note = row("Note", CONTENT_W, 44, { padX: 12, spacing: 10, align: "MIN", valign: "CENTER", fills: [solid(PINE_TINT)] });
  note.cornerRadius = 12;
  add(note, iconNode(ICONS.download, 20, PINE));
  add(note, wrapText("Map data downloads once, then works offline.", "caption", 240, PINE_DARK));
  addFull(b, note);
  at(b, 0, Y_BODY);
  add(s, b);
  at(add(s, bottomNav(0)), 0, Y_NAV);
  return s;
}

function groupCardData() {
  return [
    ["Everest Base Camp Trek", "14-day trek to EBC via Lukla", PINE_TINT],
    ["Annapurna Circuit", "Classic 12-day loop, Thorong La", "#E9EEF7"],
    ["Kathmandu Valley Day Hike", "Weekend ridge walk, easy pace", "#F3EBE3"],
  ];
}

function expeditionsBody(mode) {
  const b = body(BODY_NAV_H, 0, { padY: 20, align: mode === "empty" ? "CENTER" : "MIN" });

  if (mode === "empty") {
    add(b, badgeIcon(ICONS.groups, PINE, PINE_TINT, 72));
    add(b, gap(18));
    add(b, text("No groups found", "h2"));
    add(b, gap(8));
    const sub = wrapText("Create or join one to start tracking your expedition.", "body", 260);
    sub.textAlignHorizontal = "CENTER";
    add(b, sub);
    return b;
  }

  add(b, text("Your expeditions", "caption", MUTED));
  add(b, gap(12));
  const list = stack("Expedition List", CONTENT_W, 12, { fills: [] });
  const groups = groupCardData();
  for (let i = 0; i < groups.length; i++) {
    const g = groups[i];
    const c = card(CONTENT_W, 92, { name: "Expedition / " + g[0] });
    add(c, badgeIcon(ICONS.terrain, PINE, g[2]));
    const col = stack("Text", 172, 4, { fills: [] });
    add(col, wrapText(g[0], "title", 172));
    add(col, wrapText(g[1], "caption", 172));
    add(c, col);
    add(c, grow());
    add(c, iconNode(ICONS.chevronRight, 22, MUTED));
    addFull(list, c);
  }
  add(b, list);
  return b;
}

function screenExpeditions() {
  const s = screenFrame("4 · Expeditions (GUIDE)");
  at(add(s, statusBar()), 0, 0);
  at(add(s, appBar("My Expeditions", { actions: [{ path: ICONS.logout }] })), 0, Y_APPBAR);
  at(add(s, expeditionsBody("list")), 0, Y_BODY);

  const f = fab(ICONS.add, PINE, "New Group");
  add(s, f);
  at(f, W - f.width - 20, Y_NAV - f.height - 20);

  at(add(s, bottomNav(1)), 0, Y_NAV);
  return s;
}

function screenExpeditionsEmpty() {
  const s = screenFrame("5 · Expeditions (MEMBER, empty)");
  at(add(s, statusBar()), 0, 0);
  at(add(s, appBar("My Expeditions", { actions: [{ path: ICONS.logout }] })), 0, Y_APPBAR);
  at(add(s, expeditionsBody("empty")), 0, Y_BODY);

  const f = fab(ICONS.groupAdd, PINE, "Join Group");
  add(s, f);
  at(f, W - f.width - 20, Y_NAV - f.height - 20);

  at(add(s, bottomNav(1)), 0, Y_NAV);
  return s;
}

function screenMap() {
  const s = screenFrame("6 · Map");
  at(add(s, statusBar()), 0, 0);
  at(add(s, appBar("Kathmandu Valley", { actions: [{ path: ICONS.radar }, { path: ICONS.download }] })), 0, Y_APPBAR);

  at(add(s, mapArtwork(BODY_NAV_H)), 0, Y_BODY);
  at(add(s, mapLegend()), 16, Y_BODY + 16);

  const state = row("Status Pill", 0, 34, { padX: 12, spacing: 8, align: "MIN", valign: "CENTER", fills: [solid(SOS)] });
  state.primaryAxisSizingMode = "AUTO";
  state.cornerRadius = 17;
  state.effects = [shadow(0.2)];
  add(state, iconNode(ICONS.warning, 18, WHITE));
  add(state, text("Off path · 62 m left", "caption", WHITE));
  add(s, state);
  at(state, 16, Y_BODY + 122);

  const sos = fab(ICONS.warning, EMBER);
  add(s, sos);
  at(sos, W - sos.width - 20, Y_NAV - 140);

  const track = fab(ICONS.navigation, BLUE);
  add(s, track);
  at(track, W - track.width - 20, Y_NAV - 72);

  at(add(s, bottomNav(0)), 0, Y_NAV);
  return s;
}

function screenRadar() {
  const s = screenFrame("7 · Proximity Radar");
  at(add(s, statusBar()), 0, 0);
  at(add(s, appBar("Proximity Radar", { back: true, actions: [{ path: ICONS.refresh }] })), 0, Y_APPBAR);

  const b = body(BODY_NAV_H, 0, { padY: 20, align: "MIN" });
  const hero = row("Scanner", CONTENT_W, 92, { padX: 16, spacing: 16, align: "MIN", valign: "CENTER", fills: [solid(WHITE)] });
  hero.cornerRadius = 16;
  hero.effects = [shadow(0.1)];
  add(hero, badgeIcon(ICONS.bluetooth, WHITE, PINE, 60));
  const hcol = stack("Text", 188, 4, { fills: [] });
  add(hcol, text("Scanning for devices", "title"));
  add(hcol, wrapText("BLE proximity · listening for beacons", "caption", 188));
  add(hero, hcol);
  addFull(b, hero);

  add(b, gap(20));
  add(b, text("Detected devices", "caption", MUTED));
  add(b, gap(12));

  const devices = [
    ["Lost Hiker Beacon", "-52", "Hot", SOS, 4],
    ["Guide Radio 01", "-68", "Warm", AMBER, 3],
    ["Trail Sensor A7", "-84", "Cold", BLUE, 2],
    ["Unknown Device", "-91", "Cold", BLUE, 1],
  ];
  const tints = {};
  tints[SOS] = "#FDECEC";
  tints[AMBER] = "#FEF3E2";
  tints[BLUE] = "#E9EEF7";
  const list = stack("Device List", CONTENT_W, 10, { fills: [] });
  for (let i = 0; i < devices.length; i++) {
    const d = devices[i];
    const c = card(CONTENT_W, 68, { name: "Device / " + d[0], spacing: 10 });
    add(c, badgeIcon(ICONS.bluetooth, d[3], tints[d[3]], 42));
    const col = stack("Text", 104, 3, { fills: [] });
    add(col, wrapText(d[0], "bodyStrong", 104));
    add(col, wrapText("RSSI: " + d[1], "caption", 104));
    add(c, col);
    add(c, grow());
    add(c, signalBars(d[4], d[3]));
    add(c, chip(d[2], d[3]));
    addFull(list, c);
  }
  add(b, list);
  at(b, 0, Y_BODY);
  add(s, b);

  const f = fab(ICONS.refresh, PINE);
  add(s, f);
  at(f, W - f.width - 20, Y_NAV - f.height - 20);

  at(add(s, bottomNav(2)), 0, Y_NAV);
  return s;
}

function screenCreateGroup() {
  const card = dialogCard("Create New Group");
  add(card, gap(16));
  add(card, inputField("Expedition Name", "", { placeholder: "Annapurna Base Camp", width: 260, focused: true }));
  add(card, gap(12));
  add(card, inputField("Description", "", { placeholder: "6-day lodge trek", width: 260 }));
  dialogActions(card, "Create");
  return dialogScaffold("8 · Dialog — Create Group", card);
}

function screenJoinGroup() {
  const card = dialogCard("Join Group");
  add(card, gap(16));
  add(card, inputField("Invite Code", "TREK-4821", { width: 260, focused: true }));
  dialogActions(card, "Join");
  return dialogScaffold("9 · Dialog — Join Group", card);
}

function screenInviteCode() {
  const card = dialogCard("Group Created!");
  add(card, gap(10));
  add(card, wrapText("Share this code with your members:", "body", 260));
  add(card, gap(14));
  const code = row("Code", 260, 76, { align: "CENTER", valign: "CENTER", fills: [solid(PINE_TINT)] });
  code.cornerRadius = 12;
  add(code, text("TREK-4821", "h1", PINE));
  add(card, code);
  add(card, gap(18));
  const ok = row("OK", 260, 44, { align: "CENTER", valign: "CENTER", fills: [solid(PINE)] });
  ok.cornerRadius = 10;
  add(ok, text("OK", "button"));
  add(card, ok);
  return dialogScaffold("10 · Dialog — Invite Code", card);
}

function screenSosAlert() {
  const card = dialogCard("🚨 SOS Alert!");
  card.children[0].fills = [solid(SOS)];
  add(card, gap(12));
  add(card, wrapText("Maya Sherpa has triggered Rescue Mode.\n\nReason: Trail washed out, unable to proceed.", "body", 260));
  add(card, gap(18));
  const ok = row("Understood", 260, 44, { align: "CENTER", valign: "CENTER", fills: [solid(SOS)] });
  ok.cornerRadius = 10;
  add(ok, text("Understood", "button"));
  add(card, ok);
  return dialogScaffold("11 · Dialog — SOS Alert", card);
}

// ---------------------------------------------------------------- cover & system

function swatchCard(name, hex) {
  const c = stack("Swatch / " + name, 168, 10, { padX: 14, padY: 14, fills: [solid(WHITE)] });
  c.counterAxisSizingMode = "FIXED";
  c.primaryAxisSizingMode = "AUTO";
  c.cornerRadius = 14;
  stroke(c, BORDER, 1);
  const dot = fixedFrame("dot", 40, 40, hex);
  dot.cornerRadius = 12;
  stroke(dot, BORDER, 1);
  add(c, dot);
  add(c, text(name, "bodyStrong"));
  add(c, text(hex, "caption"));
  return c;
}

function cover() {
  const c = stack("Cover", 1200, 0, { padX: 72, padY: 72, fills: [solid(PINE)] });
  c.primaryAxisSizingMode = "FIXED";
  c.counterAxisSizingMode = "FIXED";
  c.resize(1200, 560);
  c.clipsContent = true;

  const mark = fixedFrame("Mark", 72, 72, WHITE);
  mark.cornerRadius = 22;
  at(add(mark, iconNode(ICONS.terrain, 40, PINE)), 16, 16);
  add(c, mark);
  add(c, gap(32));
  add(c, text("Travel & Emergency", "coverTitle"));
  add(c, gap(10));
  add(c, text("Offline trekking companion with rescue radar", "coverSub"));
  add(c, gap(40));

  const meta = row("Meta", 1056, 32, { spacing: 14, align: "MIN", valign: "CENTER", fills: [] });
  const tags = ["6 screens", "4 dialogs", "Android 360 × 800", "Flutter / Material 3"];
  for (let i = 0; i < tags.length; i++) add(meta, chip(tags[i], WHITE));
  add(c, meta);
  add(c, gap(24));
  add(c, text("Generated from TT/lib · TT App Screens plugin", "caption", "#C8D9CE"));
  return c;
}

function designSystem() {
  const d = stack("Design System", 1200, 0, { padX: 56, padY: 56, fills: [solid(SAND)] });
  d.primaryAxisSizingMode = "FIXED";
  d.counterAxisSizingMode = "FIXED";
  d.resize(1200, 900);
  d.clipsContent = true;

  add(d, text("Design System", "display"));
  add(d, gap(6));
  add(d, text("Colors, type scale, spacing and radii used by every screen.", "body"));
  add(d, gap(36));
  add(d, text("Color", "h2"));
  add(d, gap(16));

  const swatches = [
    ["Deep Pine", PINE], ["Pine Dark", PINE_DARK], ["Pine Tint", PINE_TINT],
    ["Sand", SAND], ["Ink", INK], ["Muted", MUTED],
    ["Border", BORDER], ["Ember", EMBER], ["SOS Red", SOS],
    ["Tracking Blue", BLUE], ["Warm Amber", AMBER], ["Safe Green", GREEN],
  ];
  const grid = fixedFrame("Swatches", 1088, 280, null);
  grid.layoutMode = "HORIZONTAL";
  grid.primaryAxisSizingMode = "FIXED";
  grid.counterAxisSizingMode = "FIXED";
  grid.layoutWrap = "WRAP";
  grid.itemSpacing = 16;
  grid.counterAxisSpacing = 16;
  grid.resize(1088, 280);
  for (let i = 0; i < swatches.length; i++) add(grid, swatchCard(swatches[i][0], swatches[i][1]));
  add(d, grid);
  add(d, gap(40));

  const two = row("Lower", 1088, 300, { spacing: 40, align: "MIN", valign: "MIN", fills: [] });
  two.counterAxisSizingMode = "FIXED";
  two.resize(1088, 300);

  const typeCol = stack("Type Scale", 560, 0, { fills: [] });
  add(typeCol, text("Type Scale", "h2"));
  add(typeCol, gap(8));
  const typeRows = [
    ["display", "Display / 28 Bold"], ["h1", "Heading / 24 Bold"], ["h2", "Subhead / 20 SemiBold"],
    ["title", "Title / 16 SemiBold"], ["body", "Body / 14 Regular"], ["caption", "Caption / 12 Regular"],
  ];
  for (let i = 0; i < typeRows.length; i++) {
    const line = row("Type Row", 560, 40, { spacing: 12, align: "MIN", valign: "CENTER", fills: [] });
    add(line, text("Aa", typeRows[i][0]));
    add(line, text(typeRows[i][1], "caption"));
    add(typeCol, line);
    add(typeCol, divider());
  }
  add(two, typeCol);

  const tokenCol = stack("Tokens", 480, 0, { fills: [] });
  add(tokenCol, text("Spacing", "h2"));
  add(tokenCol, gap(8));
  const sp = row("Spacing", 480, 28, { spacing: 10, align: "MIN", valign: "CENTER", fills: [] });
  const nums = [4, 8, 12, 16, 24, 32];
  for (let i = 0; i < nums.length; i++) {
    const c = chip(String(nums[i]), PINE);
    c.fills = [solid(PINE_TINT)];
    c.children[0].fills = [solid(PINE_DARK)];
    add(sp, c);
  }
  add(tokenCol, sp);
  add(tokenCol, gap(20));
  add(tokenCol, text("Radii", "h2"));
  add(tokenCol, gap(8));
  const radii = row("Radii", 480, 56, { spacing: 16, align: "MIN", valign: "CENTER", fills: [] });
  const rs = [8, 12, 16, 20];
  for (let i = 0; i < rs.length; i++) {
    const box = fixedFrame(String(rs[i]), 64, 56, WHITE);
    box.cornerRadius = rs[i];
    stroke(box, PINE, 2);
    add(radii, box);
  }
  add(tokenCol, radii);
  add(two, tokenCol);

  add(d, two);
  return d;
}

// ---------------------------------------------------------------- assembly

async function generate() {
  await resolveFont();
  createStyles();

  let name = "TT App Screens";
  let i = 2;
  while (figma.root.children.some(function (p) { return p.name === name; })) {
    name = "TT App Screens (" + i + ")";
    i += 1;
  }
  const page = figma.createPage();
  page.name = name;
  figma.currentPage = page;

  at(add(page, cover()), 80, 0);
  at(add(page, designSystem()), 80, 640);

  const frames = [
    screenLogin(),
    screenRegister(),
    screenOnboarding(),
    screenExpeditions(),
    screenExpeditionsEmpty(),
    screenMap(),
    screenRadar(),
    screenCreateGroup(),
    screenJoinGroup(),
    screenInviteCode(),
    screenSosAlert(),
  ];

  const cols = 4;
  const gapX = 80;
  const gapY = 120;
  const startX = 80;
  const startY = 1640;

  for (let idx = 0; idx < frames.length; idx++) {
    const fr = frames[idx];
    const caption = text(fr.name, "bodyStrong");
    caption.fills = [solid(INK)];
    const wrap = stack("Frame / " + fr.name, W, 10, { fills: [], align: "CENTER" });
    add(wrap, caption);
    add(wrap, fr);
    add(page, wrap);
    at(wrap, startX + (idx % cols) * (W + gapX), startY + Math.floor(idx / cols) * (H + gapY));
  }

  figma.viewport.scrollAndZoomIntoView([page.children[0], page.children[1]]);
  figma.notify("Created " + (frames.length + 2) + " frames");
  figma.ui.postMessage({ type: "done", count: frames.length + 2, page: page.name });
}

figma.showUI(__html__, { width: 280, height: 170 });

figma.ui.onmessage = async function (msg) {
  if (!msg || msg.type !== "generate") return;
  try {
    await generate();
  } catch (err) {
    figma.notify("Generation failed: " + err.message, { error: true });
    figma.ui.postMessage({ type: "error", message: err.message });
  }
};