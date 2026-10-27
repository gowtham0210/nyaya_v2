import type { Metadata } from 'next';
import { DM_Serif_Display, Geist } from 'next/font/google';
import './globals.css';

const sans = Geist({ variable: '--font-geist-sans', subsets: ['latin'] });
const serif = DM_Serif_Display({ variable: '--font-serif', weight: '400', subsets: ['latin'] });

export const metadata: Metadata = {
  title: { default: 'Nyaya CMS', template: '%s · Nyaya CMS' },
  description: 'Author, review and publish Nyaya questions',
};

export default function RootLayout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="en" className={`${sans.variable} ${serif.variable} h-full antialiased`}>
      <body className="flex min-h-full flex-col font-sans">{children}</body>
    </html>
  );
}
