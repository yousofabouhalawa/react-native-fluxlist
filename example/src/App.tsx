import { memo, useMemo } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { FluxListView } from 'react-native-fluxlist';

const ITEM_COUNT = 100_000;
const CARD_HEIGHT = 412;
const MEDIA_TILES = Array.from({ length: 18 }, (_, index) => index);
const DATA = Array.from({ length: ITEM_COUNT }, (_, index) => index);

const AUTHORS = [
  'Mira Chen',
  'Design Systems',
  'Noah Patel',
  'Motion Lab',
  'Ava Studio',
  'Field Notes',
  'Product Ops',
  'Nora Vale',
];

const LOCATIONS = [
  'Tokyo',
  'Cairo',
  'Berlin',
  'New York',
  'Lisbon',
  'Seoul',
  'San Francisco',
  'Dubai',
];

const CAPTIONS = [
  'Layered media, dense metadata, and fast gesture surfaces in one reusable card.',
  'A brutal feed row built to make bad virtualization obvious during fast scrolls.',
  'Synthetic photos, badges, counters, shadows, and text blocks with stable height.',
  'The list owns 100k rows while React only mounts a compact native-driven window.',
];

const COLORS = [
  '#E64A5F',
  '#FFB84D',
  '#35C2A1',
  '#3478F6',
  '#7C5CFF',
  '#111827',
  '#F4F0E6',
  '#2F6F73',
  '#D8A31A',
  '#A43D2F',
];

function pick(values: string[], seed: number) {
  return values[Math.abs(seed) % values.length]!;
}

function initials(name: string) {
  return name
    .split(' ')
    .map((part) => part[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();
}

const FeedCard = memo(function FeedCard({ index }: { index: number }) {
  const author = pick(AUTHORS, index);
  const location = pick(LOCATIONS, index * 7);
  const caption = pick(CAPTIONS, index * 13);
  const accent = pick(COLORS, index * 3);
  const dark = pick(COLORS, index * 5 + 1);
  const likes = 12_400 + ((index * 48271) % 812_000);
  const comments = 80 + ((index * 977) % 8_900);
  const saves = 20 + ((index * 313) % 4_400);

  return (
    <View style={styles.card}>
      <View style={styles.cardHeader}>
        <View style={[styles.avatar, { backgroundColor: accent }]}>
          <Text style={styles.avatarText}>{initials(author)}</Text>
        </View>
        <View style={styles.identity}>
          <Text style={styles.author}>{author}</Text>
          <Text style={styles.location}>
            {location} / frame {index + 1}
          </Text>
        </View>
        <View style={styles.livePill}>
          <Text style={styles.liveText}>LIVE</Text>
        </View>
      </View>

      <View style={[styles.media, { backgroundColor: dark }]}>
        {MEDIA_TILES.map((tile) => {
          const color = pick(COLORS, index + tile * 11);
          return (
            <View
              key={tile}
              style={[
                styles.mediaTile,
                {
                  backgroundColor: color,
                  left: `${(tile % 6) * 16.66}%`,
                  top: `${Math.floor(tile / 6) * 33.33}%`,
                },
              ]}
            />
          );
        })}
        <View style={styles.mediaOverlay}>
          <Text style={styles.playIcon}>PLAY</Text>
          <Text style={styles.mediaLabel}>4K synthetic media stack</Text>
        </View>
        <View style={styles.progressTrack}>
          <View
            style={[
              styles.progressFill,
              { width: `${18 + (index % 78)}%`, backgroundColor: accent },
            ]}
          />
        </View>
      </View>

      <View style={styles.metrics}>
        <Text style={styles.metric}>{likes.toLocaleString()} likes</Text>
        <Text style={styles.metric}>{comments.toLocaleString()} comments</Text>
        <Text style={styles.metric}>{saves.toLocaleString()} saves</Text>
      </View>

      <Text style={styles.caption} numberOfLines={2}>
        {caption}
      </Text>

      <View style={styles.footer}>
        <View style={styles.footerBar} />
        <View style={[styles.footerBar, styles.footerBarShort]} />
        <Text style={styles.rowNumber}>
          #{String(index + 1).padStart(6, '0')}
        </Text>
      </View>
    </View>
  );
});

export default function App() {
  const data = useMemo(() => DATA, []);

  return (
    <View style={styles.screen}>
      <View style={styles.header}>
        <Text style={styles.title}>FluxList Stress Feed</Text>
        <Text style={styles.subtitle}>
          {ITEM_COUNT.toLocaleString()} fixed-height media rows / native
          windowing
        </Text>
      </View>

      <FluxListView
        data={data}
        keyExtractor={(item) => `feed-${item}`}
        virtualization={{
          enabled: true,
          estimatedItemHeight: CARD_HEIGHT,
          fixedItemHeight: CARD_HEIGHT,
          initialNumToRender: 18,
          overscan: 10,
          windowSize: 32,
        }}
        renderItem={({ item }) => <FeedCard index={item} />}
        style={styles.list}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#E9EDF2',
  },
  header: {
    paddingTop: 54,
    paddingHorizontal: 16,
    paddingBottom: 12,
    backgroundColor: '#FFFFFF',
    borderBottomColor: '#CBD3DD',
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  title: {
    color: '#111827',
    fontSize: 24,
    fontWeight: '800',
  },
  subtitle: {
    color: '#526070',
    fontSize: 13,
    marginTop: 4,
  },
  list: {
    flex: 1,
  },
  card: {
    height: CARD_HEIGHT,
    paddingHorizontal: 14,
    paddingTop: 12,
    paddingBottom: 14,
    backgroundColor: '#FFFFFF',
    borderBottomColor: '#D8E0EA',
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  cardHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    height: 48,
  },
  avatar: {
    alignItems: 'center',
    borderRadius: 20,
    height: 40,
    justifyContent: 'center',
    width: 40,
  },
  avatarText: {
    color: '#FFFFFF',
    fontSize: 13,
    fontWeight: '800',
  },
  identity: {
    flex: 1,
    paddingLeft: 10,
  },
  author: {
    color: '#111827',
    fontSize: 15,
    fontWeight: '800',
  },
  location: {
    color: '#667085',
    fontSize: 12,
    marginTop: 2,
  },
  livePill: {
    alignItems: 'center',
    backgroundColor: '#111827',
    borderRadius: 4,
    height: 24,
    justifyContent: 'center',
    paddingHorizontal: 8,
  },
  liveText: {
    color: '#FFFFFF',
    fontSize: 11,
    fontWeight: '800',
  },
  media: {
    borderRadius: 8,
    height: 226,
    marginTop: 10,
    overflow: 'hidden',
    position: 'relative',
  },
  mediaTile: {
    height: '34%',
    opacity: 0.92,
    position: 'absolute',
    width: '17%',
  },
  mediaOverlay: {
    alignItems: 'center',
    bottom: 18,
    flexDirection: 'row',
    left: 14,
    position: 'absolute',
    right: 14,
  },
  playIcon: {
    backgroundColor: '#FFFFFF',
    borderRadius: 4,
    color: '#111827',
    fontSize: 11,
    fontWeight: '900',
    overflow: 'hidden',
    paddingHorizontal: 8,
    paddingVertical: 5,
  },
  mediaLabel: {
    color: '#FFFFFF',
    flex: 1,
    fontSize: 14,
    fontWeight: '800',
    marginLeft: 10,
  },
  progressTrack: {
    backgroundColor: 'rgba(255,255,255,0.34)',
    bottom: 0,
    height: 5,
    left: 0,
    position: 'absolute',
    right: 0,
  },
  progressFill: {
    height: 5,
  },
  metrics: {
    flexDirection: 'row',
    gap: 10,
    marginTop: 12,
  },
  metric: {
    color: '#111827',
    fontSize: 12,
    fontWeight: '700',
  },
  caption: {
    color: '#293241',
    fontSize: 14,
    lineHeight: 19,
    marginTop: 8,
  },
  footer: {
    alignItems: 'center',
    flexDirection: 'row',
    marginTop: 12,
  },
  footerBar: {
    backgroundColor: '#D0D7E2',
    borderRadius: 3,
    height: 6,
    marginRight: 8,
    width: 72,
  },
  footerBarShort: {
    width: 42,
  },
  rowNumber: {
    color: '#667085',
    flex: 1,
    fontSize: 12,
    fontWeight: '700',
    textAlign: 'right',
  },
});
