package com.editablelist

import android.graphics.Color
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.viewmanagers.EditableListViewManagerInterface
import com.facebook.react.viewmanagers.EditableListViewManagerDelegate

@ReactModule(name = EditableListViewManager.NAME)
class EditableListViewManager : SimpleViewManager<EditableListView>(),
  EditableListViewManagerInterface<EditableListView> {
  private val mDelegate: ViewManagerDelegate<EditableListView>

  init {
    mDelegate = EditableListViewManagerDelegate(this)
  }

  override fun getDelegate(): ViewManagerDelegate<EditableListView>? {
    return mDelegate
  }

  override fun getName(): String {
    return NAME
  }

  public override fun createViewInstance(context: ThemedReactContext): EditableListView {
    return EditableListView(context)
  }

  @ReactProp(name = "color")
  override fun setColor(view: EditableListView?, color: Int?) {
    view?.setBackgroundColor(color ?: Color.TRANSPARENT)
  }

  companion object {
    const val NAME = "EditableListView"
  }
}
