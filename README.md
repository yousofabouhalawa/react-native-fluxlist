# react-native-fluxlist

A high-performance native list for React Native with selection mode, batch actions, and swipe quick actions, backed by UITableView and RecyclerView.

## Installation


```sh
npm install react-native-fluxlist
```


## Usage


```js
import { FluxListView } from "react-native-fluxlist";

// ...

<FluxListView
  data={[{ id: "1", title: "Row 1" }]}
  keyExtractor={(item) => item.id}
  renderItem={({ item }) => <Text>{item.title}</Text>}
/>
```

For large fixed-height lists, enable native windowing so FluxList keeps the full
native scroll range while mounting only a compact React window:

```js
<FluxListView
  data={items}
  keyExtractor={(item) => item.id}
  virtualization={{
    enabled: true,
    fixedItemHeight: 412,
    estimatedItemHeight: 412,
    windowSize: 32,
    overscan: 10,
  }}
  renderItem={({ item }) => <FeedCard item={item} />}
/>
```


## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
