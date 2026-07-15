"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import {
  Bold,
  Italic,
  Underline,
  Heading2,
  Heading3,
  List,
  ListOrdered,
  Quote,
  Link as LinkIcon,
  Unlink,
  RemoveFormatting,
} from "lucide-react";

interface RichTextEditorProps {
  /** HTML string */
  value: string;
  onChange: (html: string) => void;
  disabled?: boolean;
  dir?: "ltr" | "rtl";
  placeholder?: string;
  minHeight?: number;
}

type Cmd = { command: string; value?: string };

/**
 * Lightweight contentEditable WYSIWYG editor. Stores and emits raw HTML so the
 * value can be rendered directly in the apps. When `disabled`, it renders the
 * HTML as a clean read-only preview instead of an editable surface.
 */
export default function RichTextEditor({
  value,
  onChange,
  disabled = false,
  dir = "ltr",
  placeholder,
  minHeight = 160,
}: RichTextEditorProps) {
  const ref = useRef<HTMLDivElement>(null);
  const [active, setActive] = useState<Record<string, boolean>>({});

  // Sync external value -> DOM only when it represents a real change. We compare
  // the *normalized* current DOM against the value: while typing they match (so
  // the caret never resets), but on load / cancel / tab switch / re-entering edit
  // they differ and we repaint. `disabled` is a dep because toggling edit mode
  // mounts a fresh (empty) editable div that must be populated.
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const v = value ?? "";
    if (normalizeHtml(el.innerHTML) !== v) {
      el.innerHTML = v;
    }
  }, [value, disabled]);

  // Emit clean, semantic HTML (<strong>/<em>/<p>) rather than the browser's
  // default contentEditable markup (<b>/<i>/<div>), so what we store and send
  // to the API is the normalized HTML shown in the example.
  const emit = useCallback(() => {
    const el = ref.current;
    if (!el) return;
    onChange(normalizeHtml(el.innerHTML));
  }, [onChange]);

  const refreshActive = useCallback(() => {
    if (disabled) return;
    try {
      setActive({
        bold: document.queryCommandState("bold"),
        italic: document.queryCommandState("italic"),
        underline: document.queryCommandState("underline"),
        insertUnorderedList: document.queryCommandState("insertUnorderedList"),
        insertOrderedList: document.queryCommandState("insertOrderedList"),
      });
    } catch {
      /* queryCommandState can throw if no selection — ignore */
    }
  }, [disabled]);

  // Pressing Enter should create <p> paragraphs, and inline styles should use
  // tags (<b>/<i>) not CSS — both keep the emitted HTML clean.
  const setupFormatting = useCallback(() => {
    try {
      document.execCommand("defaultParagraphSeparator", false, "p");
      document.execCommand("styleWithCSS", false, "false");
    } catch {
      /* not supported — ignore */
    }
  }, []);

  const exec = useCallback(
    ({ command, value: val }: Cmd) => {
      const el = ref.current;
      if (!el) return;
      el.focus();
      setupFormatting();
      document.execCommand(command, false, val);
      emit();
      refreshActive();
    },
    [emit, refreshActive, setupFormatting]
  );

  const setBlock = (tag: string) => exec({ command: "formatBlock", value: tag });

  const addLink = () => {
    const url = window.prompt("Enter URL", "https://");
    if (!url) return;
    exec({ command: "createLink", value: url });
  };

  if (disabled) {
    return (
      <div
        dir={dir}
        className="rte-content min-h-[3rem] rounded-xl border border-gray-200 bg-gray-50/60 px-3.5 py-3 text-gray-600"
        style={{ minHeight }}
        data-placeholder={placeholder}
        dangerouslySetInnerHTML={{ __html: value || "" }}
      />
    );
  }

  return (
    <div className="overflow-hidden rounded-xl border border-gray-300 bg-white focus-within:border-indigo-500 focus-within:ring-2 focus-within:ring-indigo-100 transition-all">
      <div className="flex flex-wrap items-center gap-0.5 border-b border-gray-200 bg-gray-50/80 px-1.5 py-1">
        <ToolbarBtn label="Bold" active={active.bold} onClick={() => exec({ command: "bold" })}>
          <Bold size={15} />
        </ToolbarBtn>
        <ToolbarBtn label="Italic" active={active.italic} onClick={() => exec({ command: "italic" })}>
          <Italic size={15} />
        </ToolbarBtn>
        <ToolbarBtn
          label="Underline"
          active={active.underline}
          onClick={() => exec({ command: "underline" })}
        >
          <Underline size={15} />
        </ToolbarBtn>

        <Divider />

        <ToolbarBtn label="Heading" onClick={() => setBlock("H2")}>
          <Heading2 size={15} />
        </ToolbarBtn>
        <ToolbarBtn label="Subheading" onClick={() => setBlock("H3")}>
          <Heading3 size={15} />
        </ToolbarBtn>
        <ToolbarBtn label="Quote" onClick={() => setBlock("BLOCKQUOTE")}>
          <Quote size={15} />
        </ToolbarBtn>

        <Divider />

        <ToolbarBtn
          label="Bullet list"
          active={active.insertUnorderedList}
          onClick={() => exec({ command: "insertUnorderedList" })}
        >
          <List size={15} />
        </ToolbarBtn>
        <ToolbarBtn
          label="Numbered list"
          active={active.insertOrderedList}
          onClick={() => exec({ command: "insertOrderedList" })}
        >
          <ListOrdered size={15} />
        </ToolbarBtn>

        <Divider />

        <ToolbarBtn label="Add link" onClick={addLink}>
          <LinkIcon size={15} />
        </ToolbarBtn>
        <ToolbarBtn label="Remove link" onClick={() => exec({ command: "unlink" })}>
          <Unlink size={15} />
        </ToolbarBtn>
        <ToolbarBtn label="Clear formatting" onClick={() => exec({ command: "removeFormat" })}>
          <RemoveFormatting size={15} />
        </ToolbarBtn>
      </div>

      <div
        ref={ref}
        dir={dir}
        contentEditable
        suppressContentEditableWarning
        role="textbox"
        aria-multiline="true"
        data-placeholder={placeholder}
        onInput={emit}
        onBlur={emit}
        onKeyUp={refreshActive}
        onMouseUp={refreshActive}
        onFocus={() => {
          setupFormatting();
          refreshActive();
        }}
        className="rte-content px-3.5 py-3"
        style={{ minHeight }}
      />
    </div>
  );
}

function ToolbarBtn({
  children,
  onClick,
  label,
  active,
}: {
  children: React.ReactNode;
  onClick: () => void;
  label: string;
  active?: boolean;
}) {
  return (
    <button
      type="button"
      title={label}
      aria-label={label}
      aria-pressed={active}
      // Keep the editor selection when clicking a toolbar button.
      onMouseDown={(e) => e.preventDefault()}
      onClick={onClick}
      className={`flex h-7 w-7 items-center justify-center rounded-md transition-colors ${
        active
          ? "bg-indigo-100 text-indigo-700"
          : "text-gray-500 hover:bg-gray-200/70 hover:text-gray-800"
      }`}
    >
      {children}
    </button>
  );
}

function Divider() {
  return <span className="mx-1 h-5 w-px bg-gray-200" />;
}

const BLOCK_TAGS = new Set([
  "P", "H1", "H2", "H3", "H4", "H5", "H6",
  "UL", "OL", "BLOCKQUOTE", "PRE", "TABLE", "FIGURE", "HR",
]);

/**
 * Normalize the browser's contentEditable output into clean semantic HTML:
 * - <b>/<i> -> <strong>/<em>, <div> -> <p>
 * - any loose text / inline content at the top level is wrapped in <p>, so even
 *   a plain typed line is stored as HTML (e.g. "Hello" -> "<p>Hello</p>")
 * - the various "empty" representations collapse to an empty string
 */
function normalizeHtml(raw: string): string {
  if (!raw) return "";

  const html = raw
    .replace(/<\s*b(\s[^>]*)?>/gi, "<strong>")
    .replace(/<\s*\/\s*b\s*>/gi, "</strong>")
    .replace(/<\s*i(\s[^>]*)?>/gi, "<em>")
    .replace(/<\s*\/\s*i\s*>/gi, "</em>")
    .replace(/<\s*div(\s[^>]*)?>/gi, "<p>")
    .replace(/<\s*\/\s*div\s*>/gi, "</p>");

  const source = document.createElement("div");
  source.innerHTML = html;

  const out = document.createElement("div");
  let buffer: Node[] = [];

  const flush = () => {
    if (buffer.length === 0) return;
    const hasText = buffer.some((n) => (n.textContent ?? "").trim() !== "");
    if (hasText) {
      const p = document.createElement("p");
      buffer.forEach((n) => p.appendChild(n));
      out.appendChild(p);
    }
    buffer = [];
  };

  Array.from(source.childNodes).forEach((node) => {
    if (node.nodeType === Node.ELEMENT_NODE && BLOCK_TAGS.has((node as Element).tagName)) {
      flush();
      out.appendChild(node);
    } else {
      buffer.push(node);
    }
  });
  flush();

  const result = out.innerHTML;
  const stripped = result.replace(/<br\s*\/?>/gi, "").replace(/<p>\s*<\/p>/gi, "").trim();
  return stripped === "" ? "" : result;
}
