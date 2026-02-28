import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'fyi.imdaniel.smalltools',
  appName: 'Small Tools',
  webDir: 'www',
  server: {
    androidScheme: 'https',
  },
  ios: {
    contentInset: 'automatic',
    // The URL scheme 'smalltools' is also registered in Info.plist
    // to support deep links from Siri Shortcuts: smalltools://open/{slug}
  },
  plugins: {
    AppShortcuts: {
      // Initial quick actions (before any tools are synced)
      shortcuts: [],
    },
  },
};

export default config;
