module.exports = function (api) {
  api.cache(true);
  return {
    presets: [["babel-preset-expo", { jsxImportSource: "nativewind" }], "nativewind/babel"],
    plugins: [
      // Reanimated's plugin has to be last. Anything after it silently breaks
      // worklets, which is how the background location task fails.
      "react-native-reanimated/plugin",
    ],
  };
};
