/**
 * Note Templates
 * Pre-defined templates for common note types
 */

export interface NoteTemplate {
  id: string;
  name: string;
  icon: string;
  tags: string[];
  content: string;
}

export const defaultTemplates: NoteTemplate[] = [
  {
    id: 'blank',
    name: 'Blank Note',
    icon: '📝',
    tags: [],
    content: '',
  },
  {
    id: 'daily',
    name: 'Daily Note',
    icon: '📅',
    tags: ['daily'],
    content: `# {{date}}

## Today's Goals
- [ ] 

## Notes


## Reflection

`,
  },
  {
    id: 'meeting',
    name: 'Meeting Notes',
    icon: '👥',
    tags: ['meeting'],
    content: `# Meeting: {{title}}

**Date:** {{date}}
**Attendees:** 

## Agenda
1. 

## Discussion


## Action Items
- [ ] 

## Next Steps

`,
  },
  {
    id: 'project',
    name: 'Project',
    icon: '🎯',
    tags: ['project'],
    content: `# Project: {{title}}

## Overview


## Goals
- 

## Tasks
- [ ] 

## Resources
- [[]]

## Timeline


## Notes

`,
  },
  {
    id: 'article',
    name: 'Article/Research',
    icon: '📚',
    tags: ['reading'],
    content: `# {{title}}

**Source:** 
**Author:** 
**Date Read:** {{date}}

## Summary


## Key Points
- 

## Quotes
> 

## My Thoughts


## Related
- [[]]
`,
  },
  {
    id: 'brainstorm',
    name: 'Brainstorm',
    icon: '💡',
    tags: ['ideas'],
    content: `# Brainstorm: {{title}}

## The Problem


## Ideas
1. 
2. 
3. 

## Pros & Cons

| Idea | Pros | Cons |
|------|------|------|
|      |      |      |

## Conclusion

`,
  },
];

/**
 * Process template variables
 */
export function processTemplate(template: NoteTemplate, title: string): { title: string; content: string; tags: string[] } {
  const date = new Date().toISOString().split('T')[0];
  const dateFormatted = new Date().toLocaleDateString('en-US', { 
    weekday: 'long', 
    year: 'numeric', 
    month: 'long', 
    day: 'numeric' 
  });

  let content = template.content
    .replace(/\{\{title\}\}/g, title)
    .replace(/\{\{date\}\}/g, dateFormatted)
    .replace(/\{\{date_iso\}\}/g, date);

  // For daily notes, use date as title
  const finalTitle = template.id === 'daily' ? `Daily Note - ${date}` : title;

  return {
    title: finalTitle,
    content,
    tags: [...template.tags],
  };
}
