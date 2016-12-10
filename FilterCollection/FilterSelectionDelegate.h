//
//  FilterSelectionDelegateProtocol.h
//  FilterCollection
//
//  Created by Peter Steele on 12/7/16.
//  Copyright © 2016 Peter Steele. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol FilterSelectionDelegate <NSObject>

- (void)setFilter:(NSString *)filterName;

@end
