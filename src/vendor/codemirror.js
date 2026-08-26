/**
 * CodeMirror 6 bundle for the AlphaNodes plugin family.
 *
 * CodeMirror is published as ES modules only, so it cannot be dropped into
 * assets/javascripts/vendor as a downloaded file like chart.js or select2.
 * This entry point is bundled by esbuild (`yarn build`) into
 * assets/javascripts/vendor/codemirror.js and exposes what a Redmine plugin
 * needs as window.CodeMirror6.
 *
 * Kept deliberately small: importing @codemirror/lang-markdown as a whole
 * pulls in the HTML, JavaScript and CSS languages plus autocomplete to
 * highlight embedded code - roughly 40 percent extra for something no plugin
 * here needs. The markdown language below uses the same parser without those,
 * and the two markup commands tree-shake cleanly (measured: +4 KB).
 *
 * The enabled parser extensions mirror Redmine's PIPELINE_CONFIG
 * (lib/redmine/wiki_formatting/common_mark/formatter.rb): GFM covers table,
 * strikethrough, tasklist and autolink. Footnotes and alerts are rendered by
 * the server but have no parser extension here, they stay unhighlighted.
 *
 * License: MIT (CodeMirror, Lezer).
 */
import { EditorState } from '@codemirror/state';
import { EditorView, drawSelection, highlightSpecialChars, keymap, placeholder } from '@codemirror/view';
import { defaultKeymap, history, historyKeymap, indentLess, indentMore } from '@codemirror/commands';
import {
  HighlightStyle,
  Language,
  defineLanguageFacet,
  indentOnInput,
  languageDataProp,
  syntaxHighlighting,
} from '@codemirror/language';
import { deleteMarkupBackward, insertNewlineContinueMarkup } from '@codemirror/lang-markdown';
import { GFM, parser } from '@lezer/markdown';
import { tags } from '@lezer/highlight';

const markdownFacet = defineLanguageFacet({ commentTokens: { block: { open: '<!--', close: '-->' } } });

const markdownLanguage = new Language(
  markdownFacet,
  parser.configure([GFM, { props: [languageDataProp.add({ Document: markdownFacet })] }]),
  [],
  'markdown',
);

window.CodeMirror6 = {
  EditorState,
  EditorView,
  HighlightStyle,
  defaultKeymap,
  deleteMarkupBackward,
  drawSelection,
  highlightSpecialChars,
  history,
  historyKeymap,
  indentLess,
  indentMore,
  indentOnInput,
  insertNewlineContinueMarkup,
  keymap,
  markdownLanguage,
  placeholder,
  syntaxHighlighting,
  tags,
};
