import type { Plugin } from "@opencode-ai/plugin"

export const NotifyOnEventsPlugin: Plugin = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      if (event?.type !== "permission.asked" as "permission.updated") {
        return
      }

      await $`sleep 10`
      await $`notify-send "OpenCode permission.asked" ${JSON.stringify(event, null, 2)}`
    },
  }
}
