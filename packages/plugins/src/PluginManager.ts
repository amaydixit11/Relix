/**
 * Relix Plugin System
 * 
 * Plugins can extend Relix functionality by:
 * - Adding new commands
 * - Transforming content
 * - Adding UI components
 * - Integrating with external services
 */

export interface Plugin {
  /** Unique plugin identifier */
  id: string;
  
  /** Display name */
  name: string;
  
  /** Plugin version */
  version: string;
  
  /** Optional description */
  description?: string;
  
  /** Called when plugin is loaded */
  onLoad?: () => void | Promise<void>;
  
  /** Called when plugin is unloaded */
  onUnload?: () => void | Promise<void>;
  
  /** Commands the plugin provides */
  commands?: PluginCommand[];
  
  /** Content transformers */
  transformers?: ContentTransformer[];
  
  /** Settings schema */
  settings?: PluginSetting[];
}

export interface PluginCommand {
  /** Command ID (e.g., "ai.summarize") */
  id: string;
  
  /** Display name */
  name: string;
  
  /** Keyboard shortcut */
  shortcut?: string;
  
  /** Command handler */
  execute: (context: CommandContext) => void | Promise<void>;
}

export interface CommandContext {
  /** Currently selected note ID */
  noteId?: string;
  
  /** Selected text */
  selection?: string;
  
  /** Current note content */
  content?: string;
  
  /** Update note content */
  updateContent: (content: string) => Promise<void>;
  
  /** Show notification */
  notify: (message: string, type?: 'info' | 'success' | 'error') => void;
}

export interface ContentTransformer {
  /** Transformer ID */
  id: string;
  
  /** When to apply: 'render' | 'save' | 'both' */
  trigger: 'render' | 'save' | 'both';
  
  /** Transform function */
  transform: (content: string) => string | Promise<string>;
}

export interface PluginSetting {
  /** Setting key */
  key: string;
  
  /** Display label */
  label: string;
  
  /** Setting type */
  type: 'string' | 'number' | 'boolean' | 'select';
  
  /** Default value */
  default: unknown;
  
  /** Options for select type */
  options?: { label: string; value: unknown }[];
}

/**
 * Plugin Manager - Handles loading/unloading plugins
 */
export class PluginManager {
  private plugins: Map<string, Plugin> = new Map();
  private enabled: Set<string> = new Set();

  /**
   * Register a plugin
   */
  register(plugin: Plugin): void {
    if (this.plugins.has(plugin.id)) {
      console.warn(`Plugin ${plugin.id} already registered`);
      return;
    }
    this.plugins.set(plugin.id, plugin);
    console.log(`Plugin registered: ${plugin.name} v${plugin.version}`);
  }

  /**
   * Enable a plugin
   */
  async enable(id: string): Promise<void> {
    const plugin = this.plugins.get(id);
    if (!plugin) throw new Error(`Plugin not found: ${id}`);
    
    if (plugin.onLoad) {
      await plugin.onLoad();
    }
    this.enabled.add(id);
    console.log(`Plugin enabled: ${plugin.name}`);
  }

  /**
   * Disable a plugin
   */
  async disable(id: string): Promise<void> {
    const plugin = this.plugins.get(id);
    if (!plugin) throw new Error(`Plugin not found: ${id}`);
    
    if (plugin.onUnload) {
      await plugin.onUnload();
    }
    this.enabled.delete(id);
    console.log(`Plugin disabled: ${plugin.name}`);
  }

  /**
   * Get all registered plugins
   */
  getPlugins(): Plugin[] {
    return Array.from(this.plugins.values());
  }

  /**
   * Get enabled plugins
   */
  getEnabledPlugins(): Plugin[] {
    return Array.from(this.plugins.values()).filter(p => this.enabled.has(p.id));
  }

  /**
   * Get all commands from enabled plugins
   */
  getCommands(): PluginCommand[] {
    return this.getEnabledPlugins().flatMap(p => p.commands || []);
  }

  /**
   * Execute a command by ID
   */
  async executeCommand(commandId: string, context: CommandContext): Promise<void> {
    const command = this.getCommands().find(c => c.id === commandId);
    if (!command) throw new Error(`Command not found: ${commandId}`);
    await command.execute(context);
  }
}

// Singleton instance
export const pluginManager = new PluginManager();
