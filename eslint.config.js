// ESLint flat config: the recommended JavaScript and TypeScript rules, nothing exotic,
// so a person and an agent get the same feedback on every change.
import js from "@eslint/js";
import { defineConfig } from "eslint/config";
import globals from "globals";
import tseslint from "typescript-eslint";

export default defineConfig(
  { ignores: ["dist/", "coverage/", "node_modules/"] },
  js.configs.recommended,
  tseslint.configs.recommended,
  {
    languageOptions: { globals: globals.node },
    rules: {
      // An unused variable is usually a half-finished change. Prefix with _ to keep one on purpose.
      "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
    },
  },
);
