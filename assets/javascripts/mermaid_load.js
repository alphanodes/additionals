$(function() {
  if (globalThis !== undefined && globalThis.mermaidTheme !== undefined) {
    var mermaidTheme = globalThis.mermaidTheme;
  } else {
    var mermaidTheme = 'default';
  }
  if (globalThis !== undefined && globalThis.mermaidThemeVariables !== undefined) {
    var mermaidThemeVariables = globalThis.mermaidThemeVariables;
  } else {
    var mermaidThemeVariables = { 'fontSize': '12px' };
  }

  mermaid.initialize({
    startOnLoad: true,
    maxTextSize: 500000,
    flowchart:{
      useMaxWidth: false
    },
    theme: mermaidTheme,
    themeVariables: mermaidThemeVariables });
});
