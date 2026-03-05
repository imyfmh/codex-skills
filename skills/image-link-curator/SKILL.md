---
name: image-link-curator
description: Select or propose article image links and embed them into Markdown with fixed display dimensions. Use when users ask for article配图, image URLs, Markdown image embedding, or size-controlled visual inserts.
---

# Image Link Curator

## Workflow

1. Determine visual needs from sections.
2. Provide image link suggestions per slot.
3. Write concise, descriptive alt text.
4. Embed links in Markdown using fixed width and height.

## Embed format

Always use HTML image tags inside Markdown:

```html
<img src="IMAGE_URL" alt="ALT_TEXT" width="960" height="540" />
```

## Rules

- Prefer legally safe/publicly embeddable links.
- Keep style consistent across article.
- One image per major section unless user asks denser layout.
