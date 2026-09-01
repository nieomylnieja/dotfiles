import { lookup } from "node:dns/promises";
import { isIP } from "node:net";

import { convert } from "html-to-markdown-node";

const DEFAULT_MAX_BYTES = 2_000_000;
const MAX_CONFIGURED_BYTES = 20_000_000;
const DEFAULT_TIMEOUT_MS = 15_000;
const MAX_REDIRECTS = 5;
const REDIRECT_STATUSES = new Set([301, 302, 303, 307, 308]);

type FetchOptions = {
  allowPrivate: boolean;
  maxBytes: number;
  timeoutMs: number;
};

type CliOptions = FetchOptions & {
  url: string;
};

type FetchResult = {
  markdown: string;
  sourceUrl: string;
};

type HostnameResolver = (
  hostname: string,
) => PromiseLike<readonly { address: string }[]>;

type Fetcher = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

type FetchDependencies = {
  fetch: Fetcher;
  resolveHostname: HostnameResolver;
};

type Deadline = {
  signal: AbortSignal;
  timeoutMs: number;
};

class DeadlineExceededError extends Error {}

const defaultOptions: FetchOptions = {
  allowPrivate: false,
  maxBytes: DEFAULT_MAX_BYTES,
  timeoutMs: DEFAULT_TIMEOUT_MS,
};

function fail(message: string): never {
  throw new Error(message);
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function deadlineError(timeoutMs: number): DeadlineExceededError {
  return new DeadlineExceededError(`request timed out after ${timeoutMs} ms`);
}

async function beforeDeadline<T>(
  operation: () => T | PromiseLike<T>,
  deadline: Deadline,
): Promise<T> {
  if (deadline.signal.aborted) {
    throw deadlineError(deadline.timeoutMs);
  }

  return new Promise<T>((resolve, reject) => {
    let settled = false;
    const finish = (callback: () => void): void => {
      if (settled) {
        return;
      }
      settled = true;
      deadline.signal.removeEventListener("abort", onAbort);
      callback();
    };
    const onAbort = (): void => {
      finish(() => reject(deadlineError(deadline.timeoutMs)));
    };

    deadline.signal.addEventListener("abort", onAbort, { once: true });
    Promise.resolve()
      .then(operation)
      .then(
        (value) => finish(() => resolve(value)),
        (error: unknown) =>
          finish(() =>
            reject(
              deadline.signal.aborted
                ? deadlineError(deadline.timeoutMs)
                : error,
            ),
          ),
      );
  });
}

function appendCleanupFailure(
  primary: unknown,
  cleanup: unknown,
  operation: string,
): Error {
  return new Error(
    `${errorMessage(primary)}; ${operation} failed: ${errorMessage(cleanup)}`,
  );
}

async function cancelResponseBody(
  response: Response,
  deadline: Deadline,
): Promise<void> {
  if (!response.body) {
    return;
  }
  await beforeDeadline(() => response.body!.cancel(), deadline);
}

async function failAfterResponseCleanup(
  response: Response,
  primary: Error,
  deadline: Deadline,
): Promise<never> {
  try {
    await cancelResponseBody(response, deadline);
  } catch (cleanupError) {
    throw appendCleanupFailure(
      primary,
      cleanupError,
      "response body cleanup",
    );
  }
  throw primary;
}

async function cleanRedirectResponse(
  response: Response,
  deadline: Deadline,
): Promise<void> {
  try {
    await cancelResponseBody(response, deadline);
  } catch (error) {
    if (error instanceof DeadlineExceededError) {
      throw error;
    }
    fail(`redirect response body cleanup failed: ${errorMessage(error)}`);
  }
}

function normalizedHostname(hostname: string): string {
  return hostname.toLowerCase().replace(/^\[|\]$/g, "").replace(/\.$/, "");
}

function mappedIpv4Address(address: string): string | undefined {
  if (!address.startsWith("::ffff:")) {
    return undefined;
  }

  const suffix = address.slice("::ffff:".length);
  if (isIP(suffix) === 4) {
    return suffix;
  }

  const match = /^([0-9a-f]{1,4}):([0-9a-f]{1,4})$/.exec(suffix);
  if (!match) {
    return undefined;
  }

  const high = Number.parseInt(match[1], 16);
  const low = Number.parseInt(match[2], 16);
  return `${high >> 8}.${high & 0xff}.${low >> 8}.${low & 0xff}`;
}

function ipv6AddressValue(address: string): bigint {
  const halves = address.split("::");
  const parseHalf = (half: string): number[] => {
    if (!half) {
      return [];
    }
    return half.split(":").flatMap((part) => {
      if (part.includes(".")) {
        const octets = part.split(".").map(Number);
        return [(octets[0] << 8) | octets[1], (octets[2] << 8) | octets[3]];
      }
      return [Number.parseInt(part, 16)];
    });
  };
  const left = parseHalf(halves[0]);
  const right = parseHalf(halves[1] ?? "");
  const missing = 8 - left.length - right.length;
  const segments =
    halves.length === 1
      ? left
      : [...left, ...Array.from({ length: missing }, () => 0), ...right];

  return segments.reduce(
    (value, segment) => (value << 16n) | BigInt(segment),
    0n,
  );
}

function isIpv6InRange(
  address: bigint,
  base: string,
  prefixLength: number,
): boolean {
  const shift = 128n - BigInt(prefixLength);
  return address >> shift === ipv6AddressValue(base) >> shift;
}

function displayUrl(url: URL): string {
  return url.origin;
}

function redactUrls(text: string): string {
  return text.replace(/https?:\/\/[^\s<>"']+/giu, (value) => {
    try {
      return displayUrl(new URL(value));
    } catch {
      return "<redacted URL>";
    }
  });
}

export function isPrivateAddress(address: string): boolean {
  const normalized = normalizedHostname(address);

  if (isIP(normalized) === 4) {
    const [a, b] = normalized.split(".").map(Number);

    return (
      a === 0 ||
      a === 10 ||
      a === 127 ||
      (a === 100 && b >= 64 && b <= 127) ||
      (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 0) ||
      (a === 192 && b === 168) ||
      (a === 198 && (b === 18 || b === 19)) ||
      (a === 198 && b === 51) ||
      (a === 203 && b === 0) ||
      a >= 224
    );
  }

  if (isIP(normalized) === 6) {
    const mappedAddress = mappedIpv4Address(normalized);
    if (mappedAddress) {
      return isPrivateAddress(mappedAddress);
    }

    const value = ipv6AddressValue(normalized);
    const blockedGlobalRanges = [
      ["2001::", 32],
      ["2001:2::", 48],
      ["2001:10::", 28],
      ["2001:20::", 28],
      ["2001:db8::", 32],
      ["2002::", 16],
      ["3fff::", 20],
    ] as const;

    return (
      !isIpv6InRange(value, "2000::", 3) ||
      blockedGlobalRanges.some(([base, prefixLength]) =>
        isIpv6InRange(value, base, prefixLength),
      )
    );
  }

  return false;
}

async function assertAllowedUrl(
  url: URL,
  allowPrivate: boolean,
  deadline: Deadline,
  resolveHostname: HostnameResolver,
): Promise<void> {
  if (url.protocol !== "http:" && url.protocol !== "https:") {
    fail(`unsupported URL scheme: ${url.protocol}`);
  }
  if (url.username || url.password) {
    fail("URLs with embedded credentials are not allowed");
  }
  if (allowPrivate) {
    return;
  }

  const hostname = normalizedHostname(url.hostname);
  if (
    hostname === "localhost" ||
    hostname.endsWith(".localhost") ||
    hostname.endsWith(".local") ||
    isPrivateAddress(hostname)
  ) {
    fail(`private or non-public address is not allowed: ${hostname}`);
  }

  const addresses = await beforeDeadline(
    () => resolveHostname(hostname),
    deadline,
  );
  if (addresses.length === 0) {
    fail(`hostname did not resolve: ${hostname}`);
  }
  for (const result of addresses) {
    if (isPrivateAddress(result.address)) {
      fail(`hostname resolves to a private or non-public address: ${hostname}`);
    }
  }
}

async function readLimitedBody(
  response: Response,
  maxBytes: number,
  deadline: Deadline,
): Promise<string> {
  const contentLength = response.headers.get("content-length");
  if (contentLength !== null && Number(contentLength) > maxBytes) {
    await failAfterResponseCleanup(
      response,
      new Error(`response exceeds ${maxBytes} bytes`),
      deadline,
    );
  }
  if (!response.body) {
    return "";
  }

  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  let primaryError: unknown;
  let failed = false;

  while (true) {
    try {
      const { done, value } = await beforeDeadline(
        () => reader.read(),
        deadline,
      );
      if (done) {
        break;
      }
      length += value.byteLength;
      if (length > maxBytes) {
        primaryError = new Error(`response exceeds ${maxBytes} bytes`);
        failed = true;
        break;
      }
      chunks.push(value);
    } catch (error) {
      primaryError = error;
      failed = true;
      break;
    }
  }

  if (failed) {
    if (!(primaryError instanceof DeadlineExceededError)) {
      try {
        await beforeDeadline(() => reader.cancel(), deadline);
      } catch (cleanupError) {
        primaryError = appendCleanupFailure(
          primaryError,
          cleanupError,
          "response body cleanup",
        );
      }
    }

    try {
      reader.releaseLock();
    } catch (cleanupError) {
      primaryError = appendCleanupFailure(
        primaryError,
        cleanupError,
        "response reader release",
      );
    }
    throw primaryError;
  }

  try {
    reader.releaseLock();
  } catch (error) {
    fail(`response reader release failed: ${errorMessage(error)}`);
  }

  const body = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    body.set(chunk, offset);
    offset += chunk.byteLength;
  }

  return new TextDecoder().decode(body);
}

export async function fetchMarkdown(
  input: string,
  overrides: Partial<FetchOptions> = {},
  dependencyOverrides: Partial<FetchDependencies> = {},
): Promise<FetchResult> {
  const options = { ...defaultOptions, ...overrides };
  const fetchImpl = dependencyOverrides.fetch ?? globalThis.fetch;
  const resolveHostname =
    dependencyOverrides.resolveHostname ??
    ((hostname: string) => lookup(hostname, { all: true, verbatim: true }));
  let currentUrl: URL;

  try {
    currentUrl = new URL(input);
  } catch {
    fail("invalid URL");
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), options.timeoutMs);
  const deadline: Deadline = {
    signal: controller.signal,
    timeoutMs: options.timeoutMs,
  };

  try {
    for (let redirects = 0; redirects <= MAX_REDIRECTS; redirects += 1) {
      await assertAllowedUrl(
        currentUrl,
        options.allowPrivate,
        deadline,
        resolveHostname,
      );
      const response = await beforeDeadline(
        () =>
          fetchImpl(currentUrl, {
            headers: { "user-agent": "html-to-markdown-skill/1" },
            redirect: "manual",
            signal: controller.signal,
          }),
        deadline,
      );

      if (REDIRECT_STATUSES.has(response.status)) {
        const location = response.headers.get("location");
        if (!location) {
          await failAfterResponseCleanup(
            response,
            new Error(`redirect ${response.status} has no Location header`),
            deadline,
          );
        }
        if (redirects === MAX_REDIRECTS) {
          await failAfterResponseCleanup(
            response,
            new Error(`more than ${MAX_REDIRECTS} redirects`),
            deadline,
          );
        }
        await cleanRedirectResponse(response, deadline);
        currentUrl = new URL(location, currentUrl);
        continue;
      }

      if (!response.ok) {
        await failAfterResponseCleanup(
          response,
          new Error(`HTTP ${response.status} ${response.statusText}`.trim()),
          deadline,
        );
      }

      const contentType = response.headers.get("content-type")?.toLowerCase();
      if (!contentType) {
        await failAfterResponseCleanup(
          response,
          new Error("expected HTML but response has no Content-Type header"),
          deadline,
        );
      }
      if (
        !contentType.includes("text/html") &&
        !contentType.includes("application/xhtml+xml")
      ) {
        await failAfterResponseCleanup(
          response,
          new Error(`expected HTML but received ${contentType}`),
          deadline,
        );
      }

      const html = await readLimitedBody(response, options.maxBytes, deadline);
      return {
        markdown: convert(html).trim(),
        sourceUrl: displayUrl(currentUrl),
      };
    }

    fail(`more than ${MAX_REDIRECTS} redirects`);
  } catch (error) {
    if (error instanceof DeadlineExceededError) {
      fail(error.message);
    }
    throw new Error(redactUrls(errorMessage(error)));
  } finally {
    clearTimeout(timeout);
  }
}

export function parseArguments(args: string[]): CliOptions {
  const options: CliOptions = { ...defaultOptions, url: "" };

  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === "--allow-private") {
      options.allowPrivate = true;
    } else if (argument === "--max-bytes") {
      const value = Number(args[index + 1]);
      if (!Number.isInteger(value) || value <= 0 || value > MAX_CONFIGURED_BYTES) {
        fail(`--max-bytes must be an integer from 1 to ${MAX_CONFIGURED_BYTES}`);
      }
      options.maxBytes = value;
      index += 1;
    } else if (argument.startsWith("-")) {
      fail(`unknown option: ${argument}`);
    } else if (options.url) {
      fail("exactly one URL is required");
    } else {
      options.url = argument;
    }
  }

  if (!options.url) {
    fail("usage: bun run scripts/index.ts [--allow-private] [--max-bytes N] <url>");
  }

  return options;
}

async function main(): Promise<void> {
  try {
    const options = parseArguments(process.argv.slice(2));
    const result = await fetchMarkdown(options.url, options);
    console.log(`Source: ${result.sourceUrl}\n\n${result.markdown}`);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`html-to-markdown: ${message}`);
    process.exitCode = 1;
  }
}

if (import.meta.main) {
  await main();
}
