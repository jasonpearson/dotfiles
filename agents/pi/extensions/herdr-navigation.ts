import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const directions = {
  "ctrl+h": "left",
  "ctrl+j": "down",
  "ctrl+k": "up",
  "ctrl+l": "right",
} as const;

export default function (pi: ExtensionAPI) {
  for (const [shortcut, direction] of Object.entries(directions)) {
    pi.registerShortcut(shortcut, {
      description: `Focus Herdr pane ${direction}`,
      handler: async (ctx) => {
        if (!process.env.HERDR_PANE_ID || process.env.TMUX) {
          return;
        }

        await pi.exec("herdr", ["pane", "focus", "--current", "--direction", direction], {
          timeout: 1000,
        });
      },
    });
  }
}
