/** @jsxImportSource @opentui/solid */
import type {
  TuiPlugin,
  TuiPluginApi,
  TuiPluginModule,
} from "@opencode-ai/plugin/tui";

const id = "local:sidebar-loaded-skills-v2";

function View(props: { api: TuiPluginApi }) {
  const theme = () => props.api.theme.current;

  return (
    <box>
      <text fg={theme().warning}>PLUGIN ACTIVE</text>
      <text fg={theme().textMuted}>loaded-skills-view.tsx rendered</text>
    </box>
  );
}

const tui: TuiPlugin = async (api) => {
  api.kv.set("loaded_skills_register_start", Date.now());
  const id = api.slots.register({
    order: -1000,
    slots: {
      sidebar_title(_ctx, props: { title: string }) {
        return (
          <text fg={api.theme.current.warning}>
            PLUGIN ACTIVE · {props.title}
          </text>
        );
      },
      sidebar_content() {
        return <View api={api} />;
      },
      sidebar_footer() {
        return (
          <text fg={api.theme.current.warning}>
            PLUGIN ACTIVE · sidebar footer
          </text>
        );
      },
    },
  });
  api.kv.set("loaded_skills_register_id", id);
  api.kv.set("loaded_skills_register_done", Date.now());
};

const plugin: TuiPluginModule & { id: string } = {
  id,
  tui,
};

export default plugin;
