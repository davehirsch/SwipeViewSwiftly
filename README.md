SwipeViewSwiftly
================

A Swift adaptation of SwipeView

The original [SwipeView](https://github.com/nicklockwood/SwipeView) is (c) 2010 by Nick Lockwood, and is licensed under something like the MIT license:

These docs are also adapted from the original SwipeView:

Purpose
--------------

SwipeView is a class designed to simplify the implementation of horizontal, paged scrolling views on iOS. It is based on a UIScrollView, but adds convenient functionality such as a UITableView-style dataSource/delegate interface for loading views dynamically, and efficient view loading, unloading and recycling.

SwipeView's interface and implementation is based on the iCarousel library, and should be familiar to anyone who has used iCarousel.


Supported OS & SDK Versions
-----------------------------

* Supported build target - iOS 8.1 (Xcode 6)
* Earliest supported deployment target - iOS 7.1

NOTE: 'Supported' means that the library has been tested with this version. 'Compatible' means that the library should work on this OS version (i.e. it doesn't rely on any unavailable SDK features) but is no longer being tested for compatibility and may require tweaking or bug fixes to run correctly.


Thread Safety
--------------

SwipeView is derived from UIView and - as with all UIKit components - it should only be accessed from the main thread. You may wish to use threads for loading or updating SwipeView contents or items, but always ensure that once your content has loaded, you switch back to the main thread before updating the SwipeView.


Installation
--------------

To use the SwipeView class in an app, just drag the SwipeView .swift (demo files and assets are not needed) into your project.  See ViewController.swift for guidelines on incorporating it into your app.


Explicitly Settable Properties
--------------

The SwipeView has the following properties that are settable externally:

defersItemViewLoading: Bool

Sometimes when your SwipeView contains very complex item views, or large images, there can be a noticeable jerk in scrolling performance as it loads the new views. Setting the `defersItemViewLoading` property to `true` forces the SwipeView to defer updating the currentItemIndex property and loading of new item views until after the scroll has finished. This can result in visible gaps in the SwipeView if you scroll too far in one go, but for scrolling short distances you may find that this improves animation performance.

Read-Only Properties
--------------

The SwipeView has the following properties that are read-only as properties, but are settable via `setPropertyName(newValue)` methods, or via delegate methods:

    dataSource: SwipeViewDataSource?

An object that supports the SwipeViewDataSource protocol and can provide views to populate the SwipeView.  Currently this must be linked in code, not in Interface Builder.

    delegate: SwipeViewDelegate?

An object that supports the SwipeViewDelegate protocol and can respond to SwipeView events and layout requests. Currently this must be linked in code, not in Interface Builder.

    numberOfItems: Int

The number of items in the SwipeView. To set this, implement the `numberOfItemsInSwipeView()` dataSource method. Note that not all of these item views will be loaded or visible at a given point in time - the SwipeView loads item views on demand as it scrolls.

    numberOfPages : Int

The number of pages in the SwipeView. To set this, implement the `numberOfItemsInSwipeView()` dataSource method and set the `itemsPerPage` value. If `itemsPerPage` = 1, numberOfPages will match the `numberOfItems`.

    itemSize: CGSize

The size of each item in the SwipeView. This property can be set using the `swipeViewItemSize()` delegate method.

    itemsPerPage: Int

The number of items per page when paging is enabled. Defaults to one;

    truncateFinalPage: Bool

If the number of items is not exactly divisible by the itemsPerPage value then it can result in blank space on the last page. By setting truncateFinalPage to true, you can eliminate that space.

    currentItemIndex: Int

The index of the first item of the currently centered (or left-aligned, depending on the alignment value) page. Setting this value is equivalent to calling `scrollToItemAtIndex:duration:` with the duration argument set to 0.0.

    alignment: SwipeViewAlignment

This property controls how the SwipeView items are aligned. The default value of `SwipeViewAlignmentEdge` means that the item views will extend to the edges of the SwipeView. Switching the alignment to `SwipeViewAlignmentCenter` means that the leftmost and rightmost item views will be centered when the SwipeView is fully scrolled to either extreme.

    pagingEnabled: Bool

Enables and disables paging. When paging is enabled, the SwipeView will stop at each item view as the user scrolls.

    scrollEnabled: Bool

Enables and disables user scrolling of the SwipeView. The SwipeView can still be scrolled programmatically if this property is set to false.

    wrapEnabled: Bool

Enables and disables wrapping. When in wrapped mode, the SwipeView can be scrolled indefinitely and will wrap around to the first item view when it reaches past the last item. When wrap is enabled, the bounces property has no effect.

    vertical: Bool

This property toggles whether the SwipeView is displayed horizontally or vertically on screen.

    delaysContentTouches: Bool

This property works like the equivalent property of UIScrollView. It defers handling of touch events on subviews within the SwipeView so that embedded controls such as buttons do not interfere with the smooth scrolling of the SwipeView. Defaults to true.

    bounces: Bool

Sets whether the SwipeView should bounce past the end and return, or stop dead.

    decelerationRate: CGFloat

A floating-point value that determines the rate of deceleration after the user lifts their finger.

    dragging: Bool

Returns true if user has started scrolling the SwipeView and has not yet released it.

    scrolling: Bool

Returns true if the SwipeView is currently being scrolled programatically.

    autoscroll: CGFloat

This property can be used to set the SwipeView scrolling at a constant speed. A value of 1.0 would scroll the SwipeView forwards at a rate of one item per second. The autoscroll value can be positive or negative and defaults to 0.0 (stationary). Autoscrolling will stop if the user interacts with the SwipeView, and will resume when they stop.


Methods
--------------

The SwipeView class has the following publicly interesting methods, in addition to all the setter methods for the read-only properties above

    reloadData()

This reloads all SwipeView item views from the dataSource and refreshes the display. Note that reloadData will reset the currentItemIndex back to zero, so if you want to retain the current scroll position, make a note of currentItemIndex before reloading and restore it afterwards. If you just wish to refresh the visible items without changing the number of items, consider calling `reloadItemAtIndex:` on all visible items instead.

    func reloadItemAtIndex(index:Int) 

This method will reload the specified item view. The new item will be requested from the dataSource. Off-screen views will not be reloaded.

    func indexesForVisibleItems() -> Array<Int> 

Returns an array containing the indexes of all item views currently loaded and visible in the SwipeView. The array contains Ints whose values match the indexes of the views. The indexes for item views start at zero and match the indexes passed to the dataSource to load the view.

    func visibleItemViews() -> Array<UIView>

Returns an array of all the item views currently displayed in the SwipeView. The indexes of views in this array do not match the item indexes, however the order of these views matches the order of the visibleItemIndexes array property, i.e. you can get the item index of a given view in this array by retrieving the equivalent object from the visibleItemIndexes array (or, you can just use the `indexOfItemView:` method, which is much easier).

    func currentItemView() -> UIView?

Returns the first item view of the currently centered (or left-aligned, depending on the alignment value) page.

    func currentPage() -> Int

Returns the index of the currently centered (or left-aligned, depending on the alignment value) page. If `itemsPerPage` is equal to one, this value will match the currentItemIndex value. Setting this value is value is equivalent to calling `scrollToPage:duration:` with the duration argument set to 0.0.

    func scrollByNumberOfItems(itemCount: Int, duration:NSTimeInterval)

This method allows you to scroll the SwipeView by a fixed distance, measured in item widths. Positive or negative values may be specified for itemCount, depending on the direction you wish to scroll. SwipeView gracefully handles bounds issues, so if you specify a distance greater than the number of items in the SwipeView, scrolling will be clamped when it reaches the end of the SwipeView.

    func scrollToItemAtIndex(index:Int, duration:NSTimeInterval) 

This will center the SwipeView on the specified item, either immediately or with a smooth animation.

    func scrollToPage(page: Int, duration:NSTimeInterval) 

This will center the SwipeView on the specified item, either immediately or with a smooth animation.

    func itemViewAtIndex(index: Int) -> UIView? 

Returns the visible item view with the specified index. Note that the index relates to the position in the SwipeView, and not the position in the `visibleItemViews` array, which may be different. The method only works for visible item views and will return nil if the view at the specified index has not been loaded, or if the index is out of bounds.

    func indexOfItemView(view:UIView) -> Int? 

The index for a given item view in the SwipeView. This function gets the "index" of a view, but it's not the index in the context of any array, it's the "index" stored as a key in the dictionary. This method only works for visible item views and will return nil for views that are not currently loaded. For a list of all currently loaded views, use the `visibleItemViews` property.

    func indexOfItemViewOrSubview(view: UIView) -> Int?

This method gives you the item index of either the view passed or the view containing the view passed as a parameter. It works by walking up the view hierarchy starting with the view passed until it finds an item view and returns its index within the SwipeView. If no currently-loaded item view is found, it returns nil. This method is extremely useful for handling events on controls embedded within an item view. This allows you to bind all your item controls to a single action method on your view controller, and then work out which item the control that triggered the action was related to.

    func isDragging() -> Bool?

Returns true if the user is dragging the SwipeView

    func isDecelerating() -> Bool? 

Returns true if the user isn't dragging the SwipeView any more, but it is still moving.


Protocols
---------------

The SwipeView follows the Apple convention for data-driven views by providing two protocol interfaces, SwipeViewDataSource and SwipeViewDelegate. 

### The SwipeViewDataSource protocol has the following required methods:

    func numberOfItemsInSwipeView(swipeView: SwipeView) -> Int

Provides the number of items (views) in the SwipeView.

    func viewForItemAtIndex(index: Int, swipeView:SwipeView, reusingView:UIView?) -> UIView?

Provides a view to be displayed at the specified index in the SwipeView. The `reusingView` argument works like a UIPickerView, where views that have previously been displayed in the SwipeView are passed back to the method to be recycled. If this argument is not nil, you can set its properties and return it instead of creating a new view instance, which will slightly improve performance. Unlike UITableView, there is no reuseIdentifier for distinguishing between different SwipeView view types, so if your SwipeView contains multiple different view types then you should just ignore this parameter and return a new view each time the method is called. You should ensure that each time the `viewForItemAtIndex:swipeView:reusingView:` method is called, it either returns the reusingView or a brand new view instance rather than maintaining your own pool of recyclable views, as returning multiple copies of the same view for different SwipeView item indexes may cause display issues with the SwipeView.

### The SwipeViewDelegate protocol has the following methods, all of which are optional:

    func swipeViewItemSize(swipeView: SwipeView) -> CGSize

Provides the size in points/pixels of each item view. If this method is not implemented, the item size is automatically calculated from the first item view that is loaded.

    func swipeViewDidScroll(swipeView: SwipeView) -> Void

This method is called whenever the SwipeView is scrolled. It is called regardless of whether the SwipeView was scrolled programatically or through user interaction.

    func swipeViewCurrentItemIndexDidChange(swipeView: SwipeView) -> Void

This method is called whenever the SwipeView scrolls far enough for the currentItemIndex property to change. It is called regardless of whether the item index was updated programatically or through user interaction.

    func swipeViewWillBeginDragging(swipeView: SwipeView) -> Void

This method is called when the SwipeView is about to start moving as the result of the user dragging it.

    func swipeViewDidEndDragging(swipeView: SwipeView, willDecelerate:Bool) -> Void

This method is called when the user stops dragging the SwipeView. The willDecelerate parameter indicates whether the SwipeView is travelling fast enough that it needs to decelerate before it stops (i.e. the current index is not necessarily the one it will stop at) or if it will stop where it is. Note that even if willDecelerate is false, if paging is enabled, the SwipeView will still scroll automatically until it aligns exactly on the current index.

    func swipeViewWillBeginDecelerating(swipeView: SwipeView) -> Void

This method is called when the SwipeView is about to start decelerating after the user has finished dragging it.

    func swipeViewDidEndDecelerating(swipeView: SwipeView) -> Void

This method is called when the SwipeView finishes decelerating and you can assume that the currentItemIndex at this point is the final stopping value.

    func swipeViewDidEndScrollingAnimation(swipeView: SwipeView) -> Void

This method is called when the SwipeView finishes moving after being scrolled programmatically using the `scrollByNumberOfItems:` or `scrollToItemAtIndex:` methods.

    func didSelectItemAtIndex(index: Int, swipeView: SwipeView) -> Void

This method will fire if the user taps any SwipeView item view. This method will not fire if the user taps a control within the currently selected view (i.e. any view that is a subclass of UIControl).

    func shouldSelectItemAtIndex(index: Int, swipeView: SwipeView) -> Bool

This method will fire if the user taps any SwipeView item view. The purpose of a method is to give you the opportunity to ignore a tap on the SwipeView. If you return true from the method, or don't implement it, the tap will be processed as normal and the `swipeView:didSelectItemAtIndex:` method will be called. If you return false, the SwipeView will ignore the tap and it will continue to propagate up the view hierarchy. This is a good way to prevent the SwipeView intercepting tap events intended for processing by another view.


Detecting Taps on Item Views
----------------------------

There are two basic approaches to detecting taps on views in SwipeView. The first approach is to simply use the `swipeView:didSelectItemAtIndex:` delegate method, which fires every time an item is tapped.

Alternatively, if you want a little more control you can supply a UIButton or UIControl as the item view and handle the touch interactions yourself.

You can also nest UIControls within your item views and these will receive touches as expected (See the Controls Example project for how this can be done).

If you wish to detect other types of interaction such as swipes, double taps or long presses, the simplest way is to attach a UIGestureRecognizer to your item view or its subviews before passing it to the SwipeView.


Release Notes
----------------

Version 1.0

- Initial Release
- No tests created yet
- Basic testing performed