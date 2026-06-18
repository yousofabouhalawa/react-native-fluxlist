#import "FluxListView.h"

#import <math.h>
#import <React/RCTConversions.h>
#import <QuartzCore/QuartzCore.h>
#import <react/renderer/components/FluxListViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/FluxListViewSpec/EventEmitters.h>
#import <react/renderer/components/FluxListViewSpec/Props.h>
#import <react/renderer/components/FluxListViewSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"

using namespace facebook::react;

@interface FluxListSwipeAction : NSObject
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong, nullable) UIColor *color;
@property (nonatomic, copy, nullable) NSString *icon;
@property (nonatomic, assign) BOOL destructive;
@end

@implementation FluxListSwipeAction
@end

static UIColor *FluxListDefaultActionBackgroundColor(BOOL destructive)
{
  return destructive ? UIColor.systemRedColor : UIColor.systemBlueColor;
}

static UIColor *FluxListResolvedActionBackgroundColor(FluxListSwipeAction *action)
{
  UIColor *fallbackColor = FluxListDefaultActionBackgroundColor(action.destructive);
  UIColor *backgroundColor = action.color ?: fallbackColor;
  CGFloat alpha = CGColorGetAlpha(backgroundColor.CGColor);
  if (alpha <= 0.01) {
    return fallbackColor;
  }
  return backgroundColor;
}

static UIColor *FluxListForegroundColorForBackground(UIColor *backgroundColor)
{
  CGFloat red = 0.0;
  CGFloat green = 0.0;
  CGFloat blue = 0.0;
  CGFloat alpha = 0.0;
  if (![backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha]) {
    return UIColor.whiteColor;
  }

  CGFloat luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue);
  return luminance > 0.62 ? UIColor.blackColor : UIColor.whiteColor;
}

static UIImage * _Nullable FluxListCombinedIconTitleImage(
    UIImage *iconImage,
    NSString *title,
    UIColor *foregroundColor)
{
  if (!iconImage || title.length == 0) {
    return nil;
  }

  UIFont *font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
  NSDictionary<NSAttributedStringKey, id> *attributes = @{
    NSFontAttributeName : font,
    NSForegroundColorAttributeName : foregroundColor,
  };
  CGSize textSize = [title sizeWithAttributes:attributes];
  CGFloat spacing = 4.0;
  CGFloat width = ceil(MAX(iconImage.size.width, textSize.width));
  CGFloat height = ceil(iconImage.size.height + spacing + textSize.height);
  if (width <= 0.0 || height <= 0.0) {
    return nil;
  }

  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
  format.scale = UIScreen.mainScreen.scale;
  UIGraphicsImageRenderer *renderer =
      [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(width, height)
                                             format:format];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
    CGFloat iconX = floor((width - iconImage.size.width) * 0.5);
    [iconImage drawInRect:CGRectMake(iconX, 0.0, iconImage.size.width, iconImage.size.height)];
    CGFloat textX = floor((width - textSize.width) * 0.5);
    CGFloat textY = iconImage.size.height + spacing;
    [title drawAtPoint:CGPointMake(textX, textY)
        withAttributes:attributes];
  }];
}

static BOOL FluxListShouldAnimateDeleteAction(FluxListSwipeAction *action)
{
  if (!action.destructive) {
    return NO;
  }
  if (action.key.length == 0) {
    return YES;
  }
  NSRange deleteRange = [action.key rangeOfString:@"delete" options:NSCaseInsensitiveSearch];
  return deleteRange.location != NSNotFound;
}

template <typename ActionVector>
static NSArray<FluxListSwipeAction *> *FluxListSwipeActionArrayFromVector(
    const ActionVector &actions)
{
  NSMutableArray<FluxListSwipeAction *> *result = [NSMutableArray new];
  for (const auto &action : actions) {
    FluxListSwipeAction *item = [FluxListSwipeAction new];
    item.key = [NSString stringWithUTF8String:action.key.c_str()];
    item.title = [NSString stringWithUTF8String:action.title.c_str()];
    if (action.color) {
      item.color = RCTUIColorFromSharedColor(action.color);
    }
    if (!action.icon.empty()) {
      item.icon = [NSString stringWithUTF8String:action.icon.c_str()];
    }
    item.destructive = action.destructive;
    [result addObject:item];
  }
  return result;
}

@implementation FluxListView {
    UIView * _containerView;
    UITableView * _tableView;
    UISearchBar * _searchBar;
    NSMutableArray<UIView *> * _itemViews;
    NSMutableArray<NSNumber *> * _mountedRowIndices;
    NSMutableArray<NSNumber *> * _rowItemIndices;
    NSMutableDictionary<NSNumber *, UIView *> * _itemViewsByRow;
    NSMutableDictionary<NSNumber *, NSNumber *> * _itemHeightsByRow;
    NSArray * _leadingSwipeActions;
    NSArray * _trailingSwipeActions;
    NSInteger _itemCount;
    CGFloat _estimatedItemHeight;
    NSInteger _lastEmittedVisibleFirst;
    NSInteger _lastEmittedVisibleLast;
    BOOL _searchEnabled;
    NSString * _searchPlaceholder;
    __weak UIView * _pendingNativeDeleteView;
    BOOL _hasPendingNativeDelete;
    BOOL _isAnimatingNativeDelete;
    BOOL _reloadScheduled;
    BOOL _needsReloadAfterDeleteAnimation;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
    return concreteComponentDescriptorProvider<FluxListViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const FluxListViewProps>();
    _props = defaultProps;

    _itemViews = [NSMutableArray new];
    _mountedRowIndices = [NSMutableArray new];
    _rowItemIndices = [NSMutableArray new];
    _itemViewsByRow = [NSMutableDictionary new];
    _itemHeightsByRow = [NSMutableDictionary new];
    _itemCount = 0;
    _estimatedItemHeight = 72.0;
    _lastEmittedVisibleFirst = NSNotFound;
    _lastEmittedVisibleLast = NSNotFound;
    _containerView = [[UIView alloc] initWithFrame:CGRectZero];
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.estimatedRowHeight = _estimatedItemHeight;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.backgroundColor = UIColor.systemBackgroundColor;
    [_tableView registerClass:[UITableViewCell class]
       forCellReuseIdentifier:@"FluxListCell"];
    _searchEnabled = NO;
    _searchPlaceholder = @"Search";

    [_containerView addSubview:_tableView];
    self.contentView = _containerView;
  }

  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _containerView.frame = self.bounds;
  _tableView.frame = _containerView.bounds;
  [self applySearchConfiguration];
  [self emitVisibleRangeIfNeeded];
}

- (void)reloadTableView
{
  if (_isAnimatingNativeDelete) {
    _needsReloadAfterDeleteAnimation = YES;
    return;
  }
  if (_reloadScheduled) {
    return;
  }
  _reloadScheduled = YES;
  dispatch_async(dispatch_get_main_queue(), ^{
    _reloadScheduled = NO;
    if (_isAnimatingNativeDelete) {
      _needsReloadAfterDeleteAnimation = YES;
      return;
    }
    [_tableView reloadData];
    [self emitVisibleRangeIfNeeded];
  });
}

- (UISearchBar *)ensureSearchBar
{
  if (_searchBar) {
    return _searchBar;
  }
  UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
  searchBar.delegate = self;
  searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
  searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
  searchBar.searchBarStyle = UISearchBarStyleMinimal;
  _searchBar = searchBar;
  return _searchBar;
}

- (void)applySearchConfiguration
{
  if (!_searchEnabled) {
    if (_searchBar) {
      if (_searchBar.text.length > 0) {
        _searchBar.text = @"";
        [self emitSearchChangeWithQuery:@""];
      }
      [_searchBar resignFirstResponder];
    }
    if (_tableView.tableHeaderView != nil) {
      _tableView.tableHeaderView = nil;
    }
    return;
  }

  UISearchBar *searchBar = [self ensureSearchBar];
  searchBar.placeholder = _searchPlaceholder ?: @"Search";
  [searchBar sizeToFit];

  CGRect frame = searchBar.frame;
  CGFloat targetWidth = CGRectGetWidth(_tableView.bounds);
  if (targetWidth > 0.0) {
    frame.size.width = targetWidth;
  }
  searchBar.frame = frame;
  if (_tableView.tableHeaderView != searchBar) {
    _tableView.tableHeaderView = searchBar;
  } else {
    CGFloat widthDelta = _tableView.tableHeaderView.frame.size.width - frame.size.width;
    if (widthDelta < 0.0) {
      widthDelta = -widthDelta;
    }
    if (widthDelta <= 0.5) {
      return;
    }
    _tableView.tableHeaderView = searchBar;
  }
}

- (void)rebuildMountedItemViewMap
{
  [_itemViewsByRow removeAllObjects];
  for (NSUInteger index = 0; index < _itemViews.count; index++) {
    NSInteger row = index;
    if (index < _mountedRowIndices.count) {
      row = _mountedRowIndices[index].integerValue;
    }
    if (row >= 0) {
      _itemViewsByRow[@(row)] = _itemViews[index];
    }
  }
}

- (UIView *)mountedItemViewForRow:(NSInteger)row
{
  return _itemViewsByRow[@(row)];
}

- (NSInteger)mountedSlotForRow:(NSInteger)row
{
  NSNumber *rowNumber = @(row);
  NSUInteger slot = [_mountedRowIndices indexOfObject:rowNumber];
  if (slot != NSNotFound) {
    return (NSInteger)slot;
  }
  if (row >= 0 && row < _itemViews.count && _mountedRowIndices.count == 0) {
    return row;
  }
  return NSNotFound;
}

- (void)emitVisibleRangeIfNeeded
{
  if (!_eventEmitter || _itemCount <= 0) {
    return;
  }

  NSArray<NSIndexPath *> *visibleRows = _tableView.indexPathsForVisibleRows;
  NSInteger first = NSNotFound;
  NSInteger last = NSNotFound;
  for (NSIndexPath *indexPath in visibleRows) {
    NSInteger row = indexPath.row;
    if (row < 0 || row >= _itemCount) {
      continue;
    }
    if (first == NSNotFound || row < first) {
      first = row;
    }
    if (last == NSNotFound || row > last) {
      last = row;
    }
  }

  if (first == NSNotFound || last == NSNotFound) {
    CGFloat rowHeight = _estimatedItemHeight > 0.0 ? _estimatedItemHeight : 72.0;
    first = MAX(0, (NSInteger)floor(_tableView.contentOffset.y / rowHeight));
    NSInteger visibleCount = MAX(1, (NSInteger)ceil(CGRectGetHeight(_tableView.bounds) / rowHeight) + 1);
    last = MIN(_itemCount - 1, first + visibleCount - 1);
  }

  if (first == _lastEmittedVisibleFirst && last == _lastEmittedVisibleLast) {
    return;
  }
  _lastEmittedVisibleFirst = first;
  _lastEmittedVisibleLast = last;

  auto eventEmitter =
      std::static_pointer_cast<const FluxListViewEventEmitter>(_eventEmitter);
  if (!eventEmitter) {
    return;
  }

  FluxListViewEventEmitter::OnVisibleRangeChange event = {
      .first = static_cast<int>(first),
      .last = static_cast<int>(last),
  };
  eventEmitter->onVisibleRangeChange(event);
}

- (BOOL)animateNativeDeleteForRow:(NSInteger)row
                       completion:(void (^ _Nullable)(void))completion
{
  if (row < 0 || row >= _itemViews.count) {
    if (completion) {
      completion();
    }
    return NO;
  }
  NSInteger tableRowCount = 0;
  if (_tableView.numberOfSections > 0) {
    tableRowCount = [_tableView numberOfRowsInSection:0];
  }
  NSInteger dataRowCount = _itemViews.count;

  // If UIKit and backing data are already out of sync, skip animated delete to avoid crashes.
  if (tableRowCount <= 0 || row >= tableRowCount || tableRowCount != dataRowCount) {
    [_itemViews removeObjectAtIndex:row];
    if (_rowItemIndices && row < _rowItemIndices.count) {
      [_rowItemIndices removeObjectAtIndex:row];
    }
    [self rebuildMountedItemViewMap];
    [self reloadTableView];
    if (completion) {
      completion();
    }
    return NO;
  }

  UIView *deletingView = _itemViews[(NSUInteger)row];
  if (deletingView.superview) {
    // Detach RN content immediately so it doesn't visually linger during native row collapse.
    [deletingView removeFromSuperview];
  }

  [_itemViews removeObjectAtIndex:row];
  if (_rowItemIndices && row < _rowItemIndices.count) {
    [_rowItemIndices removeObjectAtIndex:row];
  }
  [self rebuildMountedItemViewMap];

  NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
  _isAnimatingNativeDelete = YES;
  [CATransaction begin];
  [CATransaction setCompletionBlock:^{
    _isAnimatingNativeDelete = NO;
    if (_needsReloadAfterDeleteAnimation) {
      _needsReloadAfterDeleteAnimation = NO;
      [self reloadTableView];
    }
    if (completion) {
      completion();
    }
  }];
  @try {
    [_tableView beginUpdates];
    [_tableView deleteRowsAtIndexPaths:@[ indexPath ]
                      withRowAnimation:UITableViewRowAnimationAutomatic];
    [_tableView endUpdates];
  } @catch (NSException *exception) {
    [CATransaction commit];
    [self reloadTableView];
    _isAnimatingNativeDelete = NO;
    return NO;
  }
  [CATransaction commit];
  return YES;
}

- (void)markPendingNativeDeleteForView:(UIView *)view
{
  if (!view) {
    _pendingNativeDeleteView = nil;
    _hasPendingNativeDelete = NO;
    return;
  }
  _pendingNativeDeleteView = view;
  _hasPendingNativeDelete = YES;
}

- (void)clearPendingNativeDelete
{
  _pendingNativeDeleteView = nil;
  _hasPendingNativeDelete = NO;
}

- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView
                          index:(NSInteger)index
{
  NSUInteger existingIndex = [_itemViews indexOfObjectIdenticalTo:childComponentView];
  if (existingIndex != NSNotFound) {
    [_itemViews removeObjectAtIndex:existingIndex];
    if ((NSInteger)existingIndex < index) {
      index -= 1;
    }
  }

  NSInteger safeIndex = MAX(0, MIN(index, (NSInteger)_itemViews.count));
  [_itemViews insertObject:childComponentView atIndex:(NSUInteger)safeIndex];
  [self rebuildMountedItemViewMap];

  if (_hasPendingNativeDelete || _isAnimatingNativeDelete) {
    return;
  }
  [self reloadTableView];
}

- (void)unmountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView
                            index:(NSInteger)index
{
  (void)index;
  BOOL matchesPendingDeleteView =
      _hasPendingNativeDelete && (_pendingNativeDeleteView == childComponentView);
  if (matchesPendingDeleteView) {
    if (childComponentView.superview) {
      [childComponentView removeFromSuperview];
    }
    [self clearPendingNativeDelete];
    return;
  }

  if (_hasPendingNativeDelete || _isAnimatingNativeDelete) {
    if (childComponentView.superview) {
      [childComponentView removeFromSuperview];
    }
    return;
  }

  if (childComponentView.superview) {
    [childComponentView removeFromSuperview];
  }

  NSUInteger resolvedIndex = [_itemViews indexOfObjectIdenticalTo:childComponentView];
  if (resolvedIndex == NSNotFound) {
    return;
  }

  [_itemViews removeObjectAtIndex:resolvedIndex];
  [self rebuildMountedItemViewMap];

  if (!_isAnimatingNativeDelete) {
    [self reloadTableView];
  }
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<FluxListViewProps const>(_props);
  const auto &newViewProps = *std::static_pointer_cast<FluxListViewProps const>(props);
  BOOL didUpdateSearch = NO;
  if (oldViewProps.searchEnabled != newViewProps.searchEnabled) {
    _searchEnabled = newViewProps.searchEnabled;
    didUpdateSearch = YES;
  }
  NSString *nextSearchPlaceholder =
      newViewProps.searchPlaceholder.empty()
          ? @"Search"
          : [NSString stringWithUTF8String:newViewProps.searchPlaceholder.c_str()];
  if (![_searchPlaceholder isEqualToString:nextSearchPlaceholder]) {
    _searchPlaceholder = nextSearchPlaceholder;
    didUpdateSearch = YES;
  }
  if (didUpdateSearch) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self applySearchConfiguration];
    });
  }
  if (_hasPendingNativeDelete && newViewProps.itemCount >= oldViewProps.itemCount) {
    [self clearPendingNativeDelete];
  }
  BOOL didUpdate = NO;
  if (oldViewProps.itemCount != newViewProps.itemCount) {
    _itemCount = newViewProps.itemCount < 0 ? 0 : newViewProps.itemCount;
    _lastEmittedVisibleFirst = NSNotFound;
    _lastEmittedVisibleLast = NSNotFound;
    didUpdate = YES;
  }
  if (newViewProps.estimatedItemHeight > 0.0 &&
      fabs(_estimatedItemHeight - newViewProps.estimatedItemHeight) > 0.5) {
    _estimatedItemHeight = newViewProps.estimatedItemHeight;
    _tableView.estimatedRowHeight = _estimatedItemHeight;
    didUpdate = YES;
  }
  if (!newViewProps.mountedRowIndices.empty()) {
    NSMutableArray<NSNumber *> *nextMountedRows = [NSMutableArray new];
    for (const auto rowValue : newViewProps.mountedRowIndices) {
      [nextMountedRows addObject:@(rowValue)];
    }
    if (![_mountedRowIndices isEqualToArray:nextMountedRows]) {
      _mountedRowIndices = nextMountedRows;
      [self rebuildMountedItemViewMap];
      didUpdate = YES;
    }
  } else if (_mountedRowIndices.count > 0) {
    _mountedRowIndices = [NSMutableArray new];
    [self rebuildMountedItemViewMap];
    didUpdate = YES;
  }
  if (!newViewProps.itemHeights.empty()) {
    NSUInteger count = MIN(newViewProps.itemHeights.size(), _mountedRowIndices.count);
    BOOL didUpdateHeights = NO;
    for (NSUInteger index = 0; index < count; index++) {
      CGFloat height = newViewProps.itemHeights[index];
      if (height <= 0.0) {
        continue;
      }
      NSNumber *row = _mountedRowIndices[index];
      NSNumber *nextHeight = @(height);
      if (![_itemHeightsByRow[row] isEqualToNumber:nextHeight]) {
        _itemHeightsByRow[row] = nextHeight;
        didUpdateHeights = YES;
      }
    }
    if (didUpdateHeights) {
      didUpdate = YES;
    }
  }
  if (!newViewProps.rowItemIndices.empty()) {
    NSMutableArray<NSNumber *> *nextRowIndices = [NSMutableArray new];
    for (const auto indexValue : newViewProps.rowItemIndices) {
      [nextRowIndices addObject:@(indexValue)];
    }
    if (![_rowItemIndices isEqualToArray:nextRowIndices]) {
      _rowItemIndices = nextRowIndices;
      didUpdate = YES;
    }
  } else {
    if (_rowItemIndices != nil) {
      _rowItemIndices = nil;
      didUpdate = YES;
    }
  }
  const auto &swipeActions = newViewProps.swipeActions;
  if (!swipeActions.leading.empty()) {
    _leadingSwipeActions = FluxListSwipeActionArrayFromVector(swipeActions.leading);
  } else {
    _leadingSwipeActions = nil;
  }
  if (!swipeActions.trailing.empty()) {
    _trailingSwipeActions = FluxListSwipeActionArrayFromVector(swipeActions.trailing);
  } else {
    _trailingSwipeActions = nil;
  }
  if (didUpdate && !_isAnimatingNativeDelete) {
    [self reloadTableView];
  }

  [super updateProps:props oldProps:oldProps];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return _itemCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:@"FluxListCell"
                                      forIndexPath:indexPath];
  UIView *itemView = [self mountedItemViewForRow:indexPath.row];
  if (!itemView) {
    for (UIView *subview in cell.contentView.subviews) {
      [subview removeFromSuperview];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = UIColor.systemBackgroundColor;
    cell.contentView.backgroundColor = UIColor.systemBackgroundColor;
    return cell;
  }
  CGFloat width = CGRectGetWidth(tableView.bounds);
  CGFloat height = [self rowHeightForIndex:indexPath.row
                                itemView:itemView
                               tableView:tableView];

  for (UIView *subview in cell.contentView.subviews) {
    [subview removeFromSuperview];
  }

  [itemView removeFromSuperview];
  itemView.translatesAutoresizingMaskIntoConstraints = YES;
  itemView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [cell.contentView addSubview:itemView];
  itemView.frame = CGRectMake(0, 0, width, MAX(1.0, height));
  [itemView setNeedsLayout];
  [itemView layoutIfNeeded];

  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  cell.backgroundColor = UIColor.systemBackgroundColor;
  cell.contentView.backgroundColor = UIColor.systemBackgroundColor;
  cell.clipsToBounds = NO;
  cell.contentView.clipsToBounds = NO;
  return cell;
}

#pragma mark - UITableViewDelegate

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.row >= _itemCount) {
    return NO;
  }
  NSInteger itemIndex = [self itemIndexForRow:indexPath.row];
  if (itemIndex < 0) {
    return NO;
  }
  return (_leadingSwipeActions.count > 0 || _trailingSwipeActions.count > 0);
}

- (CGFloat)tableView:(UITableView *)tableView
    heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.row >= _itemCount) {
    return tableView.estimatedRowHeight > 0.0 ? tableView.estimatedRowHeight : 1.0;
  }
  UIView *itemView = [self mountedItemViewForRow:indexPath.row];
  CGFloat height = [self rowHeightForIndex:indexPath.row
                                itemView:itemView
                               tableView:tableView];

  return height;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return [self swipeActionsConfigurationForRow:indexPath.row isLeading:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return [self swipeActionsConfigurationForRow:indexPath.row isLeading:NO];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  (void)scrollView;
  [self emitVisibleRangeIfNeeded];
}

- (NSInteger)itemIndexForRow:(NSInteger)row
{
  if (_rowItemIndices && _rowItemIndices.count == _itemCount && row < _rowItemIndices.count) {
    return _rowItemIndices[row].integerValue;
  }
  return row;
}

- (UISwipeActionsConfiguration *)swipeActionsConfigurationForRow:(NSInteger)row
                                                       isLeading:(BOOL)isLeading
{
  NSArray<FluxListSwipeAction *> *actions =
      isLeading ? _leadingSwipeActions : _trailingSwipeActions;
  if (actions.count == 0) {
    return nil;
  }

  NSInteger itemIndex = [self itemIndexForRow:row];
  if (itemIndex < 0) {
    return nil;
  }

  NSArray<FluxListSwipeAction *> *orderedActions = actions;
  // Allow native full-swipe for the first action on each side.
  // Delete keeps its custom handling below.
  BOOL allowsFullSwipeFirstAction = actions.count > 0;
  if (!isLeading) {
    NSInteger deleteActionIndex = NSNotFound;
    for (NSInteger index = 0; index < actions.count; index++) {
      if (FluxListShouldAnimateDeleteAction(actions[(NSUInteger)index])) {
        deleteActionIndex = index;
        break;
      }
    }
    if (deleteActionIndex != NSNotFound) {
      allowsFullSwipeFirstAction = YES;
      if (deleteActionIndex != 0) {
        NSMutableArray<FluxListSwipeAction *> *mutableActions = [actions mutableCopy];
        FluxListSwipeAction *deleteAction = mutableActions[(NSUInteger)deleteActionIndex];
        [mutableActions removeObjectAtIndex:(NSUInteger)deleteActionIndex];
        [mutableActions insertObject:deleteAction atIndex:0];
        orderedActions = mutableActions;
      }
    }
  }

  NSMutableArray<UIContextualAction *> *contextualActions = [NSMutableArray new];
  FluxListViewEventEmitter::OnSwipeActionSide side =
      isLeading ? FluxListViewEventEmitter::OnSwipeActionSide::Leading
                : FluxListViewEventEmitter::OnSwipeActionSide::Trailing;
  for (FluxListSwipeAction *action in orderedActions) {
    UIContextualActionStyle style =
        action.destructive ? UIContextualActionStyleDestructive : UIContextualActionStyleNormal;
    UIColor *backgroundColor = FluxListResolvedActionBackgroundColor(action);
    UIColor *foregroundColor = FluxListForegroundColorForBackground(backgroundColor);
    BOOL shouldUseCombinedIconTitleImage = NO;
    if (action.icon && action.title.length > 0) {
      if (@available(iOS 26.0, *)) {
        shouldUseCombinedIconTitleImage = NO;
      } else {
        shouldUseCombinedIconTitleImage = YES;
      }
    }
    NSString *contextualTitle = shouldUseCombinedIconTitleImage ? nil : action.title;
    UIContextualAction *contextualAction =
        [UIContextualAction contextualActionWithStyle:style
                                                title:contextualTitle
                                              handler:^(
                                                  UIContextualAction * _Nonnull actionObj,
                                                  UIView * _Nonnull sourceView,
                                                  void (^ _Nonnull completionHandler)(BOOL)) {
        if (FluxListShouldAnimateDeleteAction(action)) {
          UIView *pendingDeleteView = nil;
          pendingDeleteView = [self mountedItemViewForRow:row];
          if (!pendingDeleteView) {
            completionHandler(YES);
            [self emitSwipeActionWithKey:action.key
                                rowIndex:row
                               itemIndex:itemIndex
                                    side:side];
            return;
          }
          [self markPendingNativeDeleteForView:pendingDeleteView];
          completionHandler(YES);
          // Let UIKit finish the full-width swipe action visual before row removal.
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)),
                         dispatch_get_main_queue(), ^{
            NSUInteger pendingRow = [_itemViews indexOfObjectIdenticalTo:pendingDeleteView];
            if (pendingRow == NSNotFound) {
              [self clearPendingNativeDelete];
              [self emitSwipeActionWithKey:action.key
                                  rowIndex:row
                                 itemIndex:itemIndex
                                      side:side];
              return;
            }
            BOOL didAnimateDelete = [self animateNativeDeleteForRow:(NSInteger)pendingRow
                                                          completion:^{
              [self emitSwipeActionWithKey:action.key
                                  rowIndex:row
                                 itemIndex:itemIndex
                                      side:side];
            }];
            if (!didAnimateDelete) {
              [self clearPendingNativeDelete];
              [self emitSwipeActionWithKey:action.key
                                  rowIndex:row
                                 itemIndex:itemIndex
                                      side:side];
            }
          });
          return;
        }
        [self emitSwipeActionWithKey:action.key
                            rowIndex:row
                           itemIndex:itemIndex
                                side:side];
        completionHandler(YES);
      }];
    if (action.icon) {
      if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *symbolConfiguration =
            [UIImageSymbolConfiguration configurationWithWeight:UIImageSymbolWeightSemibold];
        UIImage *symbolImage = [UIImage systemImageNamed:action.icon
                                           withConfiguration:symbolConfiguration];
        if (symbolImage) {
          UIImage *tintedSymbolImage =
              [symbolImage imageWithTintColor:foregroundColor
                                renderingMode:UIImageRenderingModeAlwaysOriginal];
          if (shouldUseCombinedIconTitleImage) {
            UIImage *combinedImage =
                FluxListCombinedIconTitleImage(tintedSymbolImage, action.title, foregroundColor);
            contextualAction.image = combinedImage ?: tintedSymbolImage;
          } else {
            contextualAction.image = tintedSymbolImage;
          }
        }
      }
    }
    contextualAction.backgroundColor = backgroundColor;
    [contextualActions addObject:contextualAction];
  }

  UISwipeActionsConfiguration *configuration =
      [UISwipeActionsConfiguration configurationWithActions:contextualActions];
  configuration.performsFirstActionWithFullSwipe = allowsFullSwipeFirstAction;
  return configuration;
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
  [self emitSearchChangeWithQuery:searchText ?: @""];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
  [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
  searchBar.text = @"";
  [self emitSearchChangeWithQuery:@""];
  [searchBar resignFirstResponder];
}

- (void)emitSwipeActionWithKey:(NSString *)key
                      rowIndex:(NSInteger)rowIndex
                     itemIndex:(NSInteger)itemIndex
                          side:(FluxListViewEventEmitter::OnSwipeActionSide)side
{
  if (!_eventEmitter) {
    return;
  }

  auto eventEmitter =
      std::static_pointer_cast<const FluxListViewEventEmitter>(_eventEmitter);
  if (!eventEmitter) {
    return;
  }

  FluxListViewEventEmitter::OnSwipeAction event = {
      .actionKey = std::string([key UTF8String]),
      .index = static_cast<int>(itemIndex),
      .row = static_cast<int>(rowIndex),
      .side = side,
  };
  eventEmitter->onSwipeAction(event);
}

- (void)emitSearchChangeWithQuery:(NSString *)query
{
  if (!_eventEmitter) {
    return;
  }

  auto eventEmitter =
      std::static_pointer_cast<const FluxListViewEventEmitter>(_eventEmitter);
  if (!eventEmitter) {
    return;
  }

  NSString *safeQuery = query ?: @"";
  FluxListViewEventEmitter::OnSearchChange event = {
      .query = std::string([safeQuery UTF8String]),
  };
  eventEmitter->onSearchChange(event);
}

- (CGFloat)tableView:(UITableView *)tableView
estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSNumber *heightNumber = _itemHeightsByRow[@(indexPath.row)];
  if (heightNumber) {
    CGFloat height = heightNumber.doubleValue;
    if (height > 0.0) {
      return height;
    }
  }
  return _estimatedItemHeight > 0.0 ? _estimatedItemHeight : tableView.estimatedRowHeight;
}

- (CGFloat)rowHeightForIndex:(NSInteger)index
                    itemView:(UIView *)itemView
                   tableView:(UITableView *)tableView
{
  CGFloat height = 0.0;
  NSNumber *heightNumber = _itemHeightsByRow[@(index)];
  if (heightNumber) {
    height = heightNumber.doubleValue;
  }
  if (height <= 0.0 && itemView) {
    height = CGRectGetHeight(itemView.bounds);
  }
  if (height <= 0.0) {
    height = _estimatedItemHeight > 0.0 ? _estimatedItemHeight : tableView.estimatedRowHeight;
  }
  if (height <= 0.0) {
    height = 1.0;
  }

  return height;
}

@end
