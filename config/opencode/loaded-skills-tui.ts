import type { TuiPlugin, TuiPluginModule } from "@opencode-ai/plugin/tui";

const id = "local:sidebar-loaded-skills-v8";

const tui: TuiPlugin = async (api, options, meta) => {
  api.kv.set("loaded_skills_plugin_init", Date.now());

  const host_runtime_plugin_support =
    "/home/mh/projects/opencode/packages/opencode/node_modules/@opentui/solid/scripts/runtime-plugin-support.ts";
  try {
    await import(host_runtime_plugin_support);
    api.kv.set("loaded_skills_runtime_support", "host");
  } catch (error) {
    api.kv.set("loaded_skills_runtime_support_error", String(error));
    await import("@opentui/solid/runtime-plugin-support");
    api.kv.set("loaded_skills_runtime_support", "local");
  }

  const plugin = (await import("./loaded-skills-tui-view.tsx")).default;
  return plugin.tui(api, options, meta);
};

const plugin: TuiPluginModule & { id: string } = {
  id,
  tui,
};

export default plugin;
