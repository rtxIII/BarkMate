// Ambient declarations for wrangler Text-module imports
// (configured in wrangler.jsonc → rules: [{ type: "Text", globs: ["scripts/install.sh.txt", "**/*.md"] }])

declare module '*.txt' {
  const content: string;
  export default content;
}

declare module '*.md' {
  const content: string;
  export default content;
}
