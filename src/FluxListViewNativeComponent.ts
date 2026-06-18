import {
  codegenNativeComponent,
  type ColorValue,
  type ViewProps,
} from 'react-native';
import type { Double, Int32 } from 'react-native/Libraries/Types/CodegenTypes';
import type { DirectEventHandler } from 'react-native/Libraries/Types/CodegenTypes';

type SwipeAction = {
  key: string;
  title: string;
  color?: ColorValue;
  icon?: string;
  destructive?: boolean;
};

interface NativeProps extends ViewProps {
  itemCount: Int32;
  estimatedItemHeight?: Double;
  itemHeights?: ReadonlyArray<number>;
  mountedRowIndices?: ReadonlyArray<Int32>;
  rowItemIndices?: ReadonlyArray<Int32>;
  searchEnabled?: boolean;
  searchPlaceholder?: string;
  swipeActions?: {
    leading?: ReadonlyArray<SwipeAction>;
    trailing?: ReadonlyArray<SwipeAction>;
  };
  onSearchChange?: DirectEventHandler<{
    query: string;
  }>;
  onVisibleRangeChange?: DirectEventHandler<{
    first: Int32;
    last: Int32;
  }>;
  onSwipeAction?: DirectEventHandler<{
    actionKey: string;
    index: Int32;
    row: Int32;
    side: 'leading' | 'trailing';
  }>;
}

export default codegenNativeComponent<NativeProps>('FluxListView');
