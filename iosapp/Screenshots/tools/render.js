#!/usr/bin/env node

const puppeteer = require("puppeteer-core");
const { execSync, spawn } = require("child_process");
const fs = require("fs");
const path = require("path");

const PROJECT_ROOT = path.resolve(__dirname, "../..");
const SCREENSHOTS_DIR = path.join(PROJECT_ROOT, "Screenshots");
const RAW_DIR = path.join(SCREENSHOTS_DIR, "6.7");
const OUTPUT_DIR = path.join(SCREENSHOTS_DIR, "AppStore");
const TEMPLATE_PATH = path.join(__dirname, "templates", "base.html");
const BUNDLE_ID = "com.kevinbuckley.travelplanner";
const SIMULATOR_NAME = "iPhone 17 Pro";
const CHROME_PATH = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

// App Store accepted dimensions for 6.5" display (1284×2778 or 1242×2688)
const OUTPUT_WIDTH = 1284;
const OUTPUT_HEIGHT = 2778;

// Screenshot definitions matching the existing prompts
const SCREENSHOTS = [
  {
    name: "01_trips",
    tabArg: "trips",
    headline: "Plan Every Detail",
    subheadline: "Organize trips, stops, and bookings in one place",
    gradientTop: "#0A2463",
    gradientBottom: "#FF6B35",
    glowColor: "rgba(255, 107, 53, 0.3)",
    rotateY: -3,
  },
  {
    name: "02_map",
    tabArg: "map",
    headline: "See Your Route Unfold",
    subheadline: "Interactive maps with every stop plotted beautifully",
    gradientTop: "#065F46",
    gradientBottom: "#38BDF8",
    glowColor: "rgba(56, 189, 248, 0.3)",
    rotateY: 3,
  },
  {
    name: "03_wishlist",
    tabArg: "wishlist",
    headline: "Save Your Dream Spots",
    subheadline: "Build a wishlist of places for every city you explore",
    gradientTop: "#F59E0B",
    gradientBottom: "#FDA4AF",
    glowColor: "rgba(253, 164, 175, 0.3)",
    rotateY: -1,
  },
  {
    name: "04_tripdetail",
    tabArg: "tripdetail",
    headline: "All Bookings, One Tap",
    subheadline: "Flights, hotels, and confirmations beautifully organized",
    gradientTop: "#4C1D95",
    gradientBottom: "#1D4ED8",
    glowColor: "rgba(29, 78, 216, 0.3)",
    rotateY: 2,
  },
];

function log(msg) {
  console.log(`[screenshots] ${msg}`);
}

function run(cmd, opts = {}) {
  log(`  $ ${cmd}`);
  return execSync(cmd, { encoding: "utf-8", stdio: "pipe", ...opts }).trim();
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

// ── Simulator management ──

function getBootedSimulator() {
  try {
    const output = run("xcrun simctl list devices booted -j");
    const data = JSON.parse(output);
    for (const runtime of Object.values(data.devices)) {
      for (const device of runtime) {
        if (device.state === "Booted") return device;
      }
    }
  } catch {}
  return null;
}

function bootSimulator() {
  let device = getBootedSimulator();
  if (device) {
    log(`Simulator already booted: ${device.name} (${device.udid})`);
    return device.udid;
  }

  log(`Booting ${SIMULATOR_NAME}...`);
  run(`xcrun simctl boot "${SIMULATOR_NAME}"`);
  run("open -a Simulator");

  // Wait for boot
  for (let i = 0; i < 30; i++) {
    device = getBootedSimulator();
    if (device) {
      log(`Simulator booted: ${device.name}`);
      return device.udid;
    }
    execSync("sleep 1");
  }
  throw new Error("Simulator failed to boot");
}

// ── App build & install ──

function buildApp() {
  log("Building TripWit...");
  run(
    `xcodebuild build -project "${PROJECT_ROOT}/TripWit.xcodeproj" -scheme TripWit -destination 'platform=iOS Simulator,name=${SIMULATOR_NAME}' -quiet 2>&1`,
    { timeout: 300000 }
  );
  log("Build complete.");
}

// ── Screenshot capture ──

async function captureRawScreenshots(udid) {
  fs.mkdirSync(RAW_DIR, { recursive: true });

  for (const shot of SCREENSHOTS) {
    log(`Capturing ${shot.name} (tab: ${shot.tabArg})...`);

    // Terminate any running instance
    try { run(`xcrun simctl terminate ${udid} ${BUNDLE_ID}`); } catch {}
    await sleep(500);

    // Launch to specific tab
    run(`xcrun simctl launch ${udid} ${BUNDLE_ID} -screenshotTab ${shot.tabArg}`);

    // Wait for the app to settle — map needs extra time
    const waitTime = shot.tabArg === "map" ? 5000 : 3000;
    await sleep(waitTime);

    // Capture
    const rawPath = path.join(RAW_DIR, `${shot.name}_raw.png`);
    run(`xcrun simctl io ${udid} screenshot "${rawPath}"`);
    log(`  Saved raw: ${rawPath}`);
  }

  // Terminate app when done
  try { run(`xcrun simctl terminate ${udid} ${BUNDLE_ID}`); } catch {}
}

// ── HTML rendering ──

function buildHTML(shot) {
  let html = fs.readFileSync(TEMPLATE_PATH, "utf-8");
  const rawPath = path.join(RAW_DIR, `${shot.name}_raw.png`);

  // Use file:// URL for the screenshot image
  const imgUrl = `file://${rawPath}`;

  html = html.replace(/\{\{HEADLINE\}\}/g, shot.headline);
  html = html.replace(/\{\{SUBHEADLINE\}\}/g, shot.subheadline);
  html = html.replace(/\{\{GRADIENT_TOP\}\}/g, shot.gradientTop);
  html = html.replace(/\{\{GRADIENT_BOTTOM\}\}/g, shot.gradientBottom);
  html = html.replace(/\{\{GLOW_COLOR\}\}/g, shot.glowColor);
  html = html.replace(/\{\{ROTATE_Y\}\}/g, String(shot.rotateY));
  html = html.replace(/\{\{SCREENSHOT_PATH\}\}/g, imgUrl);

  return html;
}

async function renderAppStoreScreenshots() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  log("Launching Chrome for rendering...");
  const browser = await puppeteer.launch({
    executablePath: CHROME_PATH,
    headless: "new",
    args: [
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--allow-file-access-from-files",
    ],
  });

  const page = await browser.newPage();

  // Set viewport to exact App Store 6.5" dimensions
  await page.setViewport({
    width: OUTPUT_WIDTH,
    height: OUTPUT_HEIGHT,
    deviceScaleFactor: 1,
  });

  for (const shot of SCREENSHOTS) {
    log(`Rendering ${shot.name}...`);

    const html = buildHTML(shot);

    // Write temp HTML (Puppeteer needs file:// for local images)
    const tmpHtml = path.join(__dirname, `_tmp_${shot.name}.html`);
    fs.writeFileSync(tmpHtml, html);

    await page.goto(`file://${tmpHtml}`, { waitUntil: "networkidle0" });
    await page.waitForSelector("img");

    // Small delay to ensure image is rendered
    await sleep(500);

    const outputPath = path.join(OUTPUT_DIR, `${shot.name}.png`);
    await page.screenshot({
      path: outputPath,
      type: "png",
      clip: { x: 0, y: 0, width: OUTPUT_WIDTH, height: OUTPUT_HEIGHT },
    });

    // Clean up temp file
    fs.unlinkSync(tmpHtml);

    // Verify dimensions
    const dims = run(`sips -g pixelWidth -g pixelHeight "${outputPath}"`);
    log(`  Output: ${outputPath}`);
    log(`  ${dims.split("\n").slice(1).join(", ")}`);
  }

  await browser.close();
  log("Done! All screenshots saved to Screenshots/AppStore/");
}

// ── Main ──

async function main() {
  const args = process.argv.slice(2);
  const skipBuild = args.includes("--skip-build");
  const renderOnly = args.includes("--render-only");

  log("=== TripWit App Store Screenshot Generator ===\n");

  if (!renderOnly) {
    // Step 1: Boot simulator
    const udid = bootSimulator();

    // Step 2: Build app (unless skipped)
    if (!skipBuild) {
      buildApp();
    } else {
      log("Skipping build (--skip-build).");
    }

    // Step 3: Capture raw screenshots
    await captureRawScreenshots(udid);
  } else {
    log("Render-only mode — using existing raw screenshots.");
  }

  // Step 4: Render App Store images
  await renderAppStoreScreenshots();

  log("\n=== Complete! ===");
  log(`Screenshots saved to: ${OUTPUT_DIR}`);

  // List output files
  const files = fs.readdirSync(OUTPUT_DIR).filter((f) => f.endsWith(".png"));
  for (const f of files) {
    const dims = run(`sips -g pixelWidth -g pixelHeight "${path.join(OUTPUT_DIR, f)}"`);
    const w = dims.match(/pixelWidth:\s*(\d+)/)?.[1];
    const h = dims.match(/pixelHeight:\s*(\d+)/)?.[1];
    log(`  ${f}: ${w}×${h}`);
  }
}

main().catch((err) => {
  console.error(`\n[screenshots] ERROR: ${err.message}`);
  process.exit(1);
});
