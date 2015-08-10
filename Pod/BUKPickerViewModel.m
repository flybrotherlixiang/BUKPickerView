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
@property (nonatomic, strong) BUKPickerTitleView *buk_titleView;
@property (nonatomic, weak) BUKPickerView *buk_pickerView;
@property (nonatomic, strong) NSMutableArray *buk_selectionResult;

@end

@implementation BUKPickerViewModel

- (instancetype)initWithPickerViewItems:(NSArray *)items complete:(void (^)(id))complete
{
    if (!items || ![items isKindOfClass:[NSArray class]]) {
        return nil;
    }
    
    self = [super init];
    
    if (self) {
        
        self.buk_completeBlock = complete;
        
        [self.buk_itemsStack addObject:items];
        
        _coverRates = [self buk_defaultCoverRateForItems:items];
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
    
    return self;
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
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
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

    if (self.needTitleView && pickerView.titleView != self.buk_titleView) {
        pickerView.titleView = self.buk_titleView;
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
    if ([pickerView popToDepth:depth]) {
        [self.buk_itemsStack removeObjectsInRange:NSMakeRange(depth + 1, self.buk_itemsStack.count - depth - 1)];
    }
    
    BUKPickerViewItem *item = [self buk_itemAtIndexPath:indexPath depth:depth];
    
    if (item.children) {
        [self.buk_itemsStack addObject:item.children];
        [pickerView push];
    } else if (item.lazyChildren) {
        item.lazyChildren(^(NSArray *chilren) {
            if (!chilren) {
                return ;
            }
            item.children = chilren;
            [self.buk_itemsStack addObject:chilren];
            [pickerView push];
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
    if (!self.needTitleView) {
        return;
    }
    
    self.buk_titleView.leftButton.hidden = depth == 0;
}

- (void)buk_pickerView:(BUKPickerView *)pickerView didFinishPushToDepth:(NSInteger)depth
{
    if (!self.needTitleView) {
        return;
    }
    
    self.buk_titleView.leftButton.hidden = depth == 0;
}

#pragma mark - private
- (NSArray *)buk_itemsStackAtDepth:(NSInteger)depth
{
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

#pragma mark - setter && getter -
- (NSMutableArray *)buk_itemsStack
{
    if (!_buk_itemsStack) {
        _buk_itemsStack = [[NSMutableArray alloc] init];
    }
    
    return _buk_itemsStack;
}

- (BUKPickerTitleView *)buk_titleView
{
    if (!_buk_titleView) {
        _buk_titleView = [[BUKPickerTitleView alloc] init];
        _buk_titleView.leftButton.hidden = YES;
        _buk_titleView.rightButton.hidden = !self.allowMultiSelect;
        __weak typeof(self) weakSelf = self;
        _buk_titleView.leftButtonAction = ^(BUKPickerTitleView *titleView) {
            [weakSelf.buk_itemsStack removeLastObject];
            [weakSelf.buk_pickerView pop];
            
            UITableView *tableView = [weakSelf.buk_pickerView tableViewAtDepth:weakSelf.buk_itemsStack.count - 1];
            if (tableView) {
                [tableView deselectRowAtIndexPath:tableView.indexPathForSelectedRow animated:NO];
            }
        };
        _buk_titleView.rightButtonAction = ^(BUKPickerTitleView *titleView) {
            [weakSelf buk_finishSelectionWithResult:weakSelf.buk_selectionResult];
            [weakSelf.buk_pickerView buk_dynamicHide];
        };
    }
    
    return _buk_titleView;
}

- (NSMutableArray *)buk_selectionResult
{
    if (!_buk_selectionResult) {
        _buk_selectionResult = [[NSMutableArray alloc] init];
    }
    
    return _buk_selectionResult;
}

- (void)setAllowMultiSelect:(BOOL)allowMultiSelect
{
    [self willChangeValueForKey:NSStringFromSelector(@selector(allowMultiSelect))];
    _allowMultiSelect = allowMultiSelect;
    [self didChangeValueForKey:NSStringFromSelector(@selector(allowMultiSelect))];
    
    if (!_buk_titleView) {
        self.buk_titleView.rightButton.hidden = !allowMultiSelect;
    }
}

@end