import React, {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  InteractionManager,
  StyleSheet,
  type GestureResponderEvent,
  View,
} from 'react-native';

import NativeFluxListView from './FluxListViewNativeComponent';

type NativePassthroughProps = Omit<
  React.ComponentProps<typeof NativeFluxListView>,
  | 'estimatedItemHeight'
  | 'itemCount'
  | 'itemHeights'
  | 'mountedRowIndices'
  | 'rowItemIndices'
  | 'onVisibleRangeChange'
>;

type SwipeActionEvent = Parameters<
  NonNullable<React.ComponentProps<typeof NativeFluxListView>['onSwipeAction']>
>[0];

type VisibleRangeEvent = Parameters<
  NonNullable<
    React.ComponentProps<typeof NativeFluxListView>['onVisibleRangeChange']
  >
>[0];

export type FluxListVirtualizationConfig = {
  enabled?: boolean;
  estimatedItemHeight?: number;
  fixedItemHeight?: number;
  initialNumToRender?: number;
  maxToRenderPerBatch?: number;
  overscan?: number;
  updateCellsBatchingPeriod?: number;
  windowSize?: number;
};

type FluxListViewProps<ItemT> = {
  data?: ItemT[];
  renderItem?: (info: {
    item: ItemT;
    index: number;
    separators: {
      highlight: () => void;
      unhighlight: () => void;
      updateProps: () => void;
    };
  }) => React.ReactElement | null;
  keyExtractor?: (item: ItemT, index: number) => string;
  ListHeaderComponent?:
    | React.ReactElement
    | ((info: {}) => React.ReactElement | null)
    | null;
  ListFooterComponent?:
    | React.ReactElement
    | ((info: {}) => React.ReactElement | null)
    | null;
  ItemSeparatorComponent?:
    | React.ReactElement
    | ((info: { highlighted: boolean }) => React.ReactElement | null)
    | null;
  searchEnabled?: React.ComponentProps<
    typeof NativeFluxListView
  >['searchEnabled'];
  searchPlaceholder?: React.ComponentProps<
    typeof NativeFluxListView
  >['searchPlaceholder'];
  onSearchChange?: React.ComponentProps<
    typeof NativeFluxListView
  >['onSearchChange'];
  swipeActions?: React.ComponentProps<
    typeof NativeFluxListView
  >['swipeActions'];
  onSwipeAction?: React.ComponentProps<
    typeof NativeFluxListView
  >['onSwipeAction'];
  extraData?: unknown;
  virtualization?: FluxListVirtualizationConfig;
} & NativePassthroughProps;

const noopSeparators = {
  highlight() {},
  unhighlight() {},
  updateProps() {},
};

function normalizeComponent(
  component: FluxListViewProps<unknown>['ListHeaderComponent']
) {
  if (!component) {
    return null;
  }

  return typeof component === 'function' ? component({}) : component;
}

function FluxListView<ItemT>(props: FluxListViewProps<ItemT>) {
  const {
    data,
    renderItem,
    keyExtractor,
    ListHeaderComponent,
    ListFooterComponent,
    ItemSeparatorComponent,
    extraData,
    virtualization,
    swipeActions,
    onSwipeAction,
    onTouchStart,
    onTouchMove,
    onTouchEnd,
    onTouchCancel,
    ...rest
  } = props;

  const [itemHeightsByRow, setItemHeightsByRow] = useState<
    Record<number, number>
  >({});
  const batchTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const batchInteractionTaskRef = useRef<{ cancel: () => void } | null>(null);
  const interactionReleaseTimeoutRef = useRef<ReturnType<
    typeof setTimeout
  > | null>(null);
  const touchStartPointRef = useRef<{ x: number; y: number } | null>(null);
  const touchMaxDeltaRef = useRef<{ dx: number; dy: number }>({ dx: 0, dy: 0 });
  const [renderedItemCount, setRenderedItemCount] = useState<number>(0);
  const [isInteracting, setIsInteracting] = useState(false);
  const [renderWindow, setRenderWindow] = useState({ first: 0, last: -1 });
  const renderWindowRef = useRef(renderWindow);

  const virtualizationEnabled = virtualization?.enabled === true;
  const supportsNativeWindowing =
    virtualizationEnabled &&
    !ListHeaderComponent &&
    !ListFooterComponent &&
    !ItemSeparatorComponent;
  const estimatedItemHeight = Math.max(
    1,
    virtualization?.fixedItemHeight ?? virtualization?.estimatedItemHeight ?? 96
  );
  const initialNumToRender = Math.max(
    1,
    virtualization?.initialNumToRender ?? 24
  );
  const maxToRenderPerBatch = Math.max(
    1,
    virtualization?.maxToRenderPerBatch ?? 24
  );
  const updateCellsBatchingPeriod = Math.max(
    16,
    virtualization?.updateCellsBatchingPeriod ?? 48
  );
  const windowSize = Math.max(
    initialNumToRender,
    virtualization?.windowSize ?? 64
  );
  const overscan = Math.max(
    0,
    virtualization?.overscan ?? Math.floor(windowSize * 0.5)
  );
  const hasSwipeActions =
    (swipeActions?.leading?.length ?? 0) > 0 ||
    (swipeActions?.trailing?.length ?? 0) > 0;
  const shouldMeasureItemHeights = virtualization?.fixedItemHeight == null;
  const updateItemHeight = useCallback(
    (index: number, height: number) => {
      if (!shouldMeasureItemHeights || height <= 0) {
        return;
      }
      setItemHeightsByRow((prev) => {
        if (prev[index] === height) {
          return prev;
        }
        return { ...prev, [index]: height };
      });
    },
    [shouldMeasureItemHeights]
  );

  useEffect(() => {
    setItemHeightsByRow({});
  }, [
    data,
    ListHeaderComponent,
    ListFooterComponent,
    ItemSeparatorComponent,
    extraData,
  ]);

  const totalCount = data?.length ?? 0;

  useEffect(() => {
    const last =
      totalCount === 0 ? -1 : Math.min(initialNumToRender - 1, totalCount - 1);
    const nextWindow = { first: 0, last };
    renderWindowRef.current = nextWindow;
    setRenderWindow(nextWindow);
  }, [data, totalCount, initialNumToRender, extraData]);

  const clearInteractionReleaseTimeout = useCallback(() => {
    if (interactionReleaseTimeoutRef.current) {
      clearTimeout(interactionReleaseTimeoutRef.current);
      interactionReleaseTimeoutRef.current = null;
    }
  }, []);

  const scheduleInteractionRelease = useCallback(
    (delayMs: number) => {
      clearInteractionReleaseTimeout();
      interactionReleaseTimeoutRef.current = setTimeout(() => {
        setIsInteracting(false);
        interactionReleaseTimeoutRef.current = null;
      }, delayMs);
    },
    [clearInteractionReleaseTimeout]
  );

  const handleTouchStart = useCallback(
    (event: GestureResponderEvent) => {
      clearInteractionReleaseTimeout();
      setIsInteracting(true);
      touchStartPointRef.current = {
        x: event.nativeEvent.pageX,
        y: event.nativeEvent.pageY,
      };
      touchMaxDeltaRef.current = { dx: 0, dy: 0 };
      onTouchStart?.(event);
    },
    [clearInteractionReleaseTimeout, onTouchStart]
  );

  const handleTouchMove = useCallback(
    (event: GestureResponderEvent) => {
      const start = touchStartPointRef.current;
      if (start) {
        const dx = Math.abs(event.nativeEvent.pageX - start.x);
        const dy = Math.abs(event.nativeEvent.pageY - start.y);
        touchMaxDeltaRef.current = {
          dx: Math.max(touchMaxDeltaRef.current.dx, dx),
          dy: Math.max(touchMaxDeltaRef.current.dy, dy),
        };
      }
      onTouchMove?.(event);
    },
    [onTouchMove]
  );

  const handleTouchEndLike = useCallback(
    (
      event: GestureResponderEvent,
      originalHandler?: (event: GestureResponderEvent) => void
    ) => {
      originalHandler?.(event);
      const { dx, dy } = touchMaxDeltaRef.current;
      const isHorizontalSwipe = dx > 10 && dx > dy * 1.2;
      const releaseDelay = isHorizontalSwipe && hasSwipeActions ? 12000 : 220;
      scheduleInteractionRelease(releaseDelay);
      touchStartPointRef.current = null;
      touchMaxDeltaRef.current = { dx: 0, dy: 0 };
    },
    [hasSwipeActions, scheduleInteractionRelease]
  );

  const handleTouchEnd = useCallback(
    (event: GestureResponderEvent) => {
      handleTouchEndLike(event, onTouchEnd);
    },
    [handleTouchEndLike, onTouchEnd]
  );

  const handleTouchCancel = useCallback(
    (event: GestureResponderEvent) => {
      handleTouchEndLike(event, onTouchCancel);
    },
    [handleTouchEndLike, onTouchCancel]
  );

  const handleSwipeAction = useCallback(
    (event: SwipeActionEvent) => {
      onSwipeAction?.(event);
      const actionKey = event.nativeEvent.actionKey?.toLowerCase() ?? '';
      const isDeleteAction = actionKey.includes('delete');
      scheduleInteractionRelease(isDeleteAction ? 900 : 80);
    },
    [onSwipeAction, scheduleInteractionRelease]
  );

  const handleVisibleRangeChange = useCallback(
    (event: VisibleRangeEvent) => {
      if (!supportsNativeWindowing || totalCount === 0) {
        return;
      }

      const firstVisible = Math.max(0, event.nativeEvent.first);
      const lastVisible = Math.min(totalCount - 1, event.nativeEvent.last);
      if (lastVisible < firstVisible) {
        return;
      }

      const visibleCount = lastVisible - firstVisible + 1;
      const targetCount = Math.max(windowSize, visibleCount + overscan * 2);
      const midpoint = Math.floor((firstVisible + lastVisible) / 2);
      let first = Math.max(0, midpoint - Math.floor(targetCount / 2));
      let last = Math.min(totalCount - 1, first + targetCount - 1);
      first = Math.max(0, last - targetCount + 1);

      const current = renderWindowRef.current;
      if (current.first === first && current.last === last) {
        return;
      }

      const nextWindow = { first, last };
      renderWindowRef.current = nextWindow;
      setRenderWindow(nextWindow);
    },
    [overscan, supportsNativeWindowing, totalCount, windowSize]
  );

  useEffect(() => {
    setRenderedItemCount((prev) => {
      if (!virtualizationEnabled || supportsNativeWindowing) {
        return totalCount;
      }
      if (totalCount === 0) {
        return 0;
      }
      if (prev === 0) {
        return Math.min(initialNumToRender, totalCount);
      }
      return Math.min(prev, totalCount);
    });
  }, [
    totalCount,
    virtualizationEnabled,
    supportsNativeWindowing,
    initialNumToRender,
    extraData,
  ]);

  useEffect(() => {
    if (batchTimeoutRef.current) {
      clearTimeout(batchTimeoutRef.current);
      batchTimeoutRef.current = null;
    }
    if (batchInteractionTaskRef.current) {
      batchInteractionTaskRef.current.cancel();
      batchInteractionTaskRef.current = null;
    }

    if (!virtualizationEnabled || supportsNativeWindowing) {
      return;
    }

    if (renderedItemCount >= totalCount) {
      return;
    }

    if (isInteracting) {
      return;
    }

    batchInteractionTaskRef.current = InteractionManager.runAfterInteractions(
      () => {
        batchTimeoutRef.current = setTimeout(() => {
          setRenderedItemCount((prev) =>
            Math.min(prev + maxToRenderPerBatch, totalCount)
          );
          batchTimeoutRef.current = null;
        }, updateCellsBatchingPeriod);
      }
    );

    return () => {
      if (batchTimeoutRef.current) {
        clearTimeout(batchTimeoutRef.current);
        batchTimeoutRef.current = null;
      }
      if (batchInteractionTaskRef.current) {
        batchInteractionTaskRef.current.cancel();
        batchInteractionTaskRef.current = null;
      }
    };
  }, [
    renderedItemCount,
    totalCount,
    virtualizationEnabled,
    supportsNativeWindowing,
    isInteracting,
    maxToRenderPerBatch,
    updateCellsBatchingPeriod,
  ]);

  useEffect(() => {
    return () => {
      if (batchTimeoutRef.current) {
        clearTimeout(batchTimeoutRef.current);
        batchTimeoutRef.current = null;
      }
      if (batchInteractionTaskRef.current) {
        batchInteractionTaskRef.current.cancel();
        batchInteractionTaskRef.current = null;
      }
      if (interactionReleaseTimeoutRef.current) {
        clearTimeout(interactionReleaseTimeoutRef.current);
        interactionReleaseTimeoutRef.current = null;
      }
    };
  }, []);

  const {
    children,
    mountedRowIndices,
    rowCount,
    rowItemHeights,
    rowItemIndices,
  } = useMemo(() => {
    if (!data || data.length === 0) {
      return {
        children: null,
        mountedRowIndices: [] as number[],
        rowCount: 0,
        rowItemHeights: [] as number[],
        rowItemIndices: [] as number[],
      };
    }

    const windowFirst = supportsNativeWindowing ? renderWindow.first : 0;
    const windowLast = supportsNativeWindowing
      ? Math.min(renderWindow.last, data.length - 1)
      : -1;
    const rowsData = supportsNativeWindowing
      ? data.slice(windowFirst, windowLast + 1)
      : virtualizationEnabled
      ? data.slice(0, Math.min(renderedItemCount, data.length))
      : data;

    const resolvedRenderItem =
      renderItem ??
      ((info: { item: ItemT }) =>
        React.isValidElement(info.item)
          ? (info.item as React.ReactElement)
          : null);

    const elements: React.ReactElement[] = [];
    const nextMountedRowIndices: number[] = [];
    const nextRowItemIndices: number[] = [];
    let rowIndex = 0;
    const header = normalizeComponent(ListHeaderComponent);
    if (header) {
      const index = rowIndex++;
      nextMountedRowIndices.push(index);
      nextRowItemIndices.push(-1);
      elements.push(
        <View
          key="$header"
          style={styles.fullWidth}
          onLayout={(event) =>
            updateItemHeight(index, Math.ceil(event.nativeEvent.layout.height))
          }
          collapsable={false}
        >
          {header}
        </View>
      );
    }

    rowsData.forEach((item, index) => {
      const itemIndex = supportsNativeWindowing ? windowFirst + index : index;
      const element = resolvedRenderItem({
        item,
        index: itemIndex,
        separators: noopSeparators,
      });
      if (element) {
        const elementKey =
          keyExtractor?.(item, itemIndex) ??
          (typeof element.key === 'string' ? element.key : null) ??
          String(itemIndex);
        const rowSlot = supportsNativeWindowing ? itemIndex : rowIndex++;
        nextMountedRowIndices.push(rowSlot);
        nextRowItemIndices.push(itemIndex);
        elements.push(
          <View
            key={elementKey}
            style={styles.fullWidth}
            onLayout={(event) =>
              updateItemHeight(
                rowSlot,
                Math.ceil(event.nativeEvent.layout.height)
              )
            }
            collapsable={false}
          >
            {element}
          </View>
        );
      }

      if (ItemSeparatorComponent && index < rowsData.length - 1) {
        const separator =
          typeof ItemSeparatorComponent === 'function'
            ? ItemSeparatorComponent({ highlighted: false })
            : ItemSeparatorComponent;
        if (separator) {
          const rowSlot = rowIndex++;
          nextMountedRowIndices.push(rowSlot);
          nextRowItemIndices.push(-1);
          elements.push(
            <View
              key={`$separator-${index}`}
              style={styles.fullWidth}
              onLayout={(event) =>
                updateItemHeight(
                  rowSlot,
                  Math.ceil(event.nativeEvent.layout.height)
                )
              }
              collapsable={false}
            >
              {separator}
            </View>
          );
        }
      }
    });

    const footer = normalizeComponent(ListFooterComponent);
    if (footer) {
      const index = rowIndex++;
      nextMountedRowIndices.push(index);
      nextRowItemIndices.push(-1);
      elements.push(
        <View
          key="$footer"
          style={styles.fullWidth}
          onLayout={(event) =>
            updateItemHeight(index, Math.ceil(event.nativeEvent.layout.height))
          }
          collapsable={false}
        >
          {footer}
        </View>
      );
    }

    const nativeRowCount = supportsNativeWindowing ? totalCount : rowIndex;
    return {
      children: elements,
      mountedRowIndices: nextMountedRowIndices,
      rowCount: nativeRowCount,
      rowItemHeights: nextMountedRowIndices.map(
        (row) => itemHeightsByRow[row] ?? 0
      ),
      rowItemIndices: nextRowItemIndices,
    };
    // `extraData` is intentionally included to force row recomputation.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    data,
    renderItem,
    keyExtractor,
    ListHeaderComponent,
    ListFooterComponent,
    ItemSeparatorComponent,
    extraData,
    virtualizationEnabled,
    supportsNativeWindowing,
    renderedItemCount,
    renderWindow,
    totalCount,
    itemHeightsByRow,
    updateItemHeight,
  ]);

  return (
    <NativeFluxListView
      {...rest}
      estimatedItemHeight={estimatedItemHeight}
      swipeActions={swipeActions}
      itemHeights={rowItemHeights}
      itemCount={rowCount}
      mountedRowIndices={mountedRowIndices}
      rowItemIndices={rowItemIndices}
      onVisibleRangeChange={handleVisibleRangeChange}
      onSwipeAction={handleSwipeAction}
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
      onTouchCancel={handleTouchCancel}
    >
      {children}
    </NativeFluxListView>
  );
}

const styles = StyleSheet.create({
  fullWidth: {
    width: '100%',
  },
});

export default FluxListView;
