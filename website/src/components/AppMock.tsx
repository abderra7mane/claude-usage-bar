import { useState } from "react";
import { level, levelColor } from "@/site";

type MockSession = {
  title: string;
  cost: number;
  minutes: number;
  path: string;
  account: string;
};

const sampleSessions: MockSession[] = [
  {
    title: "Refactor billing webhooks",
    cost: 4.82,
    minutes: 52,
    path: "~/Projects/shop",
    account: "Personal",
  },
  {
    title: "Fix flaky login test",
    cost: 1.37,
    minutes: 12,
    path: "~/Work/portal",
    account: "Work",
  },
  {
    title: "Draft release notes",
    cost: 0.64,
    minutes: 4,
    path: "~/Projects/claude-usage-bar",
    account: "Personal",
  },
];

function cacheLevel(minutes: number) {
  if (minutes <= 5) return "critical";
  if (minutes <= 15) return "warning";
  return "ok";
}

function remainingLabel(minutes: number) {
  const rounded = Math.ceil(minutes);
  return rounded >= 60 ? `${Math.floor(rounded / 60)}h` : `${rounded}m`;
}

/** The menu bar item: a plate with the session bar above the weekly bar. */
export function StatusGlyph({
  session,
  weekly,
  scale = 1,
}: {
  session: number;
  weekly: number;
  scale?: number;
}) {
  const bar = (y: number, percent: number) => {
    const color = levelColor[level(percent)];
    const width = Math.max(
      22 * Math.min(percent / 100, 1),
      percent > 0 ? 5 : 0,
    );
    return (
      <g>
        <rect
          x="3"
          y={y}
          width="22"
          height="5"
          rx="2.5"
          fill={color}
          opacity={0.3}
        />
        {percent > 0 && (
          <rect x="3" y={y} width={width} height="5" rx="2.5" fill={color} />
        )}
      </g>
    );
  };
  return (
    <svg
      width={28 * scale}
      height={20 * scale}
      viewBox="0 0 28 20"
      aria-hidden
      className="shrink-0"
    >
      <rect
        x="0"
        y="0"
        width="28"
        height="20"
        rx="4"
        className="fill-black dark:fill-white"
        opacity={0.08}
      />
      {bar(3.5, session)}
      {bar(11.5, weekly)}
    </svg>
  );
}

function Bar({
  fraction,
  color,
  height = 6,
}: {
  fraction: number;
  color: string;
  height?: number;
}) {
  return (
    <div
      className="relative w-full overflow-hidden rounded-full"
      style={{ height, background: `${color}33` }}
    >
      <div
        className="absolute inset-y-0 left-0 rounded-full transition-[width,background] duration-300"
        style={{
          width: `${Math.min(Math.max(fraction, 0), 1) * 100}%`,
          background: color,
        }}
      />
    </div>
  );
}

function resetLabel(percent: number) {
  if (percent >= 100) return "Resets in 1h 06m";
  return "Resets in 2h 14m";
}

/** A rendering of the app's popover, matching its SwiftUI layout. */
export function UsagePanelMock({
  session,
  weekly,
  initialTab = "usage",
  sessions = sampleSessions,
  className = "",
}: {
  session: number;
  weekly: number;
  initialTab?: "usage" | "sessions";
  sessions?: MockSession[];
  className?: string;
}) {
  const [tab, setTab] = useState(initialTab);
  const text = "text-neutral-900 dark:text-neutral-100";
  const secondary = "text-neutral-500 dark:text-neutral-400";
  const tertiary = "text-neutral-400 dark:text-neutral-500";
  const divider = "border-black/10 dark:border-white/10";
  const chip = "bg-black/[.06] dark:bg-white/10";

  const windowRow = (
    title: string,
    subtitle: string,
    percent: number,
    reset: string,
  ) => {
    const color = levelColor[level(percent)];
    return (
      <div className="flex flex-col gap-1.5">
        <div className="flex items-baseline gap-1.5">
          <span className="text-[13px] font-semibold">{title}</span>
          <span className={`text-[11px] ${secondary}`}>{subtitle}</span>
          <span
            className="ml-auto text-[19px] font-semibold tabular-nums transition-colors"
            style={{
              color,
              fontFamily: "ui-rounded, 'SF Pro Rounded', system-ui",
            }}
          >
            {Math.round(percent)}%
          </span>
        </div>
        <Bar fraction={percent / 100} color={color} />
        <span className={`text-[11px] ${secondary}`}>{reset}</span>
      </div>
    );
  };

  return (
    <div
      className={`w-[320px] max-w-full overflow-hidden rounded-xl text-left font-[system-ui] shadow-[0_20px_60px_-15px_rgba(0,0,0,.35)] ring-1 backdrop-blur-2xl bg-[#f6f6f6]/90 ring-black/10 dark:bg-[#2a2a2c]/90 dark:ring-white/10 ${text} ${className}`}
    >
      <div className="px-4 pt-4">
        <div
          role="tablist"
          className={`grid grid-cols-2 rounded-md p-[2px] text-[12px] bg-black/[.07] dark:bg-white/10`}
        >
          {(["usage", "sessions"] as const).map((value) => (
            <button
              key={value}
              type="button"
              role="tab"
              aria-selected={tab === value}
              onClick={() => setTab(value)}
              className={`rounded-[5px] py-[2px] capitalize transition ${
                tab === value ? "bg-white shadow-sm dark:bg-white/25" : ""
              }`}
            >
              {value}
            </button>
          ))}
        </div>
      </div>

      {tab === "usage" ? (
        <div className="flex flex-col gap-3.5 p-4">
          <div className="flex items-center">
            <span className="text-[13px] font-bold">Claude Usage</span>
            <RefreshIcon className={`ml-auto ${secondary}`} />
          </div>
          <div className={`border-t ${divider}`} />
          <div className="flex items-baseline gap-1.5">
            <span className="text-[12px] font-bold">Personal</span>
            <span className={`text-[11px] ${secondary}`}>~/.claude</span>
            <span
              className={`ml-auto rounded-full px-2 py-px text-[11px] font-medium ${chip}`}
            >
              Max
            </span>
          </div>
          {windowRow("Session", "5 hours", session, resetLabel(session))}
          {windowRow("Weekly", "7 days", weekly, "Resets Thu 9:00 AM")}
          <span className={`text-[10px] ${tertiary}`}>Updated just now</span>
        </div>
      ) : (
        <div className="flex flex-col gap-3.5 p-4">
          <div className="flex items-center gap-2">
            <span className="text-[13px] font-bold">Claude Sessions</span>
            <span
              className={`rounded-full px-2 py-px text-[11px] font-medium ${chip}`}
            >
              {sessions.length}
            </span>
            <RefreshIcon className={`ml-auto ${secondary}`} />
          </div>
          <div className={`border-t ${divider}`} />
          <div className="flex flex-col">
            {sessions.map((item) => {
              const color = levelColor[cacheLevel(item.minutes)];
              return (
                <div
                  key={item.title}
                  className="flex h-[52px] flex-col justify-center gap-[5px]"
                >
                  <div className="flex items-baseline gap-1">
                    <span className="truncate text-[12px] font-semibold">
                      {item.title}
                    </span>
                    <span
                      className="ml-auto shrink-0 text-[12px] font-semibold tabular-nums"
                      style={{ fontFamily: "ui-rounded, system-ui" }}
                    >
                      <span className={secondary}>${item.cost.toFixed(2)}</span>
                      <span className={tertiary}> · </span>
                      <span style={{ color }}>
                        {remainingLabel(item.minutes)}
                      </span>
                    </span>
                  </div>
                  <Bar fraction={item.minutes / 60} color={color} />
                  <span className={`truncate text-[11px] ${secondary}`}>
                    {item.account} · {item.path}
                  </span>
                </div>
              );
            })}
          </div>
          <span className={`text-[10px] leading-snug ${tertiary}`}>
            A session's cache expires 1 hour after its last request. Send a
            message to keep it.
          </span>
        </div>
      )}

      <div className={`border-t ${divider} p-1.5 text-[13px]`}>
        {[
          "Settings…",
          "Check for Updates…",
          "About Claude Usage Bar",
          "Quit Claude Usage Bar",
        ].map((label) => (
          <div
            key={label}
            className="rounded-[5px] px-2.5 py-1 hover:bg-[#0a84ff] hover:text-white"
          >
            {label}
          </div>
        ))}
      </div>
    </div>
  );
}

function RefreshIcon({ className = "" }: { className?: string }) {
  return (
    <svg
      width="13"
      height="13"
      viewBox="0 0 16 16"
      fill="none"
      className={className}
      aria-hidden
    >
      <path
        d="M13.5 8A5.5 5.5 0 1 1 11.8 4"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
      />
      <path
        d="M12.6 1.3v3.4H9.2"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

/** A macOS notification banner. */
export function NotificationMock({
  title,
  subtitle,
  body,
  time = "now",
}: {
  title: string;
  subtitle?: string;
  body: string;
  time?: string;
}) {
  return (
    <div
      className={`flex w-[340px] max-w-full items-start gap-3 rounded-[18px] p-3 text-left font-[system-ui] shadow-[0_10px_30px_-10px_rgba(0,0,0,.35)] ring-1 backdrop-blur-2xl bg-white/75 text-neutral-900 ring-black/5 dark:bg-[#3a3a3c]/80 dark:text-white dark:ring-white/10`}
    >
      <img
        src="/icon-512.png"
        alt=""
        width={36}
        height={36}
        className="mt-0.5 size-9"
      />
      <div className="min-w-0 flex-1 text-[13px] leading-tight">
        <div className="flex items-baseline gap-2">
          <span className="truncate font-semibold">{title}</span>
          <span className="ml-auto shrink-0 text-[11px] opacity-50">
            {time}
          </span>
        </div>
        {subtitle && <div className="truncate font-medium">{subtitle}</div>}
        <div className="truncate opacity-75">{body}</div>
      </div>
    </div>
  );
}
