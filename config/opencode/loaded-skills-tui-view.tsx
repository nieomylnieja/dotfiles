/** @jsxImportSource @opentui/solid */
import type { TuiPlugin, TuiPluginModule } from "@opencode-ai/plugin/tui";

const id = "local:sidebar-loaded-skills-v8";

const tui: TuiPlugin = async (api) => {
  api.kv.set("loaded_skills_register_start", Date.now());

  let sidebar_called = false;
  const register_id = api.slots.register({
    order: 10,
    slots: {
      sidebar_content() {
        if (!sidebar_called) {
          sidebar_called = true;
          api.kv.set("loaded_skills_sidebar_content_called", Date.now());
        }

        const node = (
          <box
            border
            borderStyle="single"
            borderColor={api.theme.current.warning}
            paddingLeft={1}
            paddingRight={1}
          >
            <text fg={api.theme.current.warning}>PLUGIN ACTIVE V8</text>
            <text fg={api.theme.current.textMuted}>
              loaded-skills-tui-view.tsx
            </text>
          </box>
        );
        api.kv.set("loaded_skills_sidebar_content_render_ok", Date.now());
        return node;
      },
    },
  });

  api.kv.set("loaded_skills_register_id", register_id);
  api.kv.set("loaded_skills_register_done", Date.now());
};

const plugin: TuiPluginModule & { id: string } = {
  id,
  tui,
};

export default plugin;
