import { afterAll, beforeAll, describe, expect, spyOn, test } from "bun:test";

import {
  fetchMarkdown,
  isPrivateAddress,
  parseArguments,
} from "./index";

let server: ReturnType<typeof Bun.serve>;
let baseUrl: string;

function responseWithRejectingCancellation(
  init: ResponseInit,
  body?: Uint8Array,
): Response {
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      if (body) {
        controller.enqueue(body);
      }
    },
    cancel() {
      return Promise.reject(new Error("cancel failed"));
    },
  });
  return new Response(stream, init);
}

beforeAll(() => {
  server = Bun.serve({
    port: 0,
    fetch(request) {
      const url = new URL(request.url);

      if (url.pathname === "/ok") {
        return new Response("<main><h1>Title</h1><p>Body</p></main>", {
          headers: { "content-type": "text/html; charset=utf-8" },
        });
      }
      if (url.pathname === "/redirect") {
        return Response.redirect(new URL("/ok", url), 302);
      }
      if (url.pathname === "/plain") {
        return new Response("not html", {
          headers: { "content-type": "text/plain" },
        });
      }
      if (url.pathname === "/missing-content-type") {
        return new Response(null, { status: 204 });
      }
      if (url.pathname === "/large") {
        const stream = new ReadableStream({
          start(controller) {
            controller.enqueue(
              new TextEncoder().encode(`<p>${"x".repeat(200)}</p>`),
            );
            controller.close();
          },
        });
        return new Response(stream, {
          headers: { "content-type": "text/html" },
        });
      }
      return new Response("missing", {
        status: 404,
        headers: { "content-type": "text/html" },
      });
    },
  });
  baseUrl = `http://127.0.0.1:${server.port}`;
});

afterAll(() => {
  server.stop(true);
});

describe("address policy", () => {
  test("rejects representative non-public addresses", () => {
    expect(isPrivateAddress("127.0.0.1")).toBe(true);
    expect(isPrivateAddress("10.1.2.3")).toBe(true);
    expect(isPrivateAddress("169.254.1.1")).toBe(true);
    expect(isPrivateAddress("::1")).toBe(true);
    expect(isPrivateAddress("::ffff:7f00:1")).toBe(true);
    expect(isPrivateAddress("::ffff:0a00:1")).toBe(true);
    expect(isPrivateAddress("fc00::1")).toBe(true);
    expect(isPrivateAddress("fe80::1")).toBe(true);
    expect(isPrivateAddress("fec0::1")).toBe(true);
    expect(isPrivateAddress("feff::1")).toBe(true);
    expect(isPrivateAddress("2001::1")).toBe(true);
    expect(isPrivateAddress("2001:db8::1")).toBe(true);
    expect(isPrivateAddress("2606:4700:4700::1111")).toBe(false);
    expect(isPrivateAddress("1.1.1.1")).toBe(false);
  });

  test("blocks a local URL unless explicitly allowed", async () => {
    await expect(fetchMarkdown(`${baseUrl}/ok`)).rejects.toThrow(
      "private or non-public address is not allowed",
    );
  });

  test("blocks an IPv4-mapped IPv6 URL", async () => {
    await expect(
      fetchMarkdown("http://[::ffff:127.0.0.1]/"),
    ).rejects.toThrow("private or non-public address is not allowed");
  });

  test("checks every redirect target before fetching it", async () => {
    const fetchSpy = spyOn(globalThis, "fetch").mockResolvedValueOnce(
      new Response(null, {
        status: 302,
        headers: { location: "http://127.0.0.1/private" },
      }),
    );

    try {
      await expect(fetchMarkdown("http://1.1.1.1/public")).rejects.toThrow(
        "private or non-public address is not allowed",
      );
      expect(fetchSpy).toHaveBeenCalledTimes(1);
    } finally {
      fetchSpy.mockRestore();
    }
  });

  test("applies the request deadline to DNS resolution", async () => {
    await expect(
      fetchMarkdown(
        "https://example.com",
        { timeoutMs: 5 },
        {
          resolveHostname: () => new Promise(() => {}),
        },
      ),
    ).rejects.toThrow("request timed out after 5 ms");
  });
});

describe("HTML conversion", () => {
  test("converts HTML and records the final origin", async () => {
    const result = await fetchMarkdown(`${baseUrl}/redirect`, {
      allowPrivate: true,
    });

    expect(result.sourceUrl).toBe(baseUrl);
    expect(result.markdown).toContain("# Title");
    expect(result.markdown).toContain("Body");
  });

  test("removes secrets from the displayed source URL", async () => {
    const result = await fetchMarkdown(
      "https://example.com/article?token=secret#section",
      { allowPrivate: true },
      {
        fetch: async () =>
          new Response("<p>Body</p>", {
            headers: { "content-type": "text/html" },
          }),
      },
    );

    expect(result.sourceUrl).toBe("https://example.com");
    expect(result.sourceUrl).not.toContain("secret");
  });

  test("removes secrets from a redirected source URL", async () => {
    let calls = 0;
    const result = await fetchMarkdown(
      "https://example.com/start",
      { allowPrivate: true },
      {
        fetch: async () => {
          calls += 1;
          if (calls === 1) {
            return new Response(null, {
              status: 302,
              headers: {
                location:
                  "https://cdn.example.com/article?signature=secret#part",
              },
            });
          }
          return new Response("<p>Body</p>", {
            headers: { "content-type": "text/html" },
          });
        },
      },
    );

    expect(result.sourceUrl).toBe("https://cdn.example.com");
    expect(result.sourceUrl).not.toContain("secret");
  });

  test("redacts URLs in fetch errors", async () => {
    await expect(
      fetchMarkdown(
        "https://example.com/start",
        { allowPrivate: true },
        {
          fetch: async () => {
            throw new Error(
              "redirect failed at https://cdn.example.com/file?token=secret",
            );
          },
        },
      ),
    ).rejects.toThrow("redirect failed at https://cdn.example.com");

    try {
      await fetchMarkdown(
        "https://example.com/start",
        { allowPrivate: true },
        {
          fetch: async () => {
            throw new Error(
              "redirect failed at https://cdn.example.com/file?token=secret",
            );
          },
        },
      );
    } catch (error) {
      expect(String(error)).not.toContain("token=secret");
    }
  });

  test("redacts a signed IPv6 URL in fetch errors", async () => {
    try {
      await fetchMarkdown(
        "https://example.com/start",
        { allowPrivate: true },
        {
          fetch: async () => {
            throw new Error(
              "failed at http://[2606:4700::1]/file?token=secret",
            );
          },
        },
      );
      throw new Error("expected fetchMarkdown to reject");
    } catch (error) {
      expect(String(error)).toContain("http://[2606:4700::1]");
      expect(String(error)).not.toContain("token=secret");
    }
  });

  test("does not echo an invalid input URL", async () => {
    const input = "not-a-url?token=secret";

    try {
      await fetchMarkdown(input);
      throw new Error("expected fetchMarkdown to reject");
    } catch (error) {
      expect(String(error)).toContain("invalid URL");
      expect(String(error)).not.toContain("token=secret");
    }
  });

  test("rejects failed responses", async () => {
    await expect(
      fetchMarkdown(`${baseUrl}/missing`, { allowPrivate: true }),
    ).rejects.toThrow("HTTP 404 Not Found");
  });

  test("rejects non-HTML responses", async () => {
    await expect(
      fetchMarkdown(`${baseUrl}/plain`, { allowPrivate: true }),
    ).rejects.toThrow("expected HTML but received text/plain");
  });

  test("rejects responses without a content type", async () => {
    await expect(
      fetchMarkdown(`${baseUrl}/missing-content-type`, { allowPrivate: true }),
    ).rejects.toThrow("expected HTML but response has no Content-Type header");
  });

  test("stops reading above the byte limit", async () => {
    await expect(
      fetchMarkdown(`${baseUrl}/large`, {
        allowPrivate: true,
        maxBytes: 32,
      }),
    ).rejects.toThrow("response exceeds 32 bytes");
  });

  test("rejects a declared body above the byte limit", async () => {
    const fetchSpy = spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(null, {
        headers: {
          "content-length": "200",
          "content-type": "text/html",
        },
      }),
    );

    try {
      await expect(
        fetchMarkdown("https://example.com", {
          allowPrivate: true,
          maxBytes: 32,
        }),
      ).rejects.toThrow("response exceeds 32 bytes");
    } finally {
      fetchSpy.mockRestore();
    }
  });

  test("rejects a redirect without a location", async () => {
    const fetchSpy = spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(null, { status: 302 }),
    );

    try {
      await expect(
        fetchMarkdown("https://example.com", { allowPrivate: true }),
      ).rejects.toThrow("redirect 302 has no Location header");
    } finally {
      fetchSpy.mockRestore();
    }
  });

  test("stops after the redirect limit", async () => {
    const fetchSpy = spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(null, {
        status: 302,
        headers: { location: "https://example.com/again" },
      }),
    );

    try {
      await expect(
        fetchMarkdown("https://example.com", { allowPrivate: true }),
      ).rejects.toThrow("more than 5 redirects");
      expect(fetchSpy).toHaveBeenCalledTimes(6);
    } finally {
      fetchSpy.mockRestore();
    }
  });

  test("reports a fetch timeout", async () => {
    await expect(
      fetchMarkdown(
        "https://example.com",
        {
          allowPrivate: true,
          timeoutMs: 1,
        },
        {
          fetch: (_input, init) =>
            new Promise<Response>((_resolve, reject) => {
              init?.signal?.addEventListener("abort", () => {
                reject(new DOMException("aborted", "AbortError"));
              });
            }),
        },
      ),
    ).rejects.toThrow("request timed out after 1 ms");
  });

  test("uses one deadline signal across redirects", async () => {
    const signals: (AbortSignal | null | undefined)[] = [];
    let calls = 0;

    await expect(
      fetchMarkdown(
        "https://example.com/start",
        { allowPrivate: true, timeoutMs: 5 },
        {
          fetch: async (_input, init) => {
            signals.push(init?.signal);
            calls += 1;
            if (calls === 1) {
              return new Response(null, {
                status: 302,
                headers: { location: "/next" },
              });
            }
            return new Promise<Response>((_resolve, reject) => {
              init?.signal?.addEventListener("abort", () => {
                reject(new DOMException("aborted", "AbortError"));
              });
            });
          },
        },
      ),
    ).rejects.toThrow("request timed out after 5 ms");

    expect(signals).toHaveLength(2);
    expect(signals[1]).toBe(signals[0]);
  });

  test("applies the request deadline to body reads", async () => {
    await expect(
      fetchMarkdown(
        "https://example.com",
        { allowPrivate: true, timeoutMs: 5 },
        {
          fetch: async () =>
            new Response(new ReadableStream({ pull() {} }), {
              headers: { "content-type": "text/html" },
            }),
        },
      ),
    ).rejects.toThrow("request timed out after 5 ms");
  });

  const cancellationCases = [
    {
      name: "redirect failure",
      expected: "redirect 302 has no Location header",
      response: () =>
        responseWithRejectingCancellation({
          status: 302,
        }),
      maxBytes: 32,
    },
    {
      name: "HTTP failure",
      expected: "HTTP 502 Bad Gateway",
      response: () =>
        responseWithRejectingCancellation({
          status: 502,
          statusText: "Bad Gateway",
        }),
      maxBytes: 32,
    },
    {
      name: "content-type failure",
      expected: "expected HTML but received text/plain",
      response: () =>
        responseWithRejectingCancellation({
          headers: { "content-type": "text/plain" },
        }),
      maxBytes: 32,
    },
    {
      name: "declared-size failure",
      expected: "response exceeds 32 bytes",
      response: () =>
        responseWithRejectingCancellation({
          headers: {
            "content-length": "200",
            "content-type": "text/html",
          },
        }),
      maxBytes: 32,
    },
    {
      name: "streamed-size failure",
      expected: "response exceeds 32 bytes",
      response: () =>
        responseWithRejectingCancellation(
          { headers: { "content-type": "text/html" } },
          new TextEncoder().encode("x".repeat(64)),
        ),
      maxBytes: 32,
    },
  ];

  for (const cancellationCase of cancellationCases) {
    test(`preserves the ${cancellationCase.name} when cleanup fails`, async () => {
      await expect(
        fetchMarkdown(
          "https://example.com",
          {
            allowPrivate: true,
            maxBytes: cancellationCase.maxBytes,
          },
          {
            fetch: async () => cancellationCase.response(),
          },
        ),
      ).rejects.toThrow(
        `${cancellationCase.expected}; response body cleanup failed: cancel failed`,
      );
    });
  }
});

describe("arguments", () => {
  test("parses explicit safety overrides", () => {
    expect(
      parseArguments([
        "--allow-private",
        "--max-bytes",
        "500",
        "https://example.com",
      ]),
    ).toMatchObject({
      allowPrivate: true,
      maxBytes: 500,
      url: "https://example.com",
    });
  });

  test("rejects multiple URLs", () => {
    expect(() =>
      parseArguments(["https://example.com", "https://example.org"]),
    ).toThrow("exactly one URL is required");
  });
});
