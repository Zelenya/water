const launcherOpen = () =>
  Boolean(document.getElementById("garden-command-launcher"));

const launcherEnabled = () => {
  const shell = document.getElementById("garden-shell");
  return shell?.dataset.commandLauncherEnabled === "true";
};

// Shortcut gating for the command launcher
const shouldCaptureLauncherShortcut = (event) => {
  const cmdK =
    (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k";

  if (!cmdK) {
    return false;
  }

  if (!launcherOpen() && !launcherEnabled()) {
    return false;
  }

  return !event.defaultPrevented;
};

const focusLauncherInput = (root) => {
  const input = root.querySelector("#garden-command-launcher-input");
  if (input && document.activeElement !== input) {
    input.focus();
    input.setSelectionRange(input.value.length, input.value.length);
  }
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

export const createGardenHooks = ({ renderGardenLucideIcons }) => ({
  // I really wanted a plant icon from lucide. Might need to revisit this.
  GardenLucideIcons: {
    mounted() {
      renderGardenLucideIcons(this.el);
    },

    updated() {
      renderGardenLucideIcons(this.el);
    },
  },

  // Translates browser key chords into LiveView events to toggle the launcher
  GardenShell: {
    mounted() {
      renderGardenLucideIcons(this.el);

      this.handleLauncherShortcut = (event) => {
        if (!shouldCaptureLauncherShortcut(event)) return;

        event.preventDefault();
        this.pushEvent("toggle_command_launcher", {});
      };

      window.addEventListener("keydown", this.handleLauncherShortcut);
    },

    updated() {
      renderGardenLucideIcons(this.el);
    },

    destroyed() {
      window.removeEventListener("keydown", this.handleLauncherShortcut);
    },
  },

  // Maps focus and keyboard interactions into LiveView events
  GardenCommandLauncher: {
    mounted() {
      this.queueFocusInput();
      this.handleKeydown = (event) => {
        if (event.defaultPrevented) return;

        switch (event.key) {
          case "ArrowDown":
            event.preventDefault();
            event.stopPropagation();
            this.pushEvent("move_command_launcher_selection", { delta: "1" });
            break;
          case "ArrowUp":
            event.preventDefault();
            event.stopPropagation();
            this.pushEvent("move_command_launcher_selection", { delta: "-1" });
            break;
          case "Enter":
            // Skip if the event target is already a button (don't double-handle)
            if (event.target?.tagName === "BUTTON") return;
            event.preventDefault();
            event.stopPropagation();
            this.pushEvent("submit_command_launcher_selection", {});
            break;
          case "Escape":
            event.preventDefault();
            event.stopPropagation();
            this.pushEvent("close_command_launcher", {});
            break;
          default:
            break;
        }
      };

      this.el.addEventListener("keydown", this.handleKeydown);
    },

    updated() {
      this.queueFocusInput();
    },

    destroyed() {
      this.clearFocusTimers();
      this.el.removeEventListener("keydown", this.handleKeydown);
    },

    clearFocusTimers() {
      if (this.focusAnimationFrame) {
        cancelAnimationFrame(this.focusAnimationFrame);
        this.focusAnimationFrame = null;
      }

      if (this.focusTimeout) {
        clearTimeout(this.focusTimeout);
        this.focusTimeout = null;
      }
    },

    queueFocusInput() {
      this.clearFocusTimers();

      // DaisyUI modal transitions can briefly win the focus race,
      // so we retry once after the current frame settles.
      // Make the launcher feel active immediately after opening.
      this.focusAnimationFrame = requestAnimationFrame(() => {
        focusLauncherInput(this.el);
        this.focusTimeout = setTimeout(() => focusLauncherInput(this.el), 30);
      });
    },
  },

  // Gets geolocation for the weather forecast
  GardenWeatherLocation: {
    mounted() {
      if (!("geolocation" in navigator)) {
        this.pushEvent("weather_location_unavailable", {
          reason: "unsupported",
        });
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
  },
});
