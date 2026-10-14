import { useEffect, useState } from "react";

export const repo = "https://github.com/abderra7mane/claude-usage-bar";
export const releasesUrl = `${repo}/releases`;
const download = `${repo}/releases/latest/download`;

export type Arch = "arm64" | "x86_64" | "universal";

export const builds: Record<Arch, { label: string; url: string }> = {
  arm64: {
    label: "Apple Silicon",
    url: `${download}/ClaudeUsageBar-arm64.dmg`,
  },
  x86_64: {
    label: "Intel",
    url: `${download}/ClaudeUsageBar-x86_64.dmg`,
  },
  universal: {
    label: "Universal",
    url: `${download}/ClaudeUsageBar-universal.dmg`,
  },
};

export const archs: Arch[] = ["arm64", "x86_64", "universal"];

type Level = "ok" | "warning" | "critical";

export function level(percent: number): Level {
  if (percent >= 100) return "critical";
  if (percent >= 75) return "warning";
  return "ok";
}

export const levelColor: Record<Level, string> = {
  ok: "#0a84ff",
  warning: "#ff9f0a",
  critical: "#ff453a",
};

type Release = { version: string; date: string };

let releaseRequest: Promise<Release | null> | undefined;

function fetchRelease() {
  releaseRequest ??= fetch(
    "https://api.github.com/repos/abderra7mane/claude-usage-bar/releases/latest",
  )
    .then((response) => (response.ok ? response.json() : null))
    .then((data: { tag_name: string; published_at: string } | null) =>
      data
        ? {
            version: data.tag_name,
            date: new Date(data.published_at).toLocaleDateString("en", {
              month: "short",
              day: "numeric",
              year: "numeric",
            }),
          }
        : null,
    )
    .catch(() => null);
  return releaseRequest;
}

export function useLatestRelease() {
  const [release, setRelease] = useState<Release | null>(null);
  useEffect(() => {
    let active = true;
    fetchRelease().then((value) => active && setRelease(value));
    return () => {
      active = false;
    };
  }, []);
  return release;
}

type UserAgentData = {
  getHighEntropyValues(hints: string[]): Promise<{ architecture?: string }>;
};

/** Chromium reports the CPU architecture; other browsers fall back to the universal build. */
export function useDetectedArch() {
  const [arch, setArch] = useState<Arch>("universal");
  useEffect(() => {
    const data = (navigator as { userAgentData?: UserAgentData }).userAgentData;
    data
      ?.getHighEntropyValues(["architecture"])
      .then(({ architecture }) => {
        if (architecture === "arm") setArch("arm64");
        else if (architecture === "x86") setArch("x86_64");
      })
      .catch(() => {});
  }, []);
  return arch;
}
