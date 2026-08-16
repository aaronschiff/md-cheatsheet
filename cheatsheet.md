# Markdown cheatsheet

## Text

| Format | Syntax |
|---|---|
| *italic* | `*italic*` or `_italic_` |
| **bold** | `**bold**` |
| ***bold italic*** | `***bold italic***` |
| ~~strikethrough~~ | `~~strikethrough~~` |
| `inline code` | `` `inline code` `` |
| H~2~O (subscript) | `H~2~O` |
| X^2^ (superscript) | `X^2^` |

> Blockquote: prefix lines with `>`

## Headings

```markdown
# H1     #### H4
## H2    ##### H5
### H3   ###### H6
```

Heading ID: `### Heading {#custom-id}` — link to it with `[text](#custom-id)`

## Lists

```markdown
- Bullet          1. Numbered
  - Nested          2. Item
- [ ] Task            - nested needs 3 spaces
- [x] Done
```

Definition list: `Term` on one line, `: Definition` on the next

## Code

````
```python          ← fenced block with language
def hi(): pass
```
    indented block (4 spaces) also works
````

Escape a backtick with a backslash: `` \` `` — or wrap in double backticks.

## Links & images

| Result | Syntax |
|---|---|
| [text](https://example.com) | `[text](https://example.com)` |
| hover title | `[text](url "title")` |
| <https://example.com> | `<https://example.com>` |
| image | `![alt](img.png "title")` |
| reference link | `[ref][1]` + `[1]: url` |

## Tables

```markdown
| Left | Centre | Right |
|:-----|:------:|------:|
| a    | b      | c     |
```

| Left | Centre | Right |
|:-----|:------:|------:|
| a    | b      | c     |

## Misc

| What | Syntax |
|---|---|
| Horizontal rule | `---` or `***` |
| Line break | two trailing spaces, or `\` at line end |
| Escape character | `\*not italic\*` |
| Footnote | `text[^1]` then `[^1]: note` |
| HTML inline | `<kbd>⌘</kbd> works` |
