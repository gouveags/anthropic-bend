import { expect, test } from "bun:test";

test("typed message extracts text and tool uses while retaining thinking and unknown fields", () => {
  const raw = {
    id: "msg_typed",
    stop_reason: "tool_use",
    content: [
      { type: "text", text: "one" },
      { type: "thinking", thinking: "preserve this", signature: "signature" },
      { type: "text", text: "two" },
      { type: "tool_use", id: "tool_a", name: "lookup", input: { city: "A" } },
      { type: "tool_use", id: "tool_b", name: "lookup", input: { city: "B" } },
    ],
    usage: null,
    future: true,
  };
  const result = Bun.spawnSync([
    "bun",
    "build/helpers.js",
    JSON.stringify(raw),
  ]);
  expect(result.exitCode).toBe(0);
  expect(result.stdout.toString().trim()).toBe(
    "msg_typed|tool_use|onetwo|2|" + JSON.stringify(raw),
  );
});

test("token-limit stop reason stays visible", () => {
  const raw = {
    id: "msg_partial",
    stop_reason: "max_tokens",
    content: [{ type: "text", text: "partial" }],
  };
  const result = Bun.spawnSync([
    "bun",
    "build/helpers.js",
    JSON.stringify(raw),
  ]);
  expect(result.exitCode).toBe(0);
  expect(result.stdout.toString()).toStartWith(
    "msg_partial|max_tokens|partial|0|",
  );
});
