package com.fluxlist

import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.FluxListViewManagerInterface
import com.facebook.react.viewmanagers.FluxListViewManagerDelegate

@ReactModule(name = FluxListViewManager.NAME)
class FluxListViewManager : SimpleViewManager<FluxListView>(),
  FluxListViewManagerInterface<FluxListView> {
  private val mDelegate: ViewManagerDelegate<FluxListView>

  init {
    mDelegate = FluxListViewManagerDelegate(this)
  }

  override fun getDelegate(): ViewManagerDelegate<FluxListView>? {
    return mDelegate
  }

  override fun getName(): String {
    return NAME
  }

  public override fun createViewInstance(context: ThemedReactContext): FluxListView {
    return FluxListView(context)
  }

  @ReactProp(name = "itemCount")
  override fun setItemCount(view: FluxListView?, value: Int) {
    // Native row virtualization is currently implemented on iOS only.
  }

  @ReactProp(name = "estimatedItemHeight")
  override fun setEstimatedItemHeight(view: FluxListView?, value: Double) {
    // Native row virtualization is currently implemented on iOS only.
  }

  @ReactProp(name = "itemHeights")
  override fun setItemHeights(view: FluxListView?, value: ReadableArray?) {
    // Native row virtualization is currently implemented on iOS only.
  }

  @ReactProp(name = "mountedRowIndices")
  override fun setMountedRowIndices(view: FluxListView?, value: ReadableArray?) {
    // Native row virtualization is currently implemented on iOS only.
  }

  @ReactProp(name = "rowItemIndices")
  override fun setRowItemIndices(view: FluxListView?, value: ReadableArray?) {
    // Native row virtualization is currently implemented on iOS only.
  }

  @ReactProp(name = "searchEnabled")
  override fun setSearchEnabled(view: FluxListView?, value: Boolean) {
    // Native search UI is currently implemented on iOS only.
  }

  @ReactProp(name = "searchPlaceholder")
  override fun setSearchPlaceholder(view: FluxListView?, value: String?) {
    // Native search UI is currently implemented on iOS only.
  }

  @ReactProp(name = "swipeActions")
  override fun setSwipeActions(view: FluxListView?, value: ReadableMap?) {
    // Native swipe actions are currently implemented on iOS only.
  }

  companion object {
    const val NAME = "FluxListView"
  }
}
