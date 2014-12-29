/*
ViewController.swift
SwipeViewSwiftly

Version 1.0, December 27, 2014
Adapted for Swift by David Hirsch on 12/27/14 from:
SwipeView 1.3.2 ( https://github.com/nicklockwood/SwipeView )

This version Copyright (C) 2014, David Hirsch, licensed under MIT License.
*/

import UIKit

class ViewController: UIViewController, SwipeViewDataSource, SwipeViewDelegate {

    @IBOutlet weak var swipeView: SwipeView!
    var items: [Int]
    
    required init(coder aDecoder: NSCoder) {
        items = Array()
        for i in [1...100] {
            items += i
        }
        super.init(coder: aDecoder)
        
    }

    //MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        swipeView.setDelegate(self)
        swipeView.setDataSource(self)
        swipeView.setPagingEnabled(true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: - SwipeViewDataSource functions
    
    func numberOfItemsInSwipeView(swipeView: SwipeView) -> Int {
        return items.count
    }

    func viewForItemAtIndex(index: Int, swipeView: SwipeView, reusingView: UIView?) -> UIView? {
        var label : UILabel
        var returnedView : UIView
        
        //create new view if no view is available for recycling
        if (reusingView == nil) {
            //don't do anything specific to the index within
            //this `if (view == nil) {...}` statement because the view will be
            //recycled and used with other index values later
            returnedView = UIView(frame: self.swipeView.bounds)
            returnedView.autoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleHeight
            let insetRect = CGRectInset(returnedView.bounds, 15, 25)
            label = UILabel(frame: insetRect)
            label.layer.cornerRadius = 10
            label.layer.masksToBounds = true
            label.autoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleHeight
            label.backgroundColor = UIColor.whiteColor()
            label.textAlignment = NSTextAlignment.Center
            label.font = label.font.fontWithSize(35)
            label.numberOfLines = 0
            label.tag = 1
            returnedView.addSubview(label)
        } else {
            //get a reference to the label in the recycled view
            returnedView = reusingView!
            label = returnedView.viewWithTag(1) as UILabel
        }
        
        //set background color
        srand48(index)  // code color semi-randomly to index, so each view retains the same color
        let red = CGFloat(drand48())
        let green = CGFloat(drand48())
        let blue = CGFloat(drand48())
        returnedView.backgroundColor = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
        
        //set item label
        //remember to always set any properties of your carousel item
        //views outside of the `if (view == nil) {...}` check otherwise
        //you'll get weird issues with carousel item content appearing
        //in the wrong place in the carousel
        label.text = "This is view #\(self.items[index])."
        
        return returnedView;
    }
    
    //MARK: - SwipeViewDelegate functions
    func swipeViewItemSize(swipeView: SwipeView) -> CGSize {
        return self.swipeView.bounds.size
    }

}

