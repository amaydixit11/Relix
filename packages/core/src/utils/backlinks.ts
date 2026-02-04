/**
 * Extract wikilink references from markdown text
 * Matches [[Note Title]] or [[uuid]] patterns
 * 
 * @param text - Markdown text to parse
 * @returns Array of linked note identifiers
 */
export function extractWikilinks(text: string): string[] {
  const regex = /\[\[([^\]]+)\]\]/g;
  const links: string[] = [];
  let match;

  while ((match = regex.exec(text)) !== null) {
    const link = match[1].trim();
    if (link && !links.includes(link)) {
      links.push(link);
    }
  }

  return links;
}

/**
 * Replace wikilinks with rendered links
 * 
 * @param text - Markdown text
 * @param resolver - Function to resolve link ID to URL
 * @returns Text with wikilinks replaced
 */
export function renderWikilinks(
  text: string,
  resolver: (id: string) => string
): string {
  return text.replace(/\[\[([^\]]+)\]\]/g, (_, id) => {
    const url = resolver(id.trim());
    return `[${id}](${url})`;
  });
}

/**
 * Check if text contains a wikilink to a specific note
 */
export function containsWikilink(text: string, targetId: string): boolean {
  const links = extractWikilinks(text);
  return links.includes(targetId);
}
