import {
  useEffect,
  useRef,
  useState,
  type CSSProperties,
  type ReactNode,
} from "react";
import { createFileRoute } from "@tanstack/react-router";
import {
  NotificationMock,
  StatusGlyph,
  UsagePanelMock,
} from "@/components/AppMock";
import {
  archs,
  builds,
  level,
  levelColor,
  releasesUrl,
  repo,
  useDetectedArch,
  useLatestRelease,
  type Arch,
} from "@/site";

export const Route = createFileRoute("/")({ component: Home });

const font =
  "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Inter', 'Helvetica Neue', sans-serif";

type Theme = "system" | "light" | "dark";
const themeKey = "theme";
const themeScript = `try{var t=localStorage.getItem("${themeKey}");if(t==="light"||t==="dark")document.currentScript.parentElement.dataset.theme=t}catch(e){}`;

const secondary = "text-[#6e6e73] dark:text-[#a1a1a6]";
const tertiary = "text-[#86868b] dark:text-[#8e8e93]";
const link = "text-[#0066cc] hover:underline dark:text-[#2997ff]";
const sectionTitle =
  "text-[clamp(2rem,4.5vw,3rem)] leading-[1.08] font-semibold tracking-[-0.025em]";

function useTheme() {
  const [theme, setTheme] = useState<Theme>("system");
  useEffect(() => {
    try {
      const stored = localStorage.getItem(themeKey);
      if (stored === "light" || stored === "dark") setTheme(stored);
    } catch {
      /* storage unavailable */
    }
  }, []);
  const choose = (next: Theme) => {
    setTheme(next);
    try {
      if (next === "system") localStorage.removeItem(themeKey);
      else localStorage.setItem(themeKey, next);
    } catch {
      /* storage unavailable */
    }
  };
  return [theme, choose] as const;
}

function Home() {
  const [session, setSession] = useState(42);
  const [theme, setTheme] = useTheme();
  const weekly = 31;

  return (
    <div
      data-theme={theme}
      suppressHydrationWarning
      className="min-h-dvh bg-white text-[#1d1d1f] antialiased [color-scheme:light] dark:bg-black dark:text-[#f5f5f7] dark:[color-scheme:dark]"
      style={{ fontFamily: font }}
    >
      <script dangerouslySetInnerHTML={{ __html: themeScript }} />
      <Header theme={theme} onTheme={setTheme} />

      <section
        id="top"
        className="mx-auto max-w-5xl px-6 pt-20 pb-10 text-center sm:pt-28"
      >
        <img
          src="/icon-512.png"
          alt=""
          width={112}
          height={112}
          className="mx-auto mb-8 size-24 drop-shadow-xl sm:size-28"
        />
        <h1 className="text-[clamp(2.6rem,7vw,5rem)] leading-[1.02] font-semibold tracking-[-0.035em]">
          Your Claude plan.
          <br />
          <span className="bg-gradient-to-r from-[#0a84ff] via-[#ff9f0a] to-[#ff453a] bg-clip-text text-transparent">
            Always in sight.
          </span>
        </h1>
        <p
          className={`mx-auto mt-6 max-w-xl text-xl leading-relaxed ${secondary}`}
        >
          Claude Usage Bar puts your 5-hour session and weekly limits in the
          macOS menu bar, and tells you before you run out.
        </p>
        <DownloadCluster />
      </section>

      <section className="px-4 pb-28 sm:px-6">
        <Desktop session={session} weekly={weekly} />
        <div className="mx-auto mt-8 flex max-w-md flex-col items-center gap-3">
          <label
            htmlFor="usage-slider"
            className={`text-sm font-medium ${secondary}`}
          >
            Try it: drag to change the session usage
          </label>
          <input
            id="usage-slider"
            type="range"
            min={0}
            max={100}
            value={session}
            onChange={(event) => setSession(Number(event.target.value))}
            className="w-full accent-(--accent)"
            style={{ "--accent": levelColor[level(session)] } as CSSProperties}
          />
          <div className={`flex w-full justify-between text-xs ${tertiary}`}>
            <span>0%</span>
            <span style={{ color: levelColor.warning }}>75%</span>
            <span style={{ color: levelColor.critical }}>100%</span>
          </div>
        </div>
      </section>

      <Tour />
      <Details />
      <GetStarted />
      <Faq />

      <footer
        className={`border-t border-black/10 px-6 py-10 pb-28 text-sm dark:border-white/10 ${tertiary}`}
      >
        <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-4">
          <span>Claude Usage Bar · MIT licensed</span>
          <span>Not affiliated with Anthropic.</span>
          <a className="hover:text-[#1d1d1f] dark:hover:text-white" href={repo}>
            GitHub
          </a>
        </div>
      </footer>
    </div>
  );
}

function Header({
  theme,
  onTheme,
}: {
  theme: Theme;
  onTheme: (theme: Theme) => void;
}) {
  return (
    <header className="sticky top-[env(safe-area-inset-top,0px)] z-40 border-b border-black/5 bg-white/75 backdrop-blur-xl dark:border-white/10 dark:bg-black/70">
      <div className="mx-auto flex h-12 max-w-5xl items-center gap-5 px-6 text-sm">
        <a href="#top" className="flex items-center gap-2 font-semibold">
          <img src="/icon-512.png" alt="" width={22} height={22} />
          <span className="hidden min-[400px]:inline">Claude Usage Bar</span>
        </a>
        <nav className="ml-auto hidden gap-6 text-[#424245] md:flex dark:text-[#d1d1d6]">
          <a
            href="#features"
            className="hover:text-black dark:hover:text-white"
          >
            Features
          </a>
          <a
            href="#download"
            className="hover:text-black dark:hover:text-white"
          >
            Install
          </a>
          <a href="#faq" className="hover:text-black dark:hover:text-white">
            FAQ
          </a>
          <a href={repo} className="hover:text-black dark:hover:text-white">
            GitHub
          </a>
        </nav>
        <ThemeToggle theme={theme} onTheme={onTheme} />
        <a
          href="#download"
          className="rounded-full bg-[#0071e3] px-3.5 py-1 text-white hover:bg-[#0077ed]"
        >
          Download
        </a>
      </div>
    </header>
  );
}

function ThemeToggle({
  theme,
  onTheme,
}: {
  theme: Theme;
  onTheme: (theme: Theme) => void;
}) {
  const options: { value: Theme; label: string; icon: ReactNode }[] = [
    {
      value: "system",
      label: "Match system",
      icon: (
        <path
          d="M2.5 3.5h11v7.5h-11ZM6 13.5h4M8 11v2.5"
          strokeLinejoin="round"
        />
      ),
    },
    {
      value: "light",
      label: "Light",
      icon: (
        <>
          <circle cx="8" cy="8" r="2.8" />
          <path d="M8 1.5v1.6M8 12.9v1.6M1.5 8h1.6M12.9 8h1.6M3.4 3.4l1.1 1.1M11.5 11.5l1.1 1.1M3.4 12.6l1.1-1.1M11.5 4.5l1.1-1.1" />
        </>
      ),
    },
    {
      value: "dark",
      label: "Dark",
      icon: <path d="M13 9.6A5.5 5.5 0 0 1 6.4 3a5.5 5.5 0 1 0 6.6 6.6Z" />,
    },
  ];
  return (
    <div
      role="radiogroup"
      aria-label="Theme"
      className="ml-auto flex rounded-full bg-black/[.05] p-0.5 md:ml-0 dark:bg-white/10"
    >
      {options.map((option) => (
        <button
          key={option.value}
          type="button"
          role="radio"
          aria-checked={theme === option.value}
          aria-label={option.label}
          title={option.label}
          onClick={() => onTheme(option.value)}
          className={`grid size-6 place-items-center rounded-full transition ${
            theme === option.value
              ? "bg-white text-black shadow-sm dark:bg-white/25 dark:text-white"
              : "text-[#6e6e73] hover:text-black dark:text-[#a1a1a6] dark:hover:text-white"
          }`}
        >
          <svg
            width="14"
            height="14"
            viewBox="0 0 16 16"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.4"
            strokeLinecap="round"
            aria-hidden
          >
            {option.icon}
          </svg>
        </button>
      ))}
    </div>
  );
}

function DownloadCluster() {
  const arch = useDetectedArch();
  const release = useLatestRelease();
  const primary = builds[arch];
  return (
    <div className="mt-10 flex flex-col items-center gap-4">
      <a
        href={primary.url}
        className="inline-flex items-center gap-2.5 rounded-full bg-[#0071e3] px-7 py-3.5 text-lg font-medium text-white shadow-lg shadow-blue-500/20 transition hover:bg-[#0077ed]"
      >
        <AppleLogo className="-mt-0.5 size-5" />
        Download for {arch === "universal" ? "Mac" : primary.label}
      </a>
      <p className={`text-sm ${tertiary}`}>
        {release ? `${release.version} · ${release.date} · ` : ""}macOS 14 or
        later · Requires a Pro or Max plan
      </p>
      <p className="text-sm text-[#424245] dark:text-[#d1d1d6]">
        Also for{" "}
        {archs
          .filter((other) => other !== arch)
          .map((other, i) => (
            <span key={other}>
              {i > 0 && " and "}
              <a href={builds[other].url} className={link}>
                {builds[other].label}
              </a>
            </span>
          ))}
      </p>
    </div>
  );
}

const wallpaper =
  "bg-[radial-gradient(90%_80%_at_15%_10%,#7fb6ff_0%,transparent_60%),radial-gradient(80%_70%_at_90%_20%,#ffb37a_0%,transparent_55%),radial-gradient(90%_90%_at_60%_100%,#c48cff_0%,transparent_60%),linear-gradient(#e8eefc,#f7e8ef)] dark:bg-[radial-gradient(90%_80%_at_15%_10%,#1d4f9a_0%,transparent_60%),radial-gradient(80%_70%_at_90%_20%,#7a3d1c_0%,transparent_55%),radial-gradient(90%_90%_at_60%_100%,#4b2a7a_0%,transparent_60%),linear-gradient(#0e1424,#1a1220)]";

function MenuBar({ children }: { children: ReactNode }) {
  return (
    <div className="relative flex h-7 items-center gap-4 bg-white/40 px-4 text-[13px] backdrop-blur-xl dark:bg-black/35 dark:text-white">
      <AppleLogo className="size-3.5" />
      <span className="font-semibold">Terminal</span>
      <span className="hidden sm:inline">File</span>
      <span className="hidden sm:inline">Edit</span>
      <span className="hidden sm:inline">View</span>
      <span className="hidden md:inline">Window</span>
      <span className="ml-auto flex items-center gap-3">{children}</span>
      <span className="hidden sm:inline">
        <WifiIcon />
      </span>
      <span className="hidden tabular-nums sm:inline">Wed 14 Oct 18:04</span>
    </div>
  );
}

function Desktop({ session, weekly }: { session: number; weekly: number }) {
  return (
    <div className="relative mx-auto max-w-5xl overflow-hidden rounded-[1.75rem] shadow-[0_40px_100px_-40px_rgba(0,40,120,.45)] ring-1 ring-black/10 dark:ring-white/10">
      <div className={`absolute inset-0 ${wallpaper}`} />
      <MenuBar>
        <span className="flex items-center gap-1.5 rounded-[5px] bg-black/10 px-1.5 py-0.5 dark:bg-white/15">
          <StatusGlyph session={session} weekly={weekly} scale={0.9} />
          <span className="text-[12px] font-medium tabular-nums">
            {Math.round(session)}% {weekly}%
          </span>
        </span>
      </MenuBar>
      <div className="relative flex min-h-[560px] justify-end gap-8 p-4 sm:pr-16">
        <ClaudeCodeSession session={session} weekly={weekly} />
        <div className="relative shrink-0">
          <div className="absolute -top-2 left-1/2 size-4 -translate-x-1/2 rotate-45 rounded-sm bg-[#f6f6f6]/90 dark:bg-[#2a2a2c]/90" />
          <UsagePanelMock session={session} weekly={weekly} />
        </div>
      </div>
    </div>
  );
}

const mascot = [
  ".#########.",
  ".##.###.##.",
  ".##.###.##.",
  "###########",
  ".#########.",
  ".#.#...#.#.",
  ".#.#...#.#.",
];

function Mascot() {
  return (
    <svg
      viewBox="0 0 11 7"
      className="h-[42px] w-[66px] shrink-0"
      shapeRendering="crispEdges"
      aria-hidden
    >
      {mascot.flatMap((row, y) =>
        [...row].map((cell, x) =>
          cell === "#" ? (
            <rect
              key={`${x}-${y}`}
              x={x}
              y={y}
              width={1.02}
              height={1.02}
              fill="#d97757"
            />
          ) : null,
        ),
      )}
    </svg>
  );
}

const spinnerFrames = ["·", "✢", "✳", "✶", "✻", "✽", "✻", "✶", "✳", "✢"];

function useSpinner() {
  const [frame, setFrame] = useState(4);
  const [seconds, setSeconds] = useState(134);
  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const spin = window.setInterval(
      () => setFrame((f) => (f + 1) % spinnerFrames.length),
      120,
    );
    const tick = window.setInterval(() => setSeconds((t) => t + 1), 1000);
    return () => {
      window.clearInterval(spin);
      window.clearInterval(tick);
    };
  }, []);
  return {
    glyph: spinnerFrames[frame],
    elapsed: `${Math.floor(seconds / 60)}m ${seconds % 60}s`,
  };
}

function ClaudeCodeSession({
  session,
  weekly,
}: {
  session: number;
  weekly: number;
}) {
  const { glyph, elapsed } = useSpinner();
  return (
    <div className="hidden max-w-[560px] min-w-0 flex-1 self-start overflow-hidden rounded-xl bg-[#0c0c0c]/95 font-mono text-[11.5px] leading-[1.6] text-[#d4d4d4] shadow-2xl ring-1 ring-black/40 md:mt-10 md:block lg:ml-4">
      <div className="flex h-7 items-center gap-1.5 border-b border-white/10 bg-[#1a1a1a] px-3">
        <span className="size-3 rounded-full bg-[#ff5f57]" />
        <span className="size-3 rounded-full bg-[#febc2e]" />
        <span className="size-3 rounded-full bg-[#28c840]" />
        <span className="flex-1 pr-10 text-center font-sans text-[11px] text-white/45">
          claude — ~/Projects/shop
        </span>
      </div>
      <div className="px-4 pt-4 pb-3">
        <div className="flex items-center gap-4">
          <Mascot />
          <div className="min-w-0">
            <p className="truncate">
              <span className="font-bold text-[#4ade80]">Claude Code</span>{" "}
              <span className="text-[#a3a3a3]">v2.1.299</span>
            </p>
            <p className="truncate text-[#a3a3a3]">
              Opus 5.5 with medium effort · Claude Max
            </p>
            <p className="truncate text-[#a3a3a3]">~/Projects/shop</p>
          </div>
        </div>

        <p className="mt-4 truncate bg-white/[.06] px-2 py-0.5">
          <span className="text-[#a3a3a3]">&gt;</span> add retries to the
          billing webhooks
        </p>

        <div className="mt-3 space-y-1">
          <p className="truncate">
            <span className="text-[#4ade80]">⏺</span>{" "}
            <span className="font-bold">Read</span>
            <span className="text-[#a3a3a3]">(src/billing/webhooks.ts)</span>
          </p>
          <p className="truncate pl-3 text-[#8a8a8a]">⎿ Read 214 lines</p>
          <p className="truncate">
            <span className="text-[#4ade80]">⏺</span>{" "}
            <span className="font-bold">Update</span>
            <span className="text-[#a3a3a3]">(src/billing/events.ts)</span>
          </p>
          <p className="truncate pl-3 text-[#8a8a8a]">
            ⎿ Updated with <span className="text-[#4ade80]">18 additions</span>{" "}
            and <span className="text-[#f87171]">4 removals</span>
          </p>
          <p className="truncate">
            <span className="text-[#4ade80]">⏺</span> Retries now back off
            exponentially, up to 5 attempts.
          </p>
        </div>

        <p className="mt-3 truncate">
          <span className="inline-block w-3 text-[#d97757]">{glyph}</span>
          <span className="text-[#d97757]">
            Writing tests for the retry path…
          </span>{" "}
          <span className="text-[#8a8a8a]">({elapsed} · esc to interrupt)</span>
        </p>

        <div className="mt-4 border-y border-white/25 py-1.5">
          <span className="text-[#4ade80]">❯</span>{" "}
          <span className="inline-block h-3.5 w-2 translate-y-0.5 animate-pulse bg-[#4ade80]" />
        </div>

        <p className="mt-2 truncate">
          <span className="text-[#22d3ee]">~/Projects/shop</span>
          <span className="text-[#525252]"> | </span>
          <span className="text-[#e879f9]">main</span>
          <span className="text-[#525252]"> | </span>
          <span className="text-[#60a5fa]">Opus 5.5</span>
          <span className="text-[#525252]"> | </span>
          <span
            className="transition-colors"
            style={{ color: levelColor[level(session)] }}
          >
            5h:{Math.round(session)}%
          </span>{" "}
          <span style={{ color: levelColor[level(weekly)] }}>7d:{weekly}%</span>
          <span className="text-[#525252]"> | </span>
          <span className="text-[#a3a3a3]">$4.82</span>
        </p>
        <p className="mt-1 truncate">
          <span className="text-[#facc15]">⏵⏵ auto mode on</span>{" "}
          <span className="text-[#8a8a8a]">(shift+tab to cycle)</span>
        </p>
      </div>
    </div>
  );
}

const tourSteps = [
  {
    eyebrow: "At a glance",
    eyebrowColor: levelColor.ok,
    title: "Two bars. Every answer.",
    body: "The top bar is your 5-hour session, the bottom bar is the week. They turn orange at 75% and red at the limit, so a glance at the menu bar is all it takes. Click for exact numbers and reset times.",
  },
  {
    eyebrow: "Notifications",
    eyebrowColor: levelColor.warning,
    title: "A heads-up, not a hard stop.",
    body: "Notifications at 75, 80, 85, 90, 95 and 100 percent of the session or week. If usage jumps past several marks between two checks, you get one, for the highest.",
  },
  {
    eyebrow: "Sessions",
    eyebrowColor: "#30d158",
    title: "Keep your prompt cache warm.",
    body: "A session’s prompt cache expires an hour after its last request, and the next message rewrites the whole context at a higher price. The Sessions tab shows every running session’s cache and cost, and you’re notified 5 minutes before one expires.",
  },
  {
    eyebrow: "Accounts",
    eyebrowColor: "#bf5af2",
    title: "Every subscription, side by side.",
    body: "Each Claude Code config folder is an account: ~/.claude, ~/.claude-work and so on. Name them and pick which ones get a menu bar item. A logged-out account shows the command to log back in.",
  },
];

function TourVisual({ index }: { index: number }) {
  if (index === 0) {
    return (
      <div className="flex flex-col items-center gap-8">
        <div className="grid grid-cols-[auto_auto] items-center gap-x-5 gap-y-3">
          <StatusGlyph session={58} weekly={31} scale={5} />
          <div className="flex flex-col gap-10 text-sm">
            <span>
              <span className="font-semibold">Session</span>
              <span className={`block ${secondary}`}>5 hours · 58%</span>
            </span>
            <span>
              <span className="font-semibold">Week</span>
              <span className={`block ${secondary}`}>7 days · 31%</span>
            </span>
          </div>
        </div>
        <div className="flex gap-6">
          {(
            [
              [42, 20, "Under 75%"],
              [88, 54, "75–99%"],
              [100, 72, "Limit"],
            ] as const
          ).map(([s, w, label]) => (
            <div key={label} className="flex flex-col items-center gap-2">
              <span className="rounded-lg bg-white/60 p-2 dark:bg-black/30">
                <StatusGlyph session={s} weekly={w} scale={1.6} />
              </span>
              <span className={`text-xs ${secondary}`}>{label}</span>
            </div>
          ))}
        </div>
      </div>
    );
  }
  if (index === 1) {
    return (
      <div className="flex w-full flex-col items-center gap-3">
        <NotificationMock
          title="Session usage at 85%"
          subtitle="Personal"
          body="Resets in 1h 42m"
        />
        <NotificationMock
          title="Weekly usage at 75%"
          subtitle="Work"
          body="Resets Thu 9:00 AM"
          time="1h ago"
        />
        <NotificationMock
          title="Session limit reached"
          subtitle="Personal"
          body="Resets in 1h 06m"
          time="2h ago"
        />
      </div>
    );
  }
  if (index === 2) {
    return (
      <div className="flex flex-col items-center gap-3">
        <NotificationMock
          title="Prompt cache expires in 5m"
          subtitle="Personal · Draft release notes"
          body="~/Projects/claude-usage-bar"
        />
        <UsagePanelMock session={58} weekly={31} initialTab="sessions" />
      </div>
    );
  }
  return <AccountsVisual />;
}

function AccountsVisual() {
  const accounts = [
    { name: "Personal", path: "~/.claude", session: 58, weekly: 31, on: true },
    { name: "Work", path: "~/.claude-work", session: 81, weekly: 64, on: true },
    {
      name: "Client",
      path: "~/.claude-client",
      session: 12,
      weekly: 9,
      on: false,
    },
  ];
  return (
    <div className="flex w-full max-w-md flex-col gap-4">
      <div className="flex h-8 items-center justify-end gap-3 rounded-lg bg-white/50 px-3 text-[12px] font-medium backdrop-blur dark:bg-black/40">
        {accounts
          .filter((account) => account.on)
          .map((account, i) => (
            <span
              key={account.name}
              className="flex items-center gap-1.5 whitespace-nowrap"
            >
              {i > 0 && (
                <span className="mr-1.5 h-3 w-px bg-black/25 dark:bg-white/30" />
              )}
              <StatusGlyph
                session={account.session}
                weekly={account.weekly}
                scale={0.9}
              />
              {account.name}{" "}
              <span className="hidden tabular-nums sm:inline">
                {account.session}% {account.weekly}%
              </span>
            </span>
          ))}
      </div>
      <div className="overflow-hidden rounded-xl bg-[#f6f6f6]/95 text-[13px] shadow-xl ring-1 ring-black/10 dark:bg-[#2a2a2c]/95 dark:ring-white/10">
        <div className="border-b border-black/10 px-4 py-2.5 font-semibold dark:border-white/10">
          Accounts
        </div>
        {accounts.map((account) => (
          <div
            key={account.name}
            className="flex items-center gap-3 border-b border-black/5 px-4 py-2.5 last:border-0 dark:border-white/5"
          >
            <span className="w-20 shrink-0 rounded-md bg-white px-2 py-0.5 ring-1 ring-black/10 dark:bg-white/10 dark:ring-white/10">
              {account.name}
            </span>
            <span className={`truncate text-[11px] ${secondary}`}>
              {account.path}
            </span>
            <span className="ml-auto flex shrink-0 items-center gap-1.5 text-[12px] whitespace-nowrap">
              <span
                className={`grid size-3.5 place-items-center rounded-[4px] text-[10px] text-white ${
                  account.on
                    ? "bg-[#0a84ff]"
                    : "bg-white ring-1 ring-black/20 dark:bg-white/10 dark:ring-white/20"
                }`}
              >
                {account.on ? "✓" : ""}
              </span>
              Menu bar
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

function Tour() {
  const [active, setActive] = useState(0);
  const refs = useRef<(HTMLDivElement | null)[]>([]);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            setActive(Number((entry.target as HTMLElement).dataset.step));
          }
        }
      },
      { rootMargin: "-45% 0px -45% 0px" },
    );
    refs.current.forEach((node) => node && observer.observe(node));
    return () => observer.disconnect();
  }, []);

  return (
    <section
      id="features"
      className="scroll-mt-12 bg-[#f5f5f7] px-6 py-28 dark:bg-[#101012]"
    >
      <div className="mx-auto max-w-5xl">
        <h2 className={`max-w-2xl ${sectionTitle}`}>
          Built for the way you use Claude Code.
        </h2>
        <div className="mt-16 grid gap-16 lg:grid-cols-[1fr_1.15fr]">
          <div className="flex min-w-0 flex-col gap-24 lg:gap-0">
            {tourSteps.map((step, i) => (
              <div
                key={step.title}
                ref={(node) => {
                  refs.current[i] = node;
                }}
                data-step={i}
                className={`min-w-0 transition-opacity duration-500 lg:flex lg:min-h-[78vh] lg:flex-col lg:justify-center ${
                  active === i ? "lg:opacity-100" : "lg:opacity-30"
                }`}
              >
                <p
                  className="text-sm font-semibold"
                  style={{ color: step.eyebrowColor }}
                >
                  {step.eyebrow}
                </p>
                <h3 className="mt-2 text-[clamp(1.6rem,3vw,2.2rem)] leading-tight font-semibold tracking-[-0.02em]">
                  {step.title}
                </h3>
                <p
                  className={`mt-4 max-w-md text-lg leading-relaxed ${secondary}`}
                >
                  {step.body}
                </p>
                <div
                  className={`mt-8 flex min-h-96 items-center justify-center overflow-hidden rounded-3xl p-6 lg:hidden ${wallpaper}`}
                >
                  <TourVisual index={i} />
                </div>
              </div>
            ))}
          </div>
          <div className="hidden lg:block">
            <div
              className={`sticky top-[calc(50vh-19rem)] grid h-[38rem] place-items-center overflow-hidden rounded-[2rem] p-8 shadow-[0_30px_80px_-40px_rgba(0,30,90,.35)] ring-1 ring-black/5 dark:ring-white/10 ${wallpaper}`}
            >
              {tourSteps.map((step, i) => (
                <div
                  key={step.title}
                  aria-hidden={active !== i}
                  className={`col-start-1 row-start-1 flex w-full justify-center transition duration-500 ${
                    active === i
                      ? "translate-y-0 opacity-100"
                      : "pointer-events-none translate-y-4 opacity-0"
                  }`}
                >
                  <TourVisual index={i} />
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

const details: { title: string; body: string; icon: ReactNode }[] = [
  {
    title: "Updates itself",
    body: "Checks daily and installs new releases from the panel, verified by Sparkle.",
    icon: <path d="M10 3v9m0 0 3.5-3.5M10 12 6.5 8.5M4 16h12" />,
  },
  {
    title: "No extra login",
    body: "Reads the token Claude Code keeps in your keychain and never refreshes it, so Claude Code stays signed in.",
    icon: (
      <>
        <rect x="4.5" y="9" width="11" height="7.5" rx="2" />
        <path d="M7 9V6.5a3 3 0 0 1 6 0V9" />
      </>
    ),
  },
  {
    title: "Your refresh rate",
    body: "Checks usage every 3 minutes by default. Pick anything from 1 to 15 in Settings.",
    icon: (
      <>
        <circle cx="10" cy="10" r="6.5" />
        <path d="M10 6.5V10l2.5 1.5" />
      </>
    ),
  },
  {
    title: "As quiet as you like",
    body: "Show or hide account names and percentages next to the bars, and turn either kind of notification off.",
    icon: <path d="M4 6h12M4 10h12M4 14h7" />,
  },
  {
    title: "Launch at login",
    body: "Starts with your Mac and lives only in the menu bar. No Dock icon, no windows in the way.",
    icon: (
      <>
        <rect x="3.5" y="4.5" width="13" height="9" rx="1.5" />
        <path d="M7.5 16.5h5" />
      </>
    ),
  },
  {
    title: "Open source",
    body: "MIT licensed Swift. Read exactly what it does, or build it yourself with make install.",
    icon: <path d="m7.5 6-4 4 4 4M12.5 6l4 4-4 4" />,
  },
];

function Details() {
  return (
    <section className="px-6 py-28">
      <div className="mx-auto max-w-5xl">
        <h2 className={sectionTitle}>
          The little things.{" "}
          <span className="text-[#86868b] dark:text-[#6e6e73]">
            Done right.
          </span>
        </h2>
        <div className="mt-14 grid gap-x-10 gap-y-12 sm:grid-cols-2 lg:grid-cols-3">
          {details.map((detail) => (
            <div key={detail.title}>
              <svg
                width="28"
                height="28"
                viewBox="0 0 20 20"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="round"
                strokeLinejoin="round"
                className="text-[#0071e3] dark:text-[#2997ff]"
                aria-hidden
              >
                {detail.icon}
              </svg>
              <h3 className="mt-4 font-semibold">{detail.title}</h3>
              <p className={`mt-1.5 leading-relaxed ${secondary}`}>
                {detail.body}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

const archNotes: Record<Arch, string> = {
  arm64: "M1 and later",
  x86_64: "Intel processors",
  universal: "Any Mac, larger download",
};

function GetStarted() {
  const detected = useDetectedArch();
  const [picked, setPicked] = useState<Arch | null>(null);
  const arch = picked ?? detected;
  return (
    <section
      id="download"
      className="scroll-mt-12 bg-[#f5f5f7] px-6 py-28 dark:bg-[#101012]"
    >
      <div className="mx-auto max-w-3xl text-center">
        <img
          src="/icon-512.png"
          alt=""
          width={80}
          height={80}
          className="mx-auto size-20 drop-shadow-lg"
        />
        <h2 className={`mt-6 ${sectionTitle}`}>Get Claude Usage Bar.</h2>
        <p className={`mt-3 text-lg ${secondary}`}>
          Free. macOS 14 or later. Claude Code with a Pro or Max plan.
        </p>

        <div
          role="radiogroup"
          aria-label="Mac type"
          className="mt-10 grid gap-3 sm:grid-cols-3"
        >
          {archs.map((option) => {
            const selected = option === arch;
            return (
              <button
                key={option}
                type="button"
                role="radio"
                aria-checked={selected}
                onClick={() => setPicked(option)}
                className={`rounded-2xl bg-white p-5 text-left ring-2 transition dark:bg-[#1c1c1e] ${
                  selected
                    ? "ring-[#0071e3] dark:ring-[#2997ff]"
                    : "ring-transparent hover:ring-black/10 dark:hover:ring-white/15"
                }`}
              >
                <span className="flex items-center justify-between">
                  <span className="font-semibold">{builds[option].label}</span>
                  <span
                    className={`grid size-5 place-items-center rounded-full ring-1 ${
                      selected
                        ? "bg-[#0071e3] ring-[#0071e3] dark:bg-[#2997ff] dark:ring-[#2997ff]"
                        : "ring-black/20 dark:ring-white/25"
                    }`}
                  >
                    {selected && (
                      <span className="size-2 rounded-full bg-white" />
                    )}
                  </span>
                </span>
                <span className={`mt-1 block text-sm ${secondary}`}>
                  {archNotes[option]}
                  {option === detected && option !== "universal"
                    ? " · This Mac"
                    : ""}
                </span>
              </button>
            );
          })}
        </div>

        <a
          href={builds[arch].url}
          className="mt-8 inline-flex items-center gap-2.5 rounded-full bg-[#0071e3] px-7 py-3.5 text-lg font-medium text-white shadow-lg shadow-blue-500/20 transition hover:bg-[#0077ed]"
        >
          <AppleLogo className="-mt-0.5 size-5" />
          Download for {builds[arch].label}
        </a>
      </div>

      <p className={`mt-12 text-center text-sm ${tertiary}`}>
        Looking for an older version?{" "}
        <a href={releasesUrl} className={link}>
          All releases
        </a>
      </p>
    </section>
  );
}

const faqs = [
  {
    q: "Where do the numbers come from?",
    a: "From the same plan usage endpoint Claude Code’s /usage command reads, using the token Claude Code already stores in your keychain. The endpoint is undocumented, so it may change without notice.",
  },
  {
    q: "Will it log me out of Claude Code?",
    a: "No. The app reads the token but never refreshes it, because refreshing would rotate it and log Claude Code out. When the token expires, the app keeps the last values and asks you to run claude.",
  },
  {
    q: "Why do I need the quarantine command?",
    a: "The app isn’t notarized by Apple, so macOS blocks the first launch of a downloaded copy. Clearing the quarantine flag once lets it open. Updates are verified with Sparkle’s EdDSA signatures.",
  },
  {
    q: "Which download should I pick?",
    a: "Apple Silicon for M-series Macs, Intel for Intel Macs. Universal runs on both; it updates to the build for the architecture it runs as.",
  },
  {
    q: "Why can a session cost read lower than Claude Code’s?",
    a: "Costs are estimated at API prices from the token usage in the session’s transcripts. Subagent transcripts often keep only the usage reported when a response started, and a few requests aren’t recorded at all.",
  },
  {
    q: "Does the cache timer cover paid overage?",
    a: "No. Sessions in paid usage overage use a 5-minute cache, which the timers don’t account for.",
  },
];

function Faq() {
  return (
    <section id="faq" className="scroll-mt-12 px-6 py-28">
      <div className="mx-auto grid max-w-5xl gap-12 lg:grid-cols-[1fr_1.6fr]">
        <h2 className={sectionTitle}>Questions, answered.</h2>
        <div className="divide-y divide-black/10 border-y border-black/10 dark:divide-white/10 dark:border-white/10">
          {faqs.map((faq) => (
            <details key={faq.q} className="group py-5">
              <summary className="flex cursor-pointer list-none items-center justify-between gap-6 text-lg font-medium [&::-webkit-details-marker]:hidden">
                {faq.q}
                <span
                  className={`shrink-0 text-2xl leading-none transition group-open:rotate-45 ${tertiary}`}
                  aria-hidden
                >
                  +
                </span>
              </summary>
              <p className={`mt-3 max-w-xl leading-relaxed ${secondary}`}>
                {faq.a}
              </p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}

function AppleLogo({ className = "" }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 17 20"
      fill="currentColor"
      className={className}
      aria-hidden
    >
      <path d="M14.1 10.6c0-2.6 2.1-3.8 2.2-3.9-1.2-1.8-3.1-2-3.7-2-1.6-.2-3.1.9-3.9.9-.8 0-2-.9-3.4-.9-1.7 0-3.3 1-4.2 2.6-1.8 3.1-.5 7.7 1.3 10.2.9 1.2 1.9 2.6 3.2 2.6 1.3-.1 1.8-.8 3.3-.8 1.6 0 2 .8 3.4.8 1.4 0 2.3-1.3 3.1-2.5 1-1.4 1.4-2.8 1.4-2.9-.1 0-2.7-1-2.7-4.1ZM11.6 3c.7-.9 1.2-2 1-3.2-1 0-2.3.7-3 1.6-.7.8-1.3 2-1.1 3.1 1.1.1 2.3-.6 3.1-1.5Z" />
    </svg>
  );
}

function WifiIcon() {
  return (
    <svg
      width="15"
      height="11"
      viewBox="0 0 15 11"
      fill="currentColor"
      aria-hidden
    >
      <path d="M7.5 2.3c2 0 3.9.8 5.3 2.1l1.1-1.1A9 9 0 0 0 7.5.8 9 9 0 0 0 1.1 3.3l1.1 1.1A7.6 7.6 0 0 1 7.5 2.3Zm0 3c1.2 0 2.3.5 3.2 1.2l1.1-1.1a6 6 0 0 0-8.6 0l1.1 1.1c.9-.7 2-1.2 3.2-1.2Zm0 3c-.4 0-.8.2-1.1.4l1.1 1.2 1.1-1.2c-.3-.2-.7-.4-1.1-.4Z" />
    </svg>
  );
}
