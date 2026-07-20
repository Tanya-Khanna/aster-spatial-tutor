import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://aster-spatial-tutor.tanyak897.chatgpt.site"),
  title: "Aster✱ — The spatial tutor for macOS",
  description:
    "Don’t bring your question to the tutor. Bring the tutor to your question. Aster✱ explains aloud, draws where it matters, and remembers what needs practice.",
  openGraph: {
    title: "Aster✱ — The spatial tutor for macOS",
    description: "Point. Learn. Master. Aster✱ turns your screen into a whiteboard.",
    type: "website",
    images: [{ url: "/og.png", width: 1536, height: 1024, alt: "Aster star spatial tutor teaching over an equation and anatomy diagram" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "Aster✱ — The spatial tutor for macOS",
    description: "Point. Learn. Master. Aster✱ turns your screen into a whiteboard.",
    images: ["/og.png"],
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
