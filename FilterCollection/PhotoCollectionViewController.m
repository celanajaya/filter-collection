//
//  ViewController.m
//  FilterCollection
//
//  Created by Peter Steele on 12/7/16.
//  Copyright © 2016 Peter Steele. All rights reserved.
//
#import "Photos/Photos.h"
#import "PhotoCollectionViewController.h"
#import "FilterSelectionViewController.h"
#import "FilterCollectionViewCell.h"

@interface PhotoCollectionViewController () <UICollectionViewDelegate, UICollectionViewDataSource, PHPhotoLibraryChangeObserver>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (nonatomic) CGRect previousPreheatRect;
@property (nonatomic) NSOperationQueue *filterQueue;
@property (nonatomic) NSMutableDictionary *currentFilterOperations;
@property (nonatomic) PHCachingImageManager *imageManager;
@property (nonatomic) NSMutableArray *imageAssets;
@property (nonatomic) NSString *currentFilter;

@end
@implementation PhotoCollectionViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
            [PHPhotoLibrary.sharedPhotoLibrary registerChangeObserver:self];
        }
    }];
    
    self.navigationController.title = @"Filter Photos";
    [self.collectionView setPrefetchingEnabled:NO];
    
    self.imageManager = [[PHCachingImageManager alloc] init];
    self.imageAssets = [[NSMutableArray alloc] init];
    self.previousPreheatRect = self.collectionView.bounds;
    
    self.filterQueue = [[NSOperationQueue alloc] init];
    self.filterQueue.name = @"Image Filter Queue";
    self.filterQueue.qualityOfService = NSQualityOfServiceBackground;
    
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
    PHFetchResult *results = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:options];
    
    [results enumerateObjectsUsingBlock:^(id  _Nonnull object, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([object isKindOfClass:[PHAsset class]]) {
            [self.imageAssets addObject:object];
        }
    }];
    [self updateCachedAssets];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.imageManager stopCachingImagesForAllAssets];
    [self.filterQueue cancelAllOperations];
    self.currentFilterOperations = [NSMutableDictionary dictionary];
    [super viewWillDisappear:animated];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self updateCachedAssets];
}

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    self.imageManager = [[PHCachingImageManager alloc] init];
    self.imageAssets = [[NSMutableArray alloc] init];
    self.previousPreheatRect = self.collectionView.bounds;
    
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
    PHFetchResult *results = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:options];
    
    [results enumerateObjectsUsingBlock:^(id  _Nonnull object, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([object isKindOfClass:[PHAsset class]]) {
            [self.imageAssets addObject:object];
        }
    }];
}

#pragma mark: Collection View Data Source & Delegates
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.imageAssets count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    FilterCollectionViewCell *cell=[collectionView dequeueReusableCellWithReuseIdentifier:@"FilterCollectionCellIdentifier" forIndexPath:indexPath];
    if (!cell) {
        cell = [[FilterCollectionViewCell alloc]init];
    }
    
    PHAsset *asset = self.imageAssets[indexPath.item];
    int requestID = [self.imageManager requestImageForAsset:asset
                                                 targetSize:CGSizeMake(100, 100)
                                                contentMode:PHImageContentModeAspectFill
                                                    options:nil
                                              resultHandler:^(UIImage *result, NSDictionary *info) {
                                                  if (result) {
                                                      __block FilterCollectionViewCell *destinationCell;
                                                      //if filters are on, filter the image on a background thread and display when ready
                                                      if (self.currentFilter != nil) {
                                                          
                                                          //cancel/remove any older requests for this image
                                                          int request = (int)info[@"PHImageResultRequestIDKey"];
                                                          NSBlockOperation *filterOperation = self.currentFilterOperations[[@(request) stringValue]];
                                                          [self.currentFilterOperations removeObjectForKey:[@(requestID) stringValue]];
                                                          [filterOperation cancel];
                                                          
                                                          NSBlockOperation *operation = [[NSBlockOperation alloc] init];
                                                          __weak NSBlockOperation *weakOperation = operation;
                                                          //operations are saved in self.currentFilterOpertaions array, use weakSelf
                                                          __weak PhotoCollectionViewController *weakSelf = self;
                                                          
                                                          [operation addExecutionBlock:^{
                                                              //apply filters
                                                              CIImage *inImage = [CIImage imageWithCGImage:result.CGImage];
                                                              CIFilter *filter = [CIFilter filterWithName:weakSelf.currentFilter keysAndValues:
                                                                                  kCIInputImageKey, inImage,
                                                                                  nil];
                                                              
                                                              CIImage *outImage = [filter outputImage];
                                                              
                                                              CGImageRef cgimageref = [[CIContext contextWithOptions:nil] createCGImage:outImage fromRect:[outImage extent]];
                                                              //check if operation is still needed
                                                              if ([weakOperation isCancelled]) {return;}
                                                              
                                                              __block UIImage *filteredImage = [UIImage imageWithCGImage:cgimageref];
                                                              [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                                                  destinationCell = (FilterCollectionViewCell *)[weakSelf.collectionView cellForItemAtIndexPath: indexPath];
                                                                  [weakSelf.currentFilterOperations removeObjectForKey:[@(destinationCell.tag) stringValue]];
                                                                  if (destinationCell) {
                                                                      destinationCell.imageView.image = filteredImage;
                                                                  }
                                                              }];
                                                          }];
                                                          
                                                          //save filter operations to a dictionary for cancellation
                                                          [self.currentFilterOperations setValue:operation forKey:[@(request) stringValue]];
                                                          [self.filterQueue addOperation:operation];
                                                          
                                                      } else {
                                                          //otherwise just set the image
                                                          destinationCell = (FilterCollectionViewCell *)[collectionView cellForItemAtIndexPath: indexPath];
                                                          if (destinationCell) {
                                                              destinationCell.imageView.image = result;
                                                          }
                                                      }
                                                  }
                                              }];
    cell.tag = requestID;
    return  cell;
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    FilterCollectionViewCell *filterCell = (FilterCollectionViewCell *)cell;
    
    if (self.currentFilter != nil) {
        //cancel the filter operation associated with this image
        NSString *filterID = [@(cell.tag) stringValue];
        NSBlockOperation *filterOperation = self.currentFilterOperations[filterID];
        [filterOperation cancel];
        [self.currentFilterOperations removeObjectForKey:[@(cell.tag) stringValue]];
    }
    
    //cancel any pending requests for this cell
    PHImageRequestID requestID = (PHImageRequestID)cell.tag;
    [self.imageManager cancelImageRequest:requestID];
    
    //remove the image
    filterCell.imageView.image = nil;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    FilterCollectionViewCell *filterCell = (FilterCollectionViewCell *)cell;
    filterCell.imageView.image = [UIImage imageNamed:@"default-placeholder"];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(100, 100);
}


- (IBAction)filterButtonPressed:(UIBarButtonItem *)sender {
    FilterSelectionViewController *filterSelectionVC =  [[FilterSelectionViewController alloc] initWithStyle:UITableViewStylePlain];
    filterSelectionVC.delegate = self;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:filterSelectionVC];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)setFilter:(NSString *)filterName {
    self.currentFilter = filterName;
    if (self.currentFilter != nil) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemUndo target:self action:@selector(undoFilters)];
    }
    [self.collectionView reloadData];
}

- (void)undoFilters {
    self.currentFilter = nil;
    self.navigationItem.leftBarButtonItem = nil;
    [self.collectionView reloadData];
}

#pragma mark: Caching Helpers
//sets a "preheating" rect when the user scrolls more than a 3rd of the way and begins caching
- (void)updateCachedAssets {
    //determine the preheat area, and start caching them (also remove older indexPaths)
    
    BOOL isViewVisible = [self isViewLoaded] && [[self view] window] != nil;
    if (!isViewVisible) { return; }
    
    // The preheat window is twice the height of the visible rect
    CGRect preheatRect = self.collectionView.bounds;
    preheatRect = CGRectInset(preheatRect, 0.0f, -0.5f * CGRectGetHeight(preheatRect));
    
    // If scrolled by greater than a third of its bounds amount...
    CGFloat delta = ABS(CGRectGetMidY(preheatRect) - CGRectGetMidY(self.previousPreheatRect));
    if (delta > CGRectGetHeight(self.collectionView.bounds) / 3.0f) {
        // Compute the assets to start caching and to stop caching.
        NSMutableArray *addedIndexPaths = [NSMutableArray array];
        NSMutableArray *removedIndexPaths = [NSMutableArray array];
        
        [self computeDifferenceBetweenRect:self.previousPreheatRect andRect:preheatRect removedHandler:^(CGRect removedRect) {
            NSArray *indexPaths = [self indexPathsForElementsInRect:removedRect];
            [removedIndexPaths addObjectsFromArray:indexPaths];
        } addedHandler:^(CGRect addedRect) {
            NSArray *indexPaths = [self indexPathsForElementsInRect:addedRect];
            [addedIndexPaths addObjectsFromArray:indexPaths];
        }];
        
        NSArray *assetsToStartCaching = [self assetsAtIndexPaths:addedIndexPaths];
        NSArray *assetsToStopCaching = [self assetsAtIndexPaths:removedIndexPaths];
        
        [self.imageManager startCachingImagesForAssets:assetsToStartCaching
                                            targetSize:CGSizeMake(100, 100)
                                           contentMode:PHImageContentModeAspectFill
                                               options:nil];
        
        [self.imageManager stopCachingImagesForAssets:assetsToStopCaching
                                           targetSize:CGSizeMake(100, 100)
                                          contentMode:PHImageContentModeAspectFill
                                              options:nil];
        
        self.previousPreheatRect = preheatRect;
    }
}


- (void)computeDifferenceBetweenRect:(CGRect)oldRect andRect:(CGRect)newRect removedHandler:(void (^)(CGRect removedRect))removedHandler addedHandler:(void (^)(CGRect addedRect))addedHandler
{
    if (CGRectIntersectsRect(newRect, oldRect)) {
        CGFloat oldMaxY = CGRectGetMaxY(oldRect);
        CGFloat oldMinY = CGRectGetMinY(oldRect);
        CGFloat newMaxY = CGRectGetMaxY(newRect);
        CGFloat newMinY = CGRectGetMinY(newRect);
        if (newMaxY > oldMaxY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, oldMaxY, newRect.size.width, (newMaxY - oldMaxY));
            addedHandler(rectToAdd);
        }
        if (oldMinY > newMinY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, newMinY, newRect.size.width, (oldMinY - newMinY));
            addedHandler(rectToAdd);
        }
        if (newMaxY < oldMaxY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, newMaxY, newRect.size.width, (oldMaxY - newMaxY));
            removedHandler(rectToRemove);
        }
        if (oldMinY < newMinY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, oldMinY, newRect.size.width, (newMinY - oldMinY));
            removedHandler(rectToRemove);
        }
    } else {
        addedHandler(newRect);
        removedHandler(oldRect);
    }
}

//an array of indexPaths within a rect
- (NSArray *)indexPathsForElementsInRect:(CGRect)rect {
    NSArray * layoutAttributes = [self.collectionView.collectionViewLayout layoutAttributesForElementsInRect:(rect)];
    NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
    for (UICollectionViewLayoutAttributes *attribute in layoutAttributes) {
        [indexPaths addObject:attribute.indexPath];
    }
    return indexPaths;
}

//an array of assets from the indexPath
- (NSArray *)assetsAtIndexPaths:(NSArray *)indexPaths {
    if (indexPaths.count == 0) { return nil; }
    
    NSMutableArray *assets = [NSMutableArray arrayWithCapacity:indexPaths.count];
    for (NSIndexPath *indexPath in indexPaths) {
        PHAsset *asset = self.imageAssets[indexPath.item];
        [assets addObject:asset];
    }
    return assets;
}


@end
