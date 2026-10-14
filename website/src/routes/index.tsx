import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/")({ component: Home });

const repo = "https://github.com/abderra7mane/claude-usage-bar";
const download = `${repo}/releases/latest/download`;

const downloads = [
  { label: "Apple Silicon", file: "ClaudeUsageBar-arm64.dmg" },
  { label: "Intel", file: "ClaudeUsageBar-x86_64.dmg" },
  { label: "Universal", file: "ClaudeUsageBar-universal.dmg" },
];

const features = [
  {
    title: "Session and week at a glance",
    body: "The top bar is the 5-hour session, the bottom bar is the week. Blue below 75%, orange up to 99%, red at the limit.",
  },
  {
    title: "Alerts before the limit",
    body: "Notifies you at 75%, 80%, 85%, 90%, 95% and 100%, once for the highest threshold crossed between two checks.",
  },
  {
    title: "Prompt cache timers",
    body: "The Sessions tab shows how long each running session's prompt cache has left and what the session cost, with an alert 5 minutes before it expires.",
  },
  {
    title: "Multiple subscriptions",
    body: "One account per Claude Code config folder, such as ~/.claude and ~/.claude-work, each with its own menu bar item.",
  },
];

function Home() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-3xl flex-col items-center gap-16 px-6 py-20 text-center font-sans">
      <section className="flex flex-col items-center gap-4">
        <img src="/icon-512.png" alt="" width={128} height={128} />
        <h1 className="text-4xl font-semibold">Claude Usage Bar</h1>
        <p className="max-w-xl text-lg text-neutral-600">
          Your Claude Code plan usage in the macOS menu bar.
        </p>
        <div className="mt-4 flex flex-wrap justify-center gap-3">
          {downloads.map(({ label, file }) => (
            <a
              key={file}
              className="rounded-lg bg-neutral-900 px-4 py-2 text-white hover:bg-neutral-700"
              href={`${download}/${file}`}
            >
              Download for {label}
            </a>
          ))}
        </div>
        <p className="text-sm text-neutral-500">
          Free and open source · macOS 14+ · Pro or Max subscription
        </p>
      </section>

      <section className="grid gap-8 text-left sm:grid-cols-2">
        {features.map(({ title, body }) => (
          <div key={title}>
            <h2 className="font-semibold">{title}</h2>
            <p className="mt-1 text-neutral-600">{body}</p>
          </div>
        ))}
      </section>

      <section className="flex w-full flex-col gap-3 text-left">
        <h2 className="font-semibold">Install</h2>
        <p className="text-neutral-600">
          Open the DMG and drag the app to Applications. The app isn't
          notarized, so clear the quarantine flag before the first launch:
        </p>
        <pre className="overflow-x-auto rounded-lg bg-neutral-100 p-4 text-sm">
          <code>
            xattr -dr com.apple.quarantine /Applications/ClaudeUsageBar.app
          </code>
        </pre>
        <p className="text-neutral-600">
          The app checks for updates daily and installs them from its panel.
        </p>
      </section>

      <a className="underline underline-offset-4" href={repo}>
        GitHub
      </a>
    </main>
  );
}
