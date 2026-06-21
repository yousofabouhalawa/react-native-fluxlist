# react-native-fluxlist

A native-backed React Native list with optional virtualization, native search,
selection mode, swipe actions, context menus, smooth transitions, and simple
multi-column grids.

FluxList is designed for lists where the native container should own scrolling,
row hit targets, search chrome, edit mode, and swipe gestures while React still
renders the row content.

## Installation

```sh
npm install react-native-fluxlist
```

```sh
yarn add react-native-fluxlist
```

For iOS, install pods after adding the package:

```sh
cd ios
pod install
```

## Basic Usage

```tsx
import { Text, View } from 'react-native';
import { FluxList } from 'react-native-fluxlist';

type Message = {
  id: string;
  sender: string;
  preview: string;
};

const messages: Message[] = [
  { id: '1', sender: 'Yousof', preview: 'Can you check this build?' },
  { id: '2', sender: 'Sam', preview: 'The new list feels faster.' },
];

export function Messages() {
  return (
    <FluxList
      data={messages}
      keyExtractor={(item) => item.id}
      renderItem={({ item }) => (
        <View style={{ height: 72, justifyContent: 'center', padding: 16 }}>
          <Text>{item.sender}</Text>
          <Text numberOfLines={1}>{item.preview}</Text>
        </View>
      )}
      style={{ flex: 1 }}
      virtualization={{
        itemHeight: 72,
        estimatedItemHeight: 72,
      }}
    />
  );
}
```

## Why FluxList

- Native scrolling and row containers on iOS and Android.
- Optional virtualization with a compact React render window.
- Fixed-height row support for stable spacing and fast visible-range math.
- Native iOS search, context menu, edit selection, and swipe actions.
- Android search, edit selection, long-press select mode, and full-swipe
  actions.
- React-rendered rows, so you keep your normal component model.
- Multi-column layout for product grids and catalogs.

## API

```tsx
import {
  FluxList,
  type FluxListProps,
  type FluxListRenderItemInfo,
  type FluxListSwipeAction,
  type FluxListVirtualizationConfig,
} from 'react-native-fluxlist';
```

### `FluxListProps<ItemT>`

FluxList accepts normal React Native `ViewProps`, except `children` is managed
by `renderItem`.

| Prop | Type | Default | Description |
| --- | --- | --- | --- |
| `data` | `readonly ItemT[]` | `[]` | Items to render. |
| `renderItem` | `(info: FluxListRenderItemInfo<ItemT>) => ReactElement \| null` | Required | Renders each item. |
| `keyExtractor` | `(item: ItemT, index: number) => string` | `String(index)` | Stable key for each item. Use real IDs for deletes, filtering, and virtualization. |
| `columns` | `number` | `1` | Number of columns per native row. Values below `1` are clamped to `1`. |
| `columnGap` | `number` | `0` | Horizontal gap between columns, in points. |
| `virtualization` | `boolean \| FluxListVirtualizationConfig` | `true` | Enables native-windowed rendering or configures the window. |
| `editing` | `boolean` | `false` | Shows selection controls and enables edit-mode selection. |
| `allowsMultipleSelectionDuringEditing` | `boolean` | `true` | Allows multiple rows to be selected while editing. |
| `selectedItemIndices` | `readonly number[]` | `[]` | Controlled selected item indices. |
| `selectionTintColor` | `ColorValue` | System blue | Color for selected edit controls. |
| `smoothTransitions` | `boolean` | `false` | Enables native layout transitions for insert/remove/filter changes where supported. |
| `searchEnabled` | `boolean` | `false` | Shows the native search field. Filtering is controlled by your React state. |
| `searchPlaceholder` | `string` | `"Search"` | Placeholder text for the native search field. |
| `swipeActions` | `{ leading?: FluxListSwipeAction[]; trailing?: FluxListSwipeAction[] }` | `{}` | Native swipe actions. |
| `contextMenuActions` | `FluxListSwipeAction[]` | `[]` | iOS context menu actions. Android long press enters selection mode. |
| `onSearchChange` | `(query: string) => void` | `undefined` | Called when native search text changes. |
| `onSelectionChange` | `(selectedIndices: number[]) => void` | `undefined` | Called when native edit selection changes. |
| `onSwipeAction` | `(event) => void` | `undefined` | Called when a swipe action is committed. |
| `onContextMenuAction` | `(event) => void` | `undefined` | Called when an iOS context menu action is chosen. |
| `extraData` | `unknown` | `undefined` | Forces row recomputation when external render state changes. |
| `style` | `ViewStyle` | `undefined` | Style for the list container. Use `flex: 1` when the list should fill available space. |

### `FluxListRenderItemInfo<ItemT>`

```ts
type FluxListRenderItemInfo<ItemT> = {
  item: ItemT;
  index: number;
};
```

### `FluxListVirtualizationConfig`

```ts
type FluxListVirtualizationConfig = {
  enabled?: boolean;
  itemHeight?: number;
  estimatedItemHeight?: number;
  initialNumToRender?: number;
  maxToRenderPerBatch?: number;
  updateCellsBatchingPeriod?: number;
  windowSize?: number;
  overscan?: number;
  leadingOverscan?: number;
  trailingOverscan?: number;
};
```

| Option | Default | Description |
| --- | --- | --- |
| `enabled` | `true` | Enables virtualization. Set `false` to eventually mount every item in batches. |
| `itemHeight` | `undefined` | Exact native row height. Use this whenever rows have fixed height. |
| `estimatedItemHeight` | `72` | Estimated native row height used for initial scroll range and visible-range math. |
| `initialNumToRender` | `18` | Initial item count used to seed the render window. |
| `maxToRenderPerBatch` | `48` | Batch size for non-virtualized mounting. |
| `updateCellsBatchingPeriod` | `32` | Delay between non-virtualized batches, in milliseconds. |
| `windowSize` | `72` | Target item count for the virtual render window. |
| `overscan` | `24` | Extra items rendered before and after the visible range. |
| `leadingOverscan` | `overscan` | Extra items kept before the visible range. |
| `trailingOverscan` | `overscan * 2` | Extra items kept after the visible range. |

When `columns` is greater than `1`, `itemHeight`, `estimatedItemHeight`,
`windowSize`, and overscan values describe native rows, not individual cards.
For example, two columns with `itemHeight: 306` means each two-card row is
306 points tall.

### `FluxListSwipeAction`

```ts
type FluxListSwipeAction = {
  key: string;
  title: string;
  color?: ColorValue;
  icon?: string;
  destructive?: boolean;
};
```

| Field | Description |
| --- | --- |
| `key` | Stable action identifier returned in `onSwipeAction` and `onContextMenuAction`. |
| `title` | Native action title. |
| `color` | Action background color. |
| `icon` | Native icon name. On iOS this is an SF Symbol name. |
| `destructive` | Marks the action as destructive where the platform supports it. |

### Event Payloads

```ts
onSwipeAction?: (event: {
  actionKey: string;
  index: number;
  row: number;
  side: 'leading' | 'trailing';
}) => void;

onContextMenuAction?: (event: {
  actionKey: string;
  index: number;
  row: number;
}) => void;
```

`index` is the item index for single-column lists. For multi-column lists,
`index` is the first item index in the native row.

## Examples

### Fixed-Height Feed

```tsx
const ROW_HEIGHT = 504;

<FluxList
  data={posts}
  keyExtractor={(post) => post.id}
  renderItem={({ item }) => <PostCard post={item} />}
  style={{ flex: 1 }}
  virtualization={{
    enabled: true,
    itemHeight: ROW_HEIGHT,
    estimatedItemHeight: ROW_HEIGHT,
    initialNumToRender: 12,
    windowSize: 96,
    overscan: 32,
    trailingOverscan: 96,
  }}
/>;
```

### Native Search

Search is native UI, but filtering is controlled by your React state. This
keeps the source of truth in your app and makes updates predictable.

```tsx
const [query, setQuery] = useState('');

const filteredMessages = useMemo(() => {
  const normalized = query.trim().toLowerCase();
  if (!normalized) {
    return messages;
  }

  return messages.filter((message) =>
    `${message.sender} ${message.preview}`.toLowerCase().includes(normalized)
  );
}, [messages, query]);

<FluxList
  data={filteredMessages}
  keyExtractor={(message) => message.id}
  renderItem={({ item }) => <MessageRow message={item} />}
  searchEnabled
  searchPlaceholder="Search messages"
  onSearchChange={setQuery}
  virtualization={{
    itemHeight: 76,
    estimatedItemHeight: 76,
  }}
/>;
```

### Edit Mode and Selection

```tsx
const [editing, setEditing] = useState(false);
const [selectedIds, setSelectedIds] = useState<Set<string>>(() => new Set());

const selectedItemIndices = useMemo(
  () =>
    messages.reduce<number[]>((indices, message, index) => {
      if (selectedIds.has(message.id)) {
        indices.push(index);
      }
      return indices;
    }, []),
  [messages, selectedIds]
);

<FluxList
  data={messages}
  editing={editing}
  allowsMultipleSelectionDuringEditing
  selectedItemIndices={selectedItemIndices}
  selectionTintColor="#2F7DF6"
  onSelectionChange={(indices) => {
    setSelectedIds(
      new Set(
        indices.flatMap((index) => {
          const message = messages[index];
          return message ? [message.id] : [];
        })
      )
    );
  }}
  keyExtractor={(message) => message.id}
  renderItem={({ item }) => <MessageRow message={item} />}
  virtualization={{
    itemHeight: 76,
    estimatedItemHeight: 76,
  }}
/>;
```

On iOS, edit mode uses native table selection behavior. On Android, long
pressing a row enters selection mode and tapping anywhere on a row toggles it
while editing.

### Swipe Actions

```tsx
const deleteAction = {
  key: 'delete',
  title: 'Delete',
  color: '#FF3B30',
  icon: 'trash',
  destructive: true,
};

const markReadAction = {
  key: 'mark-read',
  title: 'Read',
  color: '#8E8E93',
  icon: 'envelope.open',
};

<FluxList
  data={messages}
  keyExtractor={(message) => message.id}
  renderItem={({ item }) => <MessageRow message={item} />}
  swipeActions={{
    leading: [markReadAction],
    trailing: [deleteAction],
  }}
  onSwipeAction={({ actionKey, index }) => {
    const message = messages[index];
    if (!message) {
      return;
    }

    if (actionKey === 'delete') {
      setMessages((current) =>
        current.filter((candidate) => candidate.id !== message.id)
      );
    }
  }}
  virtualization={{
    itemHeight: 76,
    estimatedItemHeight: 76,
  }}
/>;
```

On iOS, swipe actions use native table swipe actions. On Android, swipe actions
use native Android touch handling with full-swipe commit behavior.

### iOS Context Menus

```tsx
<FluxList
  data={messages}
  keyExtractor={(message) => message.id}
  renderItem={({ item }) => <MessageRow message={item} />}
  contextMenuActions={[
    { key: 'select', title: 'Select', icon: 'checkmark.circle' },
    { key: 'delete', title: 'Delete', icon: 'trash', destructive: true },
  ]}
  onContextMenuAction={({ actionKey, index }) => {
    const message = messages[index];
    if (!message) {
      return;
    }
    if (actionKey === 'delete') {
      setMessages((current) =>
        current.filter((candidate) => candidate.id !== message.id)
      );
    }
  }}
/>;
```

Context menus are currently iOS-only. Android long press is reserved for native
selection mode.

### Product Catalog Grid

```tsx
const CARD_HEIGHT = 306;
const ROW_GAP = 14;
const ROW_HEIGHT = CARD_HEIGHT + ROW_GAP;

<FluxList
  data={products}
  columns={2}
  columnGap={14}
  keyExtractor={(product) => product.id}
  renderItem={({ item }) => <ProductCard product={item} />}
  style={{ flex: 1 }}
  virtualization={{
    enabled: true,
    itemHeight: ROW_HEIGHT,
    estimatedItemHeight: ROW_HEIGHT,
    initialNumToRender: 12,
    windowSize: 48,
    overscan: 16,
  }}
/>;
```

Each rendered item becomes a cell. FluxList groups cells into native rows based
on `columns`. Keep cards in the same row the same height for stable layouts.

### Non-Virtualized Large List

```tsx
<FluxList
  data={items}
  keyExtractor={(item) => item.id}
  renderItem={({ item }) => <Row item={item} />}
  virtualization={{
    enabled: false,
    itemHeight: 72,
    estimatedItemHeight: 72,
    initialNumToRender: 24,
    maxToRenderPerBatch: 64,
    updateCellsBatchingPeriod: 16,
  }}
/>;
```

When virtualization is disabled, FluxList eventually mounts every item. It
still batches the mounting work to avoid blocking the initial render.

## Performance Guidelines

- Prefer fixed-height rows and pass `virtualization.itemHeight`.
- Use stable `keyExtractor` values. Do not depend on array indices for data that
  can be filtered, inserted, or deleted.
- Keep row components memoized when they receive expensive props.
- Pass `extraData` when row rendering depends on external state.
- Increase `trailingOverscan` for fast forward scrolling.
- Keep `estimatedItemHeight` close to real row height if rows are dynamic.
- For grids, make every card in a native row the same height.

## Platform Notes

### iOS

- Backed by native table behavior.
- Supports native search, edit selection, swipe actions, context menus, and
  smooth row changes.
- Swipe action `icon` values should be SF Symbol names.

### Android

- Backed by a native Android scroll container and native row wrappers.
- Supports native search, edit selection, long-press select mode, and full-swipe
  actions.
- Android context menus are not currently implemented; long press enters
  selection mode.
- Swipe action `icon` is currently reserved for API parity.

## Example App

The repository includes an Expo example app with three screens:

- `Feed`: a large virtualized social feed.
- `Messages`: search, edit selection, swipe actions, and iOS context menus.
- `Catalog`: a two-column virtualized product grid.

Run it with:

```sh
yarn
yarn example start
```

For native builds:

```sh
yarn example ios
yarn example android
```

## Troubleshooting

### Rows overlap or spacing feels inconsistent

Pass an exact `virtualization.itemHeight` when your rows have a known height.
For grids, this is the full native row height.

### Swipe actions fire the wrong item after filtering

Use stable IDs in `keyExtractor`, and derive actions from your current filtered
data inside `onSwipeAction`.

### Selection state resets after search

Store selected item IDs in your app state, then convert them to
`selectedItemIndices` for the currently rendered data.

### The package is not registered in an example app

Make sure Metro is running from the example directory and the native app entry
matches the example configuration.

## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
