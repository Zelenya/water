import Sortable from "sortablejs";

const mobileViewportQuery = "(max-width: 767px)";

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

const careSortableSectionPayload = (sectionEl) => ({
  section_id: sectionEl.dataset.careSectionId,
  item_ids: Array.from(sectionEl.querySelectorAll("[data-care-item-id]")).map(
    (itemEl) => itemEl.dataset.careItemId,
  ),
});

const uniqueCareSortableSections = (...sectionEls) => {
  const seen = new Set();

  return sectionEls.filter((sectionEl) => {
    if (!sectionEl?.dataset?.careSectionId) return false;
    if (seen.has(sectionEl.dataset.careSectionId)) return false;

    seen.add(sectionEl.dataset.careSectionId);
    return true;
  });
};

const sectionSortablePayload = (boardEl) =>
  Array.from(boardEl.querySelectorAll("[data-garden-section-id]")).map(
    (sectionEl) => sectionEl.dataset.gardenSectionId,
  );

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
      this.mobileViewport = window.matchMedia(mobileViewportQuery);
      this.pushMobileViewportState = () => {
        this.pushEvent("garden_viewport_changed", {
          mobile: this.mobileViewport.matches,
        });
      };

      this.handleLauncherShortcut = (event) => {
        const cmdK =
          (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k";

        if (!cmdK || event.defaultPrevented) return;

        const launcherOpen = Boolean(
          document.getElementById("garden-command-launcher"),
        );
        const launcherEnabled =
          this.el.dataset.commandLauncherEnabled === "true";

        if (!launcherOpen && !launcherEnabled) return;

        event.preventDefault();
        this.pushEvent("toggle_command_launcher", {});
      };

      window.addEventListener("keydown", this.handleLauncherShortcut);
      this.mobileViewport.addEventListener(
        "change",
        this.pushMobileViewportState,
      );
      this.pushMobileViewportState();
    },

    updated() {
      renderGardenLucideIcons(this.el);
    },

    destroyed() {
      window.removeEventListener("keydown", this.handleLauncherShortcut);
      this.mobileViewport.removeEventListener(
        "change",
        this.pushMobileViewportState,
      );
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

  // Connects care item lists so items can be reordered or moved between sections.
  GardenCareSortable: {
    mounted() {
      this.initializeSortable();
    },

    updated() {
      this.destroySortable();
      this.initializeSortable();
    },

    destroyed() {
      this.destroySortable();
    },

    initializeSortable() {
      if (this.el.dataset.sortableEnabled !== "true") return;

      this.sortable = Sortable.create(this.el, {
        group: "garden-care-items",
        animation: 180,
        draggable: ".garden-care-sortable-item",
        handle: ".garden-care-drag-handle",
        filter: ".garden-care-sortable-empty",
        ghostClass: "garden-care-drag-ghost",
        chosenClass: "garden-care-drag-chosen",
        dragClass: "garden-care-drag-active",
        onEnd: (event) => {
          if (!event.item?.dataset?.careItemId) return;
          if (event.from === event.to && event.oldIndex === event.newIndex)
            return;

          this.pushEvent("reposition_care_item", {
            item_id: event.item.dataset.careItemId,
            sections: uniqueCareSortableSections(event.from, event.to).map(
              careSortableSectionPayload,
            ),
          });
        },
      });
    },

    destroySortable() {
      if (!this.sortable) return;

      this.sortable.destroy();
      this.sortable = null;
    },
  },

  // Connects board sections so whole sections can be reordered.
  GardenSectionSortable: {
    mounted() {
      this.initializeSortable();
    },

    updated() {
      this.destroySortable();
      this.initializeSortable();
    },

    destroyed() {
      this.destroySortable();
    },

    initializeSortable() {
      if (this.el.dataset.sortableEnabled !== "true") return;

      this.sortable = Sortable.create(this.el, {
        animation: 180,
        draggable: ".garden-section-sortable-item",
        handle: ".garden-section-drag-handle",
        ghostClass: "garden-section-drag-ghost",
        chosenClass: "garden-section-drag-chosen",
        dragClass: "garden-section-drag-active",
        onEnd: (event) => {
          if (!event.item?.dataset?.gardenSectionId) return;
          if (event.oldIndex === event.newIndex) return;

          this.pushEvent("reposition_section", {
            section_id: event.item.dataset.gardenSectionId,
            section_ids: sectionSortablePayload(this.el),
          });
        },
      });
    },

    destroySortable() {
      if (!this.sortable) return;

      this.sortable.destroy();
      this.sortable = null;
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
