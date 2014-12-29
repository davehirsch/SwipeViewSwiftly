/*
SwipeView.swift
SwipeViewSwiftly

Version 1.0, December 27, 2014
Adapted for Swift by David Hirsch on 12/27/14 from:
SwipeView 1.3.2 ( https://github.com/nicklockwood/SwipeView )

This version Copyright (C) 2014, David Hirsch, licensed under MIT License.
*/

import UIKit

internal extension Array {
    //  Extracted from:
    //  Array.swift
    //  ExSwift
    //
    //  Created by pNre on 03/06/14.
    //  Copyright (c) 2014 pNre. All rights reserved.
    //

    /**
    Checks if self contains a list of items.
    
    :param: items Items to search for
    :returns: true if self contains all the items
    */
    func contains <T: Equatable> (items: T...) -> Bool {
        return items.all { self.indexOf($0) >= 0 }
    }

    /**
    Index of the first occurrence of item, if found.
    
    :param: item The item to search for
    :returns: Index of the matched item or nil
    */
    func indexOf <U: Equatable> (item: U) -> Int? {
        if item is Element {
            return find(unsafeBitCast(self, [U].self), item)
        }
        
        return nil
    }

    /**
    Checks if test returns true for all the elements in self
    
    :param: test Function to call for each element
    :returns: True if test returns true for all the elements in self
    */
    func all (test: (Element) -> Bool) -> Bool {
        for item in self {
            if !test(item) {
                return false
            }
        }
        
        return true
    }
}

enum SwipeViewAlignment {
    case Edge
    case Center
}

protocol SwipeViewDataSource {
    func numberOfItemsInSwipeView(swipeView: SwipeView) -> Int
    func viewForItemAtIndex(index: Int, swipeView:SwipeView, reusingView:UIView?) -> UIView?
}

@objc protocol SwipeViewDelegate {
    optional func swipeViewItemSize(swipeView: SwipeView) -> CGSize
    optional func swipeViewDidScroll(swipeView: SwipeView) -> Void
    optional func swipeViewCurrentItemIndexDidChange(swipeView: SwipeView) -> Void
    optional func swipeViewWillBeginDragging(swipeView: SwipeView) -> Void
    optional func swipeViewDidEndDragging(swipeView: SwipeView, willDecelerate:Bool) -> Void
    optional func swipeViewWillBeginDecelerating(swipeView: SwipeView) -> Void
    optional func swipeViewDidEndDecelerating(swipeView: SwipeView) -> Void
    optional func swipeViewDidEndScrollingAnimation(swipeView: SwipeView) -> Void
    optional func shouldSelectItemAtIndex(index: Int, swipeView: SwipeView) -> Bool
    optional func didSelectItemAtIndex(index: Int, swipeView: SwipeView) -> Void
}

class SwipeView: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {

    private(set) var scrollView: UIScrollView?
    private(set) var itemViews: Dictionary<Int, UIView>?
    private(set) var itemViewPool: Array<UIView>?
    private(set) var previousItemIndex = 0
    private(set) var previousContentOffset = CGPointMake(0, 0)
    private(set) var itemSize = CGSizeMake(0, 0)
    private(set) var suppressScrollEvent = false
    private(set) var scrollDuration = 0.0
    private(set) var scrolling = false
    private(set) var startTime = 0.0
    private(set) var lastTime = 0.0
    private(set) var startOffset = 0.0 as CGFloat
    private(set) var endOffset = 0.0 as CGFloat
    private(set) var lastUpdateOffset = 0.0 as CGFloat
    private(set) var timer: NSTimer?

    private(set) var dataSource: SwipeViewDataSource?    // cannot be connected in IB at this time; must do it in code
    private(set) var delegate: SwipeViewDelegate?   // cannot be connected in IB at this time; must do it in code
    private(set) var numberOfItems = 0
    var numberOfPages : Int {
        return Int(ceil(Double(numberOfItems) / Double(itemsPerPage)))
    }

    // These properties are set via setProperty methods.  Could probably put those in here as setters, but that could be ugly
    private(set) var itemsPerPage = 1
    private(set) var truncateFinalPage = false
    private(set) var currentItemIndex = 0
    private(set) var alignment = SwipeViewAlignment.Center
    private(set) var scrollOffset = 0.0 as CGFloat
    private(set) var pagingEnabled = true
    private(set) var scrollEnabled = true
    private(set) var wrapEnabled = false
    private(set) var delaysContentTouches = true
    private(set) var bounces = true
    private(set) var decelerationRate = 0.0 as CGFloat
    private(set) var autoscroll = 0.0 as CGFloat
    private(set) var dragging = false
    var defersItemViewLoading = false
    private(set) var vertical = false

    
    required init(coder aDecoder: NSCoder) {
       super.init(coder: aDecoder)
        setUp()
    }
    
    required override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }
    
    //MARK: - Initialization
    func setUp() {
       
        itemViews = Dictionary(minimumCapacity: 4)
        itemViewPool = Array()
        
        self.clipsToBounds = true

        self.scrollView = UIScrollView(frame: CGRectMake(0, 0, 100, 100))    // will be modified later
        if let goodScrollView = self.scrollView {
            goodScrollView.autoresizingMask = UIViewAutoresizing.FlexibleHeight | UIViewAutoresizing.FlexibleWidth
            goodScrollView.autoresizesSubviews = true
            goodScrollView.delegate = self
            goodScrollView.delaysContentTouches = delaysContentTouches
            goodScrollView.bounces = bounces && !wrapEnabled
            goodScrollView.alwaysBounceHorizontal = !vertical && bounces
            goodScrollView.alwaysBounceVertical = vertical && bounces
            goodScrollView.pagingEnabled = pagingEnabled
            goodScrollView.scrollEnabled = scrollEnabled
            goodScrollView.decelerationRate = self.decelerationRate
            goodScrollView.showsHorizontalScrollIndicator = false
            goodScrollView.showsVerticalScrollIndicator = false
            goodScrollView.scrollsToTop = false
            goodScrollView.clipsToBounds = false

            decelerationRate = goodScrollView.decelerationRate
            previousContentOffset = goodScrollView.contentOffset
            
            let tapGesture = UITapGestureRecognizer(target: self, action: "didTap")
            tapGesture.delegate = self
            goodScrollView.addGestureRecognizer(tapGesture)
            
            //place scrollview at bottom of hierarchy
            self.insertSubview(goodScrollView, atIndex: 0)
        }
        
        if self.dataSource != nil {
            reloadData()
        }
        
    }
    
    deinit {
        if self.timer != nil {
            timer?.invalidate()
        }
    }
    
    func setDataSource(dataSource: SwipeViewDataSource) {
        // in original, we compared the old and new to see if they were changing.  Not clear how to do that in Swift
        self.dataSource = dataSource
        if (self.dataSource != nil) {
            reloadData()
        }
    }
    
    func setDelegate(delegate: SwipeViewDelegate) {
        // in original, we compared the old and new to see if they were changing.  Not clear how to do that in Swift
        self.delegate = delegate
        if (self.delegate != nil) {
            self.setNeedsLayout()
        }
    }
    
    func setAlignment(alignment: SwipeViewAlignment) {
        if self.alignment != alignment {
            self.alignment = alignment
            self.setNeedsLayout()
        }
    }
    
    func setItemsPerPage(itemsPerPage: Int) {
        if self.itemsPerPage != itemsPerPage {
            self.itemsPerPage = itemsPerPage
            self.setNeedsLayout()
        }
    }
   
    func setTruncateFinalPage(truncateFinalPage: Bool) {
        if self.truncateFinalPage != truncateFinalPage {
            self.truncateFinalPage = truncateFinalPage
            self.setNeedsLayout()
        }
    }
    
    func setScrollEnabled(scrollEnabled: Bool) {
        if self.scrollEnabled != scrollEnabled {
            self.scrollEnabled = scrollEnabled
            self.scrollView?.scrollEnabled = scrollEnabled
        }
    }
    
    func setPagingEnabled(pagingEnabled: Bool) {
        if self.pagingEnabled != pagingEnabled {
            self.pagingEnabled = pagingEnabled
            self.scrollView?.pagingEnabled = pagingEnabled
            self.setNeedsLayout()

        }
    }
    
    func setWrapEnabled(wrapEnabled: Bool) {
        if self.wrapEnabled != wrapEnabled {
            let previousOffset = self.clampedOffset(self.scrollOffset)
            self.wrapEnabled = wrapEnabled
            scrollView?.bounces = self.bounces && !wrapEnabled
            self.setNeedsLayout()
            self.scrollOffset = previousOffset
        }
    }
    
    func setDelaysContentTouches(delaysContentTouches: Bool) {
        self.delaysContentTouches = delaysContentTouches
            scrollView?.delaysContentTouches = delaysContentTouches
    }
    
    func setBounces(bounces: Bool) {
        if self.bounces != bounces {
            self.bounces = bounces
            scrollView?.alwaysBounceHorizontal = !self.vertical && self.bounces
            scrollView?.alwaysBounceVertical = self.vertical && self.bounces
            scrollView?.bounces = self.bounces && !self.wrapEnabled
        }
    }

    func setDecelerationRate(decelerationRate: CGFloat) {
        if (fabs(self.decelerationRate - decelerationRate) > 0.001) {
            self.decelerationRate = decelerationRate
            scrollView?.decelerationRate = decelerationRate
        }
    }

    func setAutoscroll(autoscroll: CGFloat) {
        if (fabs(self.autoscroll - autoscroll) > 0.001) {
            self.autoscroll = autoscroll
            if (autoscroll != 0) {
                self.startAnimation()
            }
        }
    }

    func setVertical(vertical: Bool) {
        if self.vertical != vertical {
            self.vertical = vertical
            scrollView?.alwaysBounceHorizontal = !self.vertical && self.bounces
            scrollView?.alwaysBounceVertical = self.vertical && self.bounces
            self.setNeedsLayout()
        }
    }

    func isDragging() -> Bool? {
        return scrollView?.dragging
    }

    func isDecelerating() -> Bool? {
        return scrollView?.decelerating
    }
   
    //MARK: - View management
    
    func indexesForVisibleItems() -> Array<Int> {
        if let unsortedIndexes = itemViews?.keys.array {
            return unsortedIndexes.sorted({ (n1: Int, n2: Int) -> Bool in
                return n1 < n2
            })
        }
        return Array()
    }

    func visibleItemViews() -> Array<UIView> {
        let indexesSorted = self.indexesForVisibleItems()
        var resultArrayOfViews:[UIView] = Array()
        for thisIndex in indexesSorted {
            if let foundView = itemViews![thisIndex] {
                resultArrayOfViews.append(foundView)
            }
        }
        return resultArrayOfViews
    }
    
    func itemViewAtIndex(index: Int) -> UIView? {
        return self.itemViews?[index]
    }

    func currentItemView() -> UIView? {
        return self.itemViewAtIndex(currentItemIndex)
    }
    
    /* This function gets the "index" of a view, but it's not the index in the context of any array, it's the "index" stored as a key in the dictionary, so we need to find the correct view and return the key.  There's probably a good way to do this with filter() and map(), but the set of elements in the dictionary is likely to be small, so we'll just iterate manually. */
    func indexOfItemView(view:UIView) -> Int? {
        if self.itemViews == nil {
            return nil
        }

        for (theKey, theValue) in self.itemViews! {
            if theValue === view {
                return theKey
            }
        }
        return nil
    }

    func indexOfItemViewOrSubview(view: UIView) -> Int? {
        let index = self.indexOfItemView(view)
        if (index == nil && view != scrollView) {
            // we didn't find the index, but the view is a valid view other than the scrollView, so maybe it's a subview of the indexed view.  Let's try to look up its superview instead:
            if let newViewToFind = view.superview {
                return self.indexOfItemViewOrSubview(newViewToFind)
            } else {
                return nil
            }
        }
        return index;
    }
   
    
    func setItemView(view: UIView, forIndex theIndex:Int) {
        if (self.itemViews != nil) {
            itemViews![theIndex] = view
        }
    }

    
    //MARK: - View layout
    func updateScrollOffset () {
        assert(scrollView != nil)
        if (wrapEnabled)
        {
            let itemsWide = (numberOfItems == 1) ? 1.0: 3.0
            
            if (vertical)
            {
                let scrollHeight = scrollView!.contentSize.height / CGFloat(itemsWide);
                if (scrollView!.contentOffset.y < scrollHeight)
                {
                    previousContentOffset.y += scrollHeight;
                    setContentOffsetWithoutEvent(CGPointMake(0.0, scrollView!.contentOffset.y + scrollHeight))
                }
                else if (scrollView!.contentOffset.y >= scrollHeight * 2.0)
                {
                    previousContentOffset.y -= scrollHeight;
                    setContentOffsetWithoutEvent(CGPointMake(0.0, scrollView!.contentOffset.y - scrollHeight))
                }
                scrollOffset = clampedOffset(scrollOffset)
            }
            else
            {
                let scrollWidth = scrollView!.contentSize.width / CGFloat(itemsWide)
                if (scrollView!.contentOffset.x < scrollWidth)
                {
                    previousContentOffset.x += scrollWidth;
                    setContentOffsetWithoutEvent(CGPointMake(scrollView!.contentOffset.x + scrollWidth, 0.0))
                }
                else if (scrollView!.contentOffset.x >= scrollWidth * 2.0)
                {
                    previousContentOffset.x -= scrollWidth;
                    setContentOffsetWithoutEvent(CGPointMake(scrollView!.contentOffset.x - scrollWidth, 0.0))
                }
                scrollOffset = clampedOffset(scrollOffset)
            }
        }
        if (vertical && fabs(scrollView!.contentOffset.x) > 0.0001)
        {
            setContentOffsetWithoutEvent(CGPointMake(0.0, scrollView!.contentOffset.y))
        }
        else if (!vertical && fabs(scrollView!.contentOffset.y) > 0.0001)
        {
            setContentOffsetWithoutEvent(CGPointMake(scrollView!.contentOffset.x, 0.0))
        }
    }

    func updateScrollViewDimensions () {
        assert(scrollView != nil)
        var frame = self.bounds
        var contentSize = frame.size
        
        if (vertical)
        {
            contentSize.width -= (scrollView!.contentInset.left + scrollView!.contentInset.right);
        }
        else
        {
            contentSize.height -= (scrollView!.contentInset.top + scrollView!.contentInset.bottom);
        }
        
        
        switch (alignment) {
        case .Center:
            if (vertical)
            {
                frame = CGRectMake(0.0, (self.bounds.size.height - itemSize.height * CGFloat(itemsPerPage))/2.0,
                    self.bounds.size.width, itemSize.height * CGFloat(itemsPerPage))
                contentSize.height = itemSize.height * CGFloat(numberOfItems)
            }
            else
            {
                frame = CGRectMake((self.bounds.size.width - itemSize.width * CGFloat(itemsPerPage))/2.0,
                    0.0, itemSize.width * CGFloat(itemsPerPage), self.bounds.size.height);
                contentSize.width = itemSize.width * CGFloat(numberOfItems)
            }
            
        case .Edge:
            if (vertical)
            {
                frame = CGRectMake(0.0, 0.0, self.bounds.size.width, itemSize.height * CGFloat(itemsPerPage))
                contentSize.height = itemSize.height * CGFloat(numberOfItems) - (self.bounds.size.height - frame.size.height);
            }
            else
            {
                frame = CGRectMake(0.0, 0.0, itemSize.width * CGFloat(itemsPerPage), self.bounds.size.height);
                contentSize.width = itemSize.width * CGFloat(numberOfItems) - (self.bounds.size.width - frame.size.width)
            }
        }
        
        if (wrapEnabled)
        {
            let itemsWide = CGFloat((numberOfItems == 1) ? 1.0 : Double(numberOfItems) * 3.0)
            if (vertical)
            {
                contentSize.height = itemSize.height * itemsWide;
            }
            else
            {
                contentSize.width = itemSize.width * itemsWide;
            }
        }
        else if (pagingEnabled && !truncateFinalPage)
        {
            if (vertical)
            {
                contentSize.height = ceil(contentSize.height / frame.size.height) * frame.size.height;
            }
            else
            {
                contentSize.width = ceil(contentSize.width / frame.size.width) * frame.size.width;
            }
        }
        
        if (!CGRectEqualToRect(scrollView!.frame, frame))
        {
            scrollView!.frame = frame;
        }
        
        if (!CGSizeEqualToSize(scrollView!.contentSize, contentSize))
        {
            scrollView!.contentSize = contentSize;
        }
    }

    func offsetForItemAtIndex(index:Int) -> CGFloat {
        assert(scrollView != nil)
        //calculate relative position
        var offset = CGFloat(index) - scrollOffset
        if (wrapEnabled) {
            if (alignment == SwipeViewAlignment.Center) {
                if (offset > CGFloat(numberOfItems)/2.0) {
                    offset -= CGFloat(numberOfItems)
                }
                else if (offset < -CGFloat(numberOfItems)/2.0) {
                    offset += CGFloat(numberOfItems)
                }
            } else {
                let width = vertical ? self.bounds.size.height : self.bounds.size.width
                let x = vertical ? scrollView!.frame.origin.y : scrollView!.frame.origin.x
                let itemWidth = vertical ? itemSize.height : itemSize.width
                if (offset * itemWidth + x > width) {
                    offset -= CGFloat(numberOfItems)
                }
                else if (offset * itemWidth + x < -itemWidth) {
                    offset += CGFloat(numberOfItems)
                }
            }
        }
        return offset;
    }

    func setFrameForView(view: UIView, atIndex index:Int) {
        assert(scrollView != nil)
        if ((self.window) != nil) {
            var center = view.center
            if (vertical) {
                center.y = (offsetForItemAtIndex(index) + 0.5) * itemSize.height + scrollView!.contentOffset.y;
            } else {
                center.x = (offsetForItemAtIndex(index) + 0.5) * itemSize.width + scrollView!.contentOffset.x;
            }
            
            let disableAnimation = !CGPointEqualToPoint(center, view.center)
            let animationEnabled = UIView.areAnimationsEnabled()
            if (disableAnimation && animationEnabled) {
                UIView.setAnimationsEnabled(false)
            }
            if (vertical) {
                view.center = CGPointMake(scrollView!.frame.size.width/2.0, center.y)
            } else {
                view.center = CGPointMake(center.x, scrollView!.frame.size.height/2.0)
            }
            
            view.bounds = CGRectMake(0.0, 0.0, itemSize.width, itemSize.height)
            
            if (disableAnimation && animationEnabled) {
                UIView.setAnimationsEnabled(true)
            }
        }
    }
    
    func layOutItemViews()  {
        let visibleViews = self.visibleItemViews()
        for view in visibleViews {
            if let theIndex = self.indexOfItemView(view) {
                setFrameForView(view, atIndex:theIndex)
            }
        }
    }
    
    func updateLayout() {
        updateScrollOffset()
        loadUnloadViews()
        layOutItemViews()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateItemSizeAndCount()
        updateScrollViewDimensions()
        updateLayout()
        if pagingEnabled && !scrolling {
            scrollToItemAtIndex(self.currentItemIndex, duration:0.25)
        }
    }

    //MARK: - View queing
    
    func queueItemView(view: UIView) {
        itemViewPool?.append(view)
    }
    
    func dequeueItemView() -> UIView? {
        if itemViewPool == nil {
            return nil
        }
        if itemViewPool!.count <= 0 {
            return nil
        }
        let view = itemViewPool!.removeLast()
        return view;
    }
    
    //MARK: - Scrolling
    
    func didScroll() {
        //handle wrap
        updateScrollOffset()
        
        //update view
        layOutItemViews()
        delegate?.swipeViewDidScroll?(self)
        
        if (!defersItemViewLoading || (fabs(minScrollDistanceFromOffset(lastUpdateOffset, toOffset:scrollOffset)) >= 1.0)) {
            //update item index
            currentItemIndex = clampedIndex(Int(roundf(Float(scrollOffset))))
            
            //load views
            lastUpdateOffset = CGFloat(currentItemIndex)
            loadUnloadViews()
            
            //send index update event
            if (previousItemIndex != currentItemIndex) {
                previousItemIndex = currentItemIndex
                delegate?.swipeViewCurrentItemIndexDidChange?(self)
            }
        }
    }

    func easeInOut(time: CGFloat) -> CGFloat {
        return (time < 0.5) ? 0.5 * pow(time * 2.0, 3.0) : 0.5 * pow(time * 2.0 - 2.0, 3.0) + 1.0
    }
    
    func step() {
        assert(scrollView != nil)
        let currentTime = CFAbsoluteTimeGetCurrent()
        var delta = CGFloat(lastTime - currentTime)
        self.lastTime = currentTime
        
        if (scrolling) {
            let time = CGFloat(fmin(1.0, (currentTime - startTime) / scrollDuration))
            delta = easeInOut(time)
            scrollOffset = clampedOffset(startOffset + (endOffset - startOffset) * delta)
            if (vertical) {
                setContentOffsetWithoutEvent(CGPointMake(0.0, scrollOffset * itemSize.height))
            } else {
                setContentOffsetWithoutEvent(CGPointMake(scrollOffset * itemSize.width, 0.0))
            }
            didScroll()
            if (time == 1.0) {
                scrolling = false
                didScroll()
                delegate?.swipeViewDidEndScrollingAnimation?(self)
            }
        } else if (autoscroll != 0.0) {
            if (!scrollView!.dragging) {
                self.scrollOffset = clampedOffset(scrollOffset + delta * autoscroll)
            }
        } else {
            stopAnimation()
        }
    }
    
    func startAnimation() {
        if (timer == nil) {
            self.timer = NSTimer(timeInterval: 1.0/60.0, target: self, selector: "step", userInfo: nil, repeats: true)
            NSRunLoop.mainRunLoop().addTimer(timer!, forMode:NSDefaultRunLoopMode)
            NSRunLoop.mainRunLoop().addTimer(timer!, forMode:UITrackingRunLoopMode)
        }
    }
    
    func stopAnimation() {
        if timer != nil {
            timer!.invalidate()
            self.timer = nil;
        }
    }
    
    func clampedIndex(index: Int) -> Int {
        if (wrapEnabled) {
            if numberOfItems != 0 {
                return index - Int(CGFloat(floor(CGFloat(index) / CGFloat(numberOfItems))) * CGFloat(numberOfItems))
            } else {
                return 0
            }
        } else {
            return min(max(0, index), max(0, numberOfItems - 1))
        }
    }
    
    func clampedOffset(offset: CGFloat) -> CGFloat {
        var returnValue = CGFloat(0)
        if (wrapEnabled) {
            if numberOfItems != 0 {
                returnValue =  (offset - floor(offset / CGFloat(numberOfItems)) * CGFloat(numberOfItems))
            } else {
                returnValue = 0.0
            }
        } else {
            returnValue = fmin(fmax(0.0, offset), fmax(0.0, CGFloat(numberOfItems) - 1.0))
        }
        return returnValue;
    }

    func setContentOffsetWithoutEvent(contentOffset:CGPoint) {
        assert(scrollView != nil)
        if (!CGPointEqualToPoint(scrollView!.contentOffset, contentOffset))
        {
            let animationEnabled = UIView.areAnimationsEnabled()
            if (animationEnabled) {
                UIView.setAnimationsEnabled(false)
            }
            suppressScrollEvent = true
            scrollView!.contentOffset = contentOffset
            suppressScrollEvent = false
            if (animationEnabled) {
                UIView.setAnimationsEnabled(true)
            }
        }
    }
    
    func currentPage() -> Int {
        if (itemsPerPage > 1
            && truncateFinalPage
            && !wrapEnabled
            && currentItemIndex > (numberOfItems / itemsPerPage - 1) * itemsPerPage) {
                return numberOfPages - 1
        }
        return Int(round(Double(currentItemIndex) / Double(itemsPerPage)))
    }
    
 
    func minScrollDistanceFromIndex(fromIndex: Int, toIndex:Int) -> Int {
        let directDistance = toIndex - fromIndex
        if (wrapEnabled) {
            var wrappedDistance = min(toIndex, fromIndex) + numberOfItems - max(toIndex, fromIndex)
            if (fromIndex < toIndex) {
                wrappedDistance = -wrappedDistance
            }
            return (abs(directDistance) <= abs(wrappedDistance)) ? directDistance : wrappedDistance
        }
        return directDistance;
    }
    
    func minScrollDistanceFromOffset(fromOffset:CGFloat, toOffset:CGFloat) -> CGFloat {
        let directDistance = toOffset - fromOffset
        if (wrapEnabled) {
            var wrappedDistance = min(toOffset, fromOffset) + CGFloat(numberOfItems) - max(toOffset, fromOffset)
            if (fromOffset < toOffset) {
                wrappedDistance = -wrappedDistance
            }
            return (abs(directDistance) <= abs(wrappedDistance)) ? directDistance : wrappedDistance
        }
        return directDistance;
    }

    func setCurrentItemIndex(currentItemIndex: Int) {
        self.currentItemIndex = currentItemIndex
        scrollOffset = CGFloat(currentItemIndex)
    }
    
    func setCurrentPage(currentPage: Int) {
        if (currentPage * itemsPerPage != currentItemIndex) {
            scrollToPage(currentPage, duration:0.0)
        }
    }
    
    func setScrollOffset(scrollOffset:CGFloat) {
        if (abs(self.scrollOffset - scrollOffset) > 0.0001) {
            self.scrollOffset = scrollOffset
            lastUpdateOffset = self.scrollOffset - 1.0; //force refresh
            scrolling = false; //stop scrolling
            updateItemSizeAndCount()
            updateScrollViewDimensions()
            updateLayout()
            let contentOffset = vertical
                ? CGPointMake(0.0, clampedOffset(scrollOffset) * itemSize.height)
                : CGPointMake(clampedOffset(scrollOffset) * itemSize.width, 0.0)
            setContentOffsetWithoutEvent(contentOffset)
            didScroll()
        }
    }
    
    func scrollByOffset(offset: CGFloat, duration:NSTimeInterval) {
        if (duration > 0.0) {
            scrolling = true
            startTime = NSDate.timeIntervalSinceReferenceDate()
            startOffset = scrollOffset
            scrollDuration = duration
            endOffset = startOffset + offset
            if (!wrapEnabled) {
                endOffset = clampedOffset(endOffset)
            }
            startAnimation()
        } else {
            self.scrollOffset += offset
        }
    }

    func scrollToOffset(offset: CGFloat, duration:NSTimeInterval) {
        scrollByOffset(minScrollDistanceFromOffset(scrollOffset, toOffset:offset), duration:duration)
    }
    
    func scrollByNumberOfItems(itemCount: Int, duration:NSTimeInterval) {
        if (duration > 0.0) {
            var offset = Float(0.0)
            if (itemCount > 0) {
                offset = floorf(Float(scrollOffset)) + Float(itemCount) - Float(scrollOffset)
            } else if (itemCount < 0) {
                offset = ceilf(Float(scrollOffset)) + Float(itemCount) - Float(scrollOffset)
            } else {
                offset = roundf(Float(scrollOffset)) - Float(scrollOffset)
            }
            scrollByOffset(CGFloat(offset), duration:duration)
        } else {
            scrollOffset = CGFloat(clampedIndex(previousItemIndex + itemCount))
        }
    }
    

    func scrollToItemAtIndex(index:Int, duration:NSTimeInterval) {
        scrollToOffset(CGFloat(index), duration:duration)
    }
    
    func scrollToPage(page: Int, duration:NSTimeInterval) {
        var index = page * itemsPerPage
        if (truncateFinalPage) {
            index = min(index, numberOfItems - itemsPerPage)
        }
        scrollToItemAtIndex(index, duration:duration)
    }

    //MARK: - View loading
    
    func loadViewAtIndex(index: Int) -> UIView {
        var view = dataSource?.viewForItemAtIndex(index, swipeView: self, reusingView: dequeueItemView())
        if (view == nil) {
            view = UIView()
        }
        
        let oldView = itemViewAtIndex(index)
        if (oldView != nil) {
            queueItemView(oldView!)
            oldView!.removeFromSuperview()
        }
        
        setItemView(view!, forIndex:index)
        setFrameForView(view!, atIndex:index)
        view!.userInteractionEnabled = true
        scrollView?.addSubview(view!)
        
        return view!;
    }

    func updateItemSizeAndCount() {
        //get number of items
        numberOfItems = (dataSource?.numberOfItemsInSwipeView(self))!
        
        //get item size
        let size = delegate?.swipeViewItemSize?(self)
        if (!CGSizeEqualToSize(size!, CGSizeZero)) {
            itemSize = size!;
        } else if (numberOfItems > 0) {
            if self.visibleItemViews().count <= 0 {
                let view = dataSource?.viewForItemAtIndex(0, swipeView: self, reusingView: dequeueItemView())
                itemSize = view!.frame.size;
            }
        }
        
        //prevent crashes
        if (itemSize.width < 0.0001) { itemSize.width = 1 }
        if (itemSize.height < 0.0001) { itemSize.height = 1 }
    }
    
    func loadUnloadViews() {
        assert(scrollView != nil)
        //check that item size is known
        let itemWidth = vertical ? itemSize.height : itemSize.width
        if (itemWidth != 0) {
            //calculate offset and bounds
            let width = vertical ? self.bounds.size.height : self.bounds.size.width
            let x = vertical ? scrollView!.frame.origin.y : scrollView!.frame.origin.x
            
            //calculate range
            let startOffset = clampedOffset(scrollOffset - x / itemWidth)
            var startIndex = Int(floor(startOffset))
            var numberOfVisibleItems = Int(ceil(width / itemWidth + (startOffset - CGFloat(startIndex))))
            if (defersItemViewLoading) {
                startIndex = currentItemIndex - Int(ceil(x / itemWidth)) - 1
                numberOfVisibleItems = Int(ceil(width / itemWidth) + 3)
            }
            
            //create indices
            numberOfVisibleItems = min(numberOfVisibleItems, numberOfItems)
            var visibleIndices = [Int]()
            
            for (var i = 0; i < numberOfVisibleItems; i++) {
                let index = clampedIndex(i + startIndex)
                visibleIndices.append(index)
            }
            
            //remove offscreen views
            for number in itemViews!.keys.array {
                if (!visibleIndices.contains(number)) {
                    if (itemViews != nil) {
                        let view = itemViews![number]
                        if (view != nil) {
                            queueItemView(view!)
                            view!.removeFromSuperview()
                            itemViews!.removeValueForKey(number)
                        }
                    }
                }
            }
            
            //add onscreen views
            for number in visibleIndices {
                let view = itemViews![number]
                if (view == nil) {
                    loadViewAtIndex(number)
                }
            }
        }
    }
    
    func reloadItemAtIndex(index:Int) {
        //if view is visible
        if (itemViewAtIndex(index) != nil) {
            //reload view
            loadViewAtIndex(index)
        }
    }

    func reloadData() {
        //remove old views
        for view in self.visibleItemViews() {
            view.removeFromSuperview()
        }
        
        //reset view pools
        itemViews = Dictionary(minimumCapacity: 4)
        itemViewPool = Array()
        
        //get number of items
        updateItemSizeAndCount()
        
        //layout views
        setNeedsLayout()
        
        //fix scroll offset
        if (numberOfItems > 0 && scrollOffset < 0.0) {
            self.scrollOffset = 0;
        }
    }
    
    override func hitTest(point: CGPoint, withEvent event:UIEvent?) -> UIView? {
        assert(scrollView != nil)
        var view = super.hitTest(point, withEvent:event)
        if (view == nil) {
            return view
        }
        if (view!.isEqual(self)) {
            for subview in scrollView!.subviews {
                let offset = CGPointMake(point.x - scrollView!.frame.origin.x + scrollView!.contentOffset.x - subview.frame.origin.x,
                    point.y - scrollView!.frame.origin.y + scrollView!.contentOffset.y - subview.frame.origin.y);
                view = subview.hitTest(offset, withEvent:event)
                if (view != nil)
                {
                    return view;
                }
            }
            return scrollView!;
        }
        return view;
    }

    override func didMoveToSuperview() {
        if (self.superview != nil) {
            self.setNeedsLayout()
            if scrolling {
                startAnimation()
            }
        } else {
            stopAnimation()
        }
    }

    //MARK: - Gestures and taps
    
    func viewOrSuperviewIndex(view: UIView) -> Int? {
        assert(scrollView != nil)
        if (view == scrollView!) {
            return nil
        }
        let index = self.indexOfItemView(view)
        if (index == nil)
        {
            if (view.superview == nil) {
                return nil
            }
            return viewOrSuperviewIndex(view.superview!)
        }
        return index;
    }
    
    func viewOrSuperviewHandlesTouches(view:UIView) -> Bool {
        // This implementation is pretty different from the original, because many of the class-exposure methods are not present in Swift.  The original seems needlessly complex, checking all the superclasses of the view as well.
        if view.respondsToSelector(Selector("touchesBegan:withEvent:")) {
            return true
        } else {
            if let theSuperView = view.superview {
                return self.viewOrSuperviewHandlesTouches(theSuperView)
            } else {
                // there's no superview to check, so nothing in the hierarchy can respond.
                return false
            }
        }
    }

    func gestureRecognizer(gesture: UIGestureRecognizer, shouldReceiveTouch touch:UITouch) -> Bool {
        if (gesture is UITapGestureRecognizer) {
            //handle tap
            let index = viewOrSuperviewIndex(touch.view)
            if (index != nil) {
                var delegateExistsAndDeclinesSelection = false
                if (delegate != nil) {
                    if let delegateWantsItemSelection = delegate!.shouldSelectItemAtIndex?(index!, swipeView: self) {
                        // delegate is valid and responded to the shouldSelectItemAtIndex selector
                        delegateExistsAndDeclinesSelection = !delegateWantsItemSelection
                    }
                }
                if delegateExistsAndDeclinesSelection ||
                    self.viewOrSuperviewHandlesTouches(touch.view) {
                        return false
                } else {
                    return true
                }
            }
        }
        return false
    }
    
    func didTap (tapGesture: UITapGestureRecognizer) {
        let point = tapGesture.locationInView(scrollView)
        var index = Int(vertical ? (point.y / (itemSize.height)) : (point.x / (itemSize.width)))
        if (wrapEnabled) {
            index = index % numberOfItems
        }
        if (index >= 0 && index < numberOfItems) {
            delegate?.didSelectItemAtIndex?(index, swipeView: self)
        }
    }

    //MARK: - UIScrollViewDelegate methods

    func scrollViewDidScroll(scrollView: UIScrollView) {
        if (!suppressScrollEvent) {
            //stop scrolling animation
            scrolling = false
            
            //update scrollOffset
            let delta = vertical ? (scrollView.contentOffset.y - previousContentOffset.y) : (scrollView.contentOffset.x - previousContentOffset.x)
            previousContentOffset = scrollView.contentOffset
            scrollOffset += delta / (vertical ? itemSize.height : itemSize.width)
            
            //update view and call delegate
            didScroll()
        } else {
            previousContentOffset = scrollView.contentOffset
        }
    }

    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        delegate?.swipeViewWillBeginDragging?(self)
        
        //force refresh
        lastUpdateOffset = self.scrollOffset - 1.0
        didScroll()
    }
    
    func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate:Bool) {
        if (!decelerate) {
            //force refresh
            lastUpdateOffset = self.scrollOffset - 1.0
            didScroll()
        }
        delegate?.swipeViewDidEndDragging?(self, willDecelerate:decelerate)
    }
    
    func scrollViewWillBeginDecelerating(scrollView: UIScrollView) {
        delegate?.swipeViewWillBeginDecelerating?(self)
    }
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        //prevent rounding errors from accumulating
        let integerOffset = CGFloat(round(scrollOffset))
        if (fabs(scrollOffset - integerOffset) < 0.01) {
            scrollOffset = integerOffset
        }
        
        //force refresh
        lastUpdateOffset = self.scrollOffset - 1.0
        didScroll()
        
        delegate?.swipeViewDidEndDecelerating?(self)
    }

}
