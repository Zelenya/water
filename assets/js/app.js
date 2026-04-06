// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { hooks as colocatedHooks } from "phoenix-colocated/water";
import {
  BedSingle,
  Calendar1,
  Cloud,
  CloudDrizzle,
  CloudRain,
  CloudSun,
  createElement as createLucideElement,
  Droplets,
  Flag,
  Haze,
  LayoutGrid,
  Shovel,
  Sprout,
  Sun,
  Trees,
} from "lucide";
import topbar from "../vendor/topbar";

const themeStorageKey = "phx:theme";
const gardenLucideIcons = {
  "bed-single": BedSingle,
  "calendar-1": Calendar1,
  cloud: Cloud,
  "cloud-drizzle": CloudDrizzle,
  "cloud-rain": CloudRain,
  "cloud-sun": CloudSun,
  droplets: Droplets,
  flag: Flag,
  haze: Haze,
  "layout-grid": LayoutGrid,
  shovel: Shovel,
  sprout: Sprout,
  sun: Sun,
  trees: Trees,
};

const renderGardenLucideIcons = (root) => {
  root.querySelectorAll("[data-lucide-icon]").forEach((node) => {
    const icon = gardenLucideIcons[node.dataset.lucideIcon];
    if (!icon) return;

    const svg = createLucideElement(icon, {
      class: "garden-lucide-svg",
      "stroke-width": node.dataset.lucideStrokeWidth || "1.9",
      "absolute-stroke-width": "true",
      "aria-hidden": "true",
    });

    if (node.firstElementChild?.outerHTML !== svg.outerHTML) {
      node.replaceChildren(svg);
    }
  });
};

const GardenLucideIcons = {
  mounted() {
    renderGardenLucideIcons(this.el);
  },

  updated() {
    renderGardenLucideIcons(this.el);
  },
};

const geolocationFailureReason = (error) => {
  switch (error?.code) {
    case 1:
      return "denied";
    case 2:
      return "unavailable";
    case 3:
      return "timeout";
    default:
      return "unavailable";
  }
};

const GardenWeatherLocation = {
  mounted() {
    if (!("geolocation" in navigator)) {
      this.pushEvent("weather_location_unavailable", { reason: "unsupported" });
      return;
    }

    // The weather cards are a bonus, not required for the rest of the board.
    // So, we use a short timeout and accept coarse cached positions.
    navigator.geolocation.getCurrentPosition(
      ({ coords }) => {
        this.pushEvent("weather_location_ready", {
          latitude: coords.latitude,
          longitude: coords.longitude,
        });
      },
      (error) => {
        this.pushEvent("weather_location_unavailable", {
          reason: geolocationFailureReason(error),
        });
      },
      {
        enableHighAccuracy: false,
        timeout: 5000,
        maximumAge: 600000,
      },
    );
  },
};

const applyTheme = (theme) => {
  if (theme === "system") {
    localStorage.removeItem(themeStorageKey);
    document.documentElement.removeAttribute("data-theme");
  } else {
    localStorage.setItem(themeStorageKey, theme);
    document.documentElement.setAttribute("data-theme", theme);
  }
};

if (!document.documentElement.hasAttribute("data-theme")) {
  applyTheme(localStorage.getItem(themeStorageKey) || "system");
}

window.addEventListener("storage", (event) => {
  if (event.key === themeStorageKey) {
    applyTheme(event.newValue || "system");
  }
});

window.addEventListener("phx:set-theme", (event) => {
  applyTheme(event.target.dataset.phxTheme);
});

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { GardenLucideIcons, GardenWeatherLocation, ...colocatedHooks },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener(
    "phx:live_reload:attached",
    ({ detail: reloader }) => {
      // Enable server log streaming to client.
      // Disable with reloader.disableServerLogs()
      reloader.enableServerLogs();

      // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
      //
      //   * click with "c" key pressed to open at caller location
      //   * click with "d" key pressed to open at function component definition location
      let keyDown;
      window.addEventListener("keydown", (e) => (keyDown = e.key));
      window.addEventListener("keyup", (_e) => (keyDown = null));
      window.addEventListener(
        "click",
        (e) => {
          if (keyDown === "c") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtCaller(e.target);
          } else if (keyDown === "d") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtDef(e.target);
          }
        },
        true,
      );

      window.liveReloader = reloader;
    },
  );
}
