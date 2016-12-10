//
//  FilterSelectionViewController.h
//  FilterCollection
//
//  Created by Peter Steele on 12/7/16.
//  Copyright © 2016 Peter Steele. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FilterSelectionDelegate.h"

@interface FilterSelectionViewController : UITableViewController
@property (nonatomic, weak) id <FilterSelectionDelegate> delegate;
@end
