/** @jsxImportSource @opentui/solid */
import type { Part } from "@opencode-ai/sdk/v2";
import type {
  TuiPlugin,
  TuiPluginApi,
  TuiPluginModule,
} from "@opencode-ai/plugin/tui";
import { createMemo, createSignal, For, Show } from "solid-js";

const id = "local:sidebar-loaded-skills";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function skillName(part: Part) {
  if (part.type !== "tool" || part.tool !== "skill") return;
  if (!isRecord(part.state.input)) return;
  const name = part.state.input.name;
  if (typeof name !== "string") return;
  const out = name.trim();
  if (!out) return;
  return out;
}

function View(props: { api: TuiPluginApi; session_id: string }) {
  const [open, setOpen] = createSignal(true);
  const theme = () => props.api.theme.current;

  const list = createMemo(() => {
    const seen = new Set<string>();
    return props.api.state.session
      .messages(props.session_id)
      .flatMap((message) => props.api.state.part(message.id))
      .flatMap((part) => {
        const name = skillName(part);
        if (!name || seen.has(name)) return [];
        seen.add(name);
        return [name];
      });
  });

  const expandable = createMemo(() => list().length > 2);

  return (
    <Show when={list().length > 0}>
      <box>
        <box
          flexDirection="row"
          gap={1}
          onMouseDown={() => expandable() && setOpen((value) => !value)}
        >
          <Show when={expandable()}>
            <text fg={theme().text}>{open() ? "▼" : "▶"}</text>
          </Show>
          <text fg={theme().text}>
            <b>Loaded Skills</b>
            <Show when={!open()}>
              <span style={{ fg: theme().textMuted }}> ({list().length})</span>
            </Show>
          </text>
        </box>
        <Show when={!expandable() || open()}>
          <For each={list()}>
            {(name) => <text fg={theme().textMuted}>{name}</text>}
          </For>
        </Show>
      </box>
    </Show>
  );
}

const tui: TuiPlugin = async (api) => {
  api.slots.register({
    order: 300,
    slots: {
      sidebar_content(_ctx: unknown, props: { session_id: string }) {
        return <View api={api} session_id={props.session_id} />;
      },
    },
  });
};

const plugin: TuiPluginModule & { id: string } = {
  id,
  tui,
};

export default plugin;
