/**
 * AI Plugin Example
 * 
 * This is a template for AI integration plugins.
 * Replace the placeholder implementation with actual AI service calls.
 */

import type { Plugin, CommandContext } from './PluginManager';

export const aiPlugin: Plugin = {
  id: 'relix.ai',
  name: 'AI Assistant',
  version: '0.0.1',
  description: 'AI-powered note enhancements',

  commands: [
    {
      id: 'ai.summarize',
      name: 'Summarize Note',
      shortcut: 'Ctrl+Shift+S',
      execute: async (context: CommandContext) => {
        if (!context.content) {
          context.notify('No content to summarize', 'error');
          return;
        }

        context.notify('Generating summary...', 'info');
        
        // Placeholder - replace with actual AI API call
        const summary = await mockAISummarize(context.content);
        
        // Prepend summary to note
        const newContent = `## Summary\n${summary}\n\n---\n\n${context.content}`;
        await context.updateContent(newContent);
        
        context.notify('Summary added!', 'success');
      },
    },
    {
      id: 'ai.expand',
      name: 'Expand Selection',
      shortcut: 'Ctrl+Shift+E',
      execute: async (context: CommandContext) => {
        if (!context.selection) {
          context.notify('Select text to expand', 'error');
          return;
        }

        context.notify('Expanding...', 'info');
        
        // Placeholder - replace with actual AI API call
        const expanded = await mockAIExpand(context.selection);
        
        const newContent = context.content?.replace(context.selection, expanded) || expanded;
        await context.updateContent(newContent);
        
        context.notify('Text expanded!', 'success');
      },
    },
    {
      id: 'ai.tags',
      name: 'Suggest Tags',
      execute: async (context: CommandContext) => {
        if (!context.content) {
          context.notify('No content to analyze', 'error');
          return;
        }

        context.notify('Analyzing content...', 'info');
        
        // Placeholder - replace with actual AI API call
        const tags = await mockAISuggestTags(context.content);
        
        context.notify(`Suggested tags: ${tags.join(', ')}`, 'info');
      },
    },
    {
      id: 'ai.related',
      name: 'Find Related Notes',
      execute: async (context: CommandContext) => {
        if (!context.noteId) {
          context.notify('No note selected', 'error');
          return;
        }

        context.notify('Finding related notes...', 'info');
        
        // Placeholder - this would use embeddings/vector search
        context.notify('Related notes feature coming soon!', 'info');
      },
    },
  ],

  settings: [
    {
      key: 'api_key',
      label: 'AI API Key',
      type: 'string',
      default: '',
    },
    {
      key: 'model',
      label: 'AI Model',
      type: 'select',
      default: 'gpt-4',
      options: [
        { label: 'GPT-4', value: 'gpt-4' },
        { label: 'GPT-3.5', value: 'gpt-3.5-turbo' },
        { label: 'Claude', value: 'claude-3' },
        { label: 'Local (Ollama)', value: 'ollama' },
      ],
    },
  ],
};

// Mock AI functions - replace with real implementations
async function mockAISummarize(content: string): Promise<string> {
  // Simulate API delay
  await new Promise(r => setTimeout(r, 500));
  
  // Simple extractive "summary"
  const sentences = content.split(/[.!?]+/).filter(s => s.trim().length > 20);
  return sentences.slice(0, 3).join('. ') + '.';
}

async function mockAIExpand(text: string): Promise<string> {
  await new Promise(r => setTimeout(r, 500));
  return `${text}\n\n*[AI would expand this concept with more details, examples, and connections to related topics.]*`;
}

async function mockAISuggestTags(content: string): Promise<string[]> {
  await new Promise(r => setTimeout(r, 300));
  
  // Simple keyword extraction
  const words = content.toLowerCase().split(/\W+/);
  const freq: Record<string, number> = {};
  
  for (const word of words) {
    if (word.length > 4) {
      freq[word] = (freq[word] || 0) + 1;
    }
  }
  
  return Object.entries(freq)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([word]) => word);
}

export default aiPlugin;
