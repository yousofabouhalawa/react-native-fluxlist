#import <React/RCTViewComponentView.h>
#import <UIKit/UIKit.h>

#ifndef FluxListViewNativeComponent_h
#define FluxListViewNativeComponent_h

NS_ASSUME_NONNULL_BEGIN

@interface FluxListView : RCTViewComponentView <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@end

NS_ASSUME_NONNULL_END

#endif /* FluxListViewNativeComponent_h */
