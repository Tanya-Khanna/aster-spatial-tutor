import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://aster-spatial-tutor.tanyak897.chatgpt.site"),
  title: "Aster — Your screen becomes the whiteboard",
  description:
    "A spatial AI tutor for macOS that sees what you see, teaches by voice, and draws explanations exactly where they belong.",
  openGraph: {
    title: "Aster — Your screen becomes the whiteboard",
    description: "Point at an equation, figure, or diagram. Aster teaches right on your screen.",
    type: "website",
    images: [{ url: "/og.png", width: 1536, height: 1024, alt: "Aster spatial tutor teaching over an equation and anatomy diagram" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "Aster — Your screen becomes the whiteboard",
    description: "A spatial AI tutor for macOS.",
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
