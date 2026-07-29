/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./app/**/*.{ts,tsx}", "./src/**/*.{ts,tsx}"],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      // The same tokens as the web app, docs/prd/03-web.md §1.1. A guard and an
      // operations manager looking at the same status must see the same colour.
      colors: {
        primary: { DEFAULT: "#0B5FFF", hover: "#0A54E0", subtle: "#EFF5FF" },
        accent: "#00C2A8",
        success: "#16A34A",
        warning: "#F59E0B",
        danger: "#DC2626",
        info: "#0EA5E9",
        present: "#16A34A",
        absent: "#DC2626",
        halfday: "#F59E0B",
        leave: "#8B5CF6",
        weekoff: "#64748B",
        holiday: "#0EA5E9",
        bg: "#FAFAFA",
        surface: "#FFFFFF",
        border: "#E4E4E7",
        text: "#18181B",
        muted: "#71717A",
      },
    },
  },
  plugins: [],
};
