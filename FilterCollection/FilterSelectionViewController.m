//
//  FilterSelectionViewController.m
//  FilterCollection
//
//  Created by Peter Steele on 12/7/16.
//  Copyright © 2016 Peter Steele. All rights reserved.
//

#import "FilterSelectionViewController.h"
#import "FilterSelectionDelegate.h"
#import "CoreImage/CoreImage.h"

@interface FilterSelectionViewController ()
@property (nonatomic) NSArray *filterList;
@end

@implementation FilterSelectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc ] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(done)];
    self.navigationItem.leftBarButtonItem = doneButton;
    self.navigationItem.title = @"Choose a Filter";
    self.clearsSelectionOnViewWillAppear = NO;
    self.filterList = @[@"CIColorCrossPolynomial",
                        @"CIColorCube",
                        @"CIColorCubeWithColorSpace",
                        @"CIColorInvert",
                        @"CIColorMonochrome",
                        @"CIColorPosterize",
                        @"CIFalseColor",
                        @"CIMaximumComponent",
                        @"CIMinimumComponent",
                        @"CIPhotoEffectChrome",
                        @"CIPhotoEffectFade",
                        @"CIPhotoEffectInstant",
                        @"CIPhotoEffectMono",
                        @"CIPhotoEffectNoir",
                        @"CIPhotoEffectProcess"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filterList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *kFilterCellID = @"filterTableCellID";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kFilterCellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleValue1 reuseIdentifier: kFilterCellID];
    }
    cell.textLabel.text = self.filterList[indexPath.row];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self dismissViewControllerAnimated:YES completion:^{
        [self.delegate setFilter:self.filterList[indexPath.row]];
    }];
}

- (void)done {
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
