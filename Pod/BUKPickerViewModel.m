//
//  BUKPickerViewModel.m
//  Pods
//
//  Created by hyice on 15/8/6.
//
//

#import "BUKPickerViewModel.h"
#import "BUKPickerViewDefaultCell.h"
#import "BUKPickerTitleView.h"

@implementation BUKPickerViewItem
@end



static NSString * const kBUKPickerViewDefaultCellIdentifier = @"kBUKPickerViewDefaultCellIdentifier";

@interface BUKPickerViewModel ()

@property (nonatomic, strong) NSMutableArray *buk_itemsStack;
@property (nonatomic, copy) void (^buk_completeBlock)(id result);
@property (nonatomic, copy) void (^buk_lazyLoadBlock)(BUKFinishLoadPickerViewItemsBlock finishLoad);
@property (nonatomic, strong) BUKPickerTitleView *titleView;
@property (nonatomic, weak) BUKPickerView *buk_pickerView;
@property (nonatomic, strong) NSMutableArray *buk_selectionResult;

@property (nonatomic, assign) BOOL buk_userInteracted;

@end

@implementation BUKPickerViewModel

- (instancetype)initWithPickerViewItems:(NSArray *)items complete:(void (^)(id))complete
{
    self = [super init];
    
    if (self) {
        
        [self buk_setupDefaultViewStyle];
        
        self.buk_completeBlock = complete;
        
        [self buk_addRootItems:items];
    }
    
    return self;
}

- (instancetype)initWithLazyPickerViewItems:(void (^)(BUKFinishLoadPickerViewItemsBlock))lazyLoad complete:(void (^)(id))complete
{
    self = [super init];
    
    if (self) {
        
        [self buk_setupDefaultViewStyle];
        
        self.buk_completeBlock = complete;
        self.buk_lazyLoadBlock = lazyLoad;
    }
    
    return self;
}

- (void)buk_setupDefaultViewStyle
{
    _needTitleView = YES;
    
    _oddLevelCellNormalTextColor = [UIColor colorWithRed:0x66/255.0 green:0x66/255.0 blue:0x66/255.0 alpha:1.0];
    _oddLevelCellNormalBgColor = [UIColor whiteColor];
    _oddLevelCellHighlightTextColor = [UIColor orangeColor];
    _oddLevelCellHighlightBgColor = [UIColor colorWithRed:0xf8/255.0 green:0xf8/255.0 blue:0xf8/255.0 alpha:1.0];
    
    _evenLevelCellNormalTextColor = _oddLevelCellNormalTextColor;
    _evenLevelCellNormalBgColor = _oddLevelCellHighlightBgColor;
    _evenLevelCellHighlightTextColor = _oddLevelCellHighlightTextColor;
    _evenLevelCellHighlightBgColor = _oddLevelCellNormalBgColor;
}

- (void)buk_addRootItems:(NSArray *)items
{
    if (!items || ![items isKindOfClass:[NSArray class]]) {
        return;
    }
    
    self.buk_itemsStack = nil;
    [self.buk_itemsStack addObject:items];
    
    [self buk_loadDefaultSelectionsFromItems:items];
    
    _coverRates = [self buk_defaultCoverRateForItems:items];
}

#pragma mark - BUKPickerViewDataSourceAndDelegate
- (NSInteger)buk_tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section depth:(NSInteger)depth pickerView:(BUKPickerView *)pickerView
{
    return [self buk_itemsStackAtDepth:depth].count;
}

- (UITableViewCell *)buk_tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath depth:(NSInteger)depth pickerView:(BUKPickerView *)pickerView
{
    BUKPickerViewDefaultCell *cell = [tableView dequeueReusableCellWithIdentifier:kBUKPickerViewDefaultCellIdentifier forIndexPath:indexPath];
    
    if (depth % 2 == 0) {
        cell.normalStateTextColor = self.oddLevelCellNormalTextColor;
        cell.normalStateBgColor = self.oddLevelCellNormalBgColor;
        cell.selectedStateTextColor = self.oddLevelCellHighlightTextColor;
        cell.selectedStateBgColor = self.oddLevelCellHighlightBgColor;
    }else {
        cell.normalStateTextColor = self.evenLevelCellNormalTextColor;
        cell.normalStateBgColor = self.evenLevelCellNormalBgColor;
        cell.selectedStateTextColor = self.evenLevelCellHighlightTextColor;
        cell.selectedStateBgColor = self.evenLevelCellHighlightBgColor;
    }
    
    BUKPickerViewItem *item = [self buk_itemAtIndexPath:indexPath depth:depth];
    if (item) {
        cell.imageView.image = item.image;
        cell.textLabel.text = item.title;
        if (item.isSelected) {
            if (!item.children && !item.lazyChildren) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
        } else if (item.children || item.lazyChildren) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    
    return cell;
}

- (void)buk_registerCellClassOrNibForTableView:(UITableView *)tableView depth:(NSInteger)depth pickerView:(BUKPickerView *)pickerView
{
    self.buk_pickerView = pickerView;
    
    if (depth % 2 == 0) {
        tableView.backgroundColor = self.oddLevelCellNormalBgColor;
    }else {
        tableView.backgroundColor = self.evenLevelCellNormalBgColor;
    }
    
    if (self.needTitleView && pickerView.titleView != self.titleView) {
        pickerView.titleView = self.titleView;
    }
    
    [tableView registerClass:[BUKPickerViewDefaultCell class] forCellReuseIdentifier:kBUKPickerViewDefaultCellIdentifier];
}

- (CGFloat)buk_coverRateForTableView:(UITableView *)tableView depth:(NSInteger)depth pickerView:(BUKPickerView *)pickerView
{
    if (!self.coverRates || !self.coverRates.count) {
        return 1.0;
    }
    
    NSInteger index = depth;
    if (self.coverRates.count <= index) {
        index = self.coverRates.count - 1;
    }
    
    id value = [self.coverRates objectAtIndex:index];
    
    if ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]]) {
        return [value floatValue];
    }
    
    return 1.0;
}

- (void)buk_tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath depth:(NSInteger)depth pickerView:(BUKPickerView *)pickerView
{
    self.buk_userInteracted = YES;
    
    if ([pickerView popToDepth:depth]) {
        [self.buk_itemsStack removeObjectsInRange:NSMakeRange(depth + 1, self.buk_itemsStack.count - depth - 1)];
    }
    
    BUKPickerViewItem *item = [self buk_itemAtIndexPath:indexPath depth:depth];
    
    if (item.children && item.children.count != 0) {
        [self.buk_itemsStack addObject:item.children];
        [pickerView push];
    } else if (item.lazyChildren && !item.children) {
        [self buk_showLoadingView];
        item.lazyChildren(^(NSArray *chilren) {
            if (!chilren || ![chilren isKindOfClass:[NSArray class]]) {
                return ;
            }
            
            item.children = chilren;
            
            [self buk_tableView:tableView didSelectRowAtIndexPath:indexPath depth:depth pickerView:pickerView];
            
            [self buk_hideLoadingView];
        });
        
    } else {
        if (self.allowMultiSelect) {
            if (item.isSelected) {
                item.isSelected = NO;
                [self.buk_selectionResult removeObject:item];
            }else {
                item.isSelected = YES;
                [self.buk_selectionResult addObject:item];
            }
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        }else {
            [self buk_finishSelectionWithResult:item];
            [pickerView buk_dynamicHide];
        }
    }
}

- (void)buk_pickerView:(BUKPickerView *)pickerView didFinishPopToDepth:(NSInteger)depth
{
    self.buk_userInteracted = YES;
    
    if (!self.needTitleView) {
        return;
    }
    
    self.titleView.leftButton.hidden = depth == 0;
}

- (void)buk_pickerView:(BUKPickerView *)pickerView didFinishPushToDepth:(NSInteger)depth
{
    [self buk_highlightDefaultSelectionAtDepth:depth];
    
    if (!self.needTitleView) {
        return;
    }
    
    self.titleView.leftButton.hidden = depth == 0;
}

#pragma mark - private
- (NSArray *)buk_itemsStackAtDepth:(NSInteger)depth
{
    if (self.buk_lazyLoadBlock) {
        BUKFinishLoadPickerViewItemsBlock finishLoad = ^(NSArray *items) {
            self.buk_lazyLoadBlock = nil;
            [self buk_addRootItems:items];
            [[self.buk_pickerView tableViewAtDepth:0] reloadData];
            [self buk_hideLoadingView];
        };
        
        [self buk_showLoadingView];
        self.buk_lazyLoadBlock(finishLoad);
        return nil;
    }
    
    if (self.buk_itemsStack.count <= depth) {
        return nil;
    }
    
    NSArray *items = [self.buk_itemsStack objectAtIndex:depth];
    if (!items || ![items isKindOfClass:[NSArray class]]) {
        return nil;
    }
    
    return items;
}

- (BUKPickerViewItem *)buk_itemAtIndexPath:(NSIndexPath *)indexPath depth:(NSInteger)depth
{
    NSArray *items = [self buk_itemsStackAtDepth:depth];
    
    if (!items || items.count <= indexPath.row) {
        return nil;
    }
    
    BUKPickerViewItem *item = [items objectAtIndex:indexPath.row];
    
    if (![item isKindOfClass:[BUKPickerViewItem class]]) {
        return nil;
    }
    
    return item;
}

- (NSArray *)buk_defaultCoverRateForItems:(NSArray *)items
{
    NSInteger levels = 1;
    BUKPickerViewItem *item = items.lastObject;
    
    if (!item) {
        return @[@1.0];
    }
    
    while (item && item.children && item.children.count) {
        levels++;
        item = item.children.lastObject;
    }
    
    if (item.lazyChildren) {
        levels++;
    }
    
    NSMutableArray *rates = [[NSMutableArray alloc] initWithCapacity:levels];
    for (int i = 0; i < levels; i++) {
        [rates addObject:@(1-i*1.0/levels)];
    }
    
    return rates;
}

- (void)buk_finishSelectionWithResult:(id)result
{
    if (self.buk_completeBlock) {
        self.buk_completeBlock(result);
    }
}

- (void)buk_loadDefaultSelectionsFromItems:(NSArray *)items
{
    if (![items isKindOfClass:[NSArray class]]) {
        NSAssert(NO, @"BUKPickerViewModel: Not Valid BUKPickerViewItem Children!");
        return;
    }
    
    [items enumerateObjectsUsingBlock:^(BUKPickerViewItem *item, NSUInteger idx, BOOL *stop) {
        if (![item isKindOfClass:[BUKPickerViewItem class]]) {
            NSAssert(NO, @"BUKPickerViewModel: Not Valid BUKPickerViewItem!");
            return;
        }
        
        if (item.isSelected) {
            if (item.children) {
                if (!self.allowMultiSelect) {
                    [self.buk_itemsStack addObject:item.children];
                }
            } else {
                [self.buk_selectionResult addObject:item];
            }
        }
        
        if (item.children) {
            [self buk_loadDefaultSelectionsFromItems:item.children];
        }
    }];
}

- (void)buk_showLoadingView
{
    [self.loadingView removeFromSuperview];
    
    [self.buk_pickerView addSubview:self.loadingView];
    self.loadingView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.buk_pickerView addConstraints:@[
                                          [NSLayoutConstraint constraintWithItem:self.loadingView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.needTitleView ? self.titleView : self.buk_pickerView attribute:self.needTitleView? NSLayoutAttributeBottom : NSLayoutAttributeTop multiplier:1.0 constant:0],
                                          [NSLayoutConstraint constraintWithItem:self.loadingView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.buk_pickerView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0],
                                          [NSLayoutConstraint constraintWithItem:self.loadingView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.buk_pickerView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0],
                                          [NSLayoutConstraint constraintWithItem:self.loadingView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.buk_pickerView attribute:NSLayoutAttributeRight multiplier:1.0 constant:0]
                                          ]];
    
    self.loadingView.alpha = 0.0f;
    [UIView animateWithDuration:0.25f animations:^{
        self.loadingView.alpha = 1.0f;
    }];
}

- (void)buk_hideLoadingView
{
    CALayer *layer = [self.loadingView.layer presentationLayer];
    CGFloat alpha = layer.opacity;
    [self.loadingView.layer removeAllAnimations];
    self.loadingView.alpha = alpha;
    [UIView animateWithDuration:0.25f animations:^{
        self.loadingView.alpha = 0.0f;
    } completion:^(BOOL finished) {
        [self.loadingView removeFromSuperview];
    }];
}

- (void)buk_highlightDefaultSelectionAtDepth:(NSInteger)depth
{
    NSInteger stackCount = self.buk_itemsStack.count;
    if (stackCount <= 1) {
        return;
    }
    
    if (stackCount <= depth) {
        return;
    }
    
    NSArray *currentItems = [self.buk_itemsStack objectAtIndex:depth];
    BUKPickerViewItem *selectedItem;
    
    if (self.buk_itemsStack.count > depth + 1) {
        
        if (self.buk_userInteracted) {
            return;
        }
        
        if (self.allowMultiSelect) {
            return;
        }
        
        NSArray *childrenItems = [self.buk_itemsStack objectAtIndex:depth+1];
        
        BUKPickerViewItem *childItem = [childrenItems firstObject];
        selectedItem = childItem.parent;
    } else {
        selectedItem = [self.buk_selectionResult firstObject];
    }
    
    if (!selectedItem) {
        return;
    }
    
    NSInteger index = [currentItems indexOfObject:selectedItem];
    if (index != NSNotFound) {
        UITableView *tableView = [self.buk_pickerView tableViewAtDepth:depth];
        [tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
}


#pragma mark - setter && getter -
- (NSMutableArray *)buk_itemsStack
{
    if (!_buk_itemsStack) {
        _buk_itemsStack = [[NSMutableArray alloc] init];
    }
    
    return _buk_itemsStack;
}

- (BUKPickerTitleView *)titleView
{
    if (!_titleView) {
        _titleView = [[BUKPickerTitleView alloc] init];
        _titleView.leftButton.hidden = YES;
        _titleView.rightButton.hidden = !self.allowMultiSelect;
        __weak typeof(self) weakSelf = self;
        _titleView.leftButtonAction = ^(BUKPickerTitleView *titleView) {
            [weakSelf.buk_itemsStack removeLastObject];
            [weakSelf.buk_pickerView pop];
            
            UITableView *tableView = [weakSelf.buk_pickerView tableViewAtDepth:weakSelf.buk_itemsStack.count - 1];
            if (tableView) {
                [tableView deselectRowAtIndexPath:tableView.indexPathForSelectedRow animated:NO];
            }
        };
        _titleView.rightButtonAction = ^(BUKPickerTitleView *titleView) {
            [weakSelf buk_finishSelectionWithResult:weakSelf.buk_selectionResult];
            [weakSelf.buk_pickerView buk_dynamicHide];
        };
    }
    
    return _titleView;
}

- (NSMutableArray *)buk_selectionResult
{
    if (!_buk_selectionResult) {
        _buk_selectionResult = [[NSMutableArray alloc] init];
    }
    
    return _buk_selectionResult;
}

- (UIView *)loadingView
{
    if (!_loadingView) {
        _loadingView = [[UIView alloc] init];
        _loadingView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
        
        UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        [indicator startAnimating];
        [_loadingView addSubview:indicator];
        
        indicator.translatesAutoresizingMaskIntoConstraints = NO;
        [_loadingView addConstraints:@[
                                       [NSLayoutConstraint constraintWithItem:indicator attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:_loadingView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0],
                                       [NSLayoutConstraint constraintWithItem:indicator attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_loadingView attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]
                                       ]
         ];
    }
    
    return _loadingView;
}

- (void)setAllowMultiSelect:(BOOL)allowMultiSelect
{
    [self willChangeValueForKey:NSStringFromSelector(@selector(allowMultiSelect))];
    _allowMultiSelect = allowMultiSelect;
    [self didChangeValueForKey:NSStringFromSelector(@selector(allowMultiSelect))];
    
    if (!_titleView) {
        self.titleView.rightButton.hidden = !allowMultiSelect;
    }
}

@end
