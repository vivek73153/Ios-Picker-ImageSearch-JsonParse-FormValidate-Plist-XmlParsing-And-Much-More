//  PagedFlowView.m
//  PicLab
//
//  Created by Rupesh on 2/15/14.
//  Copyright (c) 2014 The Social Ammo. All rights reserved.


#import "PagedFlowView.h"
#import <QuartzCore/QuartzCore.h>

@interface PagedFlowView ()
@property (nonatomic, assign, readwrite) NSInteger currentPageIndex;
@end

@implementation PagedFlowView
@synthesize dataSource = _dataSource;
@synthesize delegate = _delegate;
@synthesize pageControl;
@synthesize minimumPageAlpha = _minimumPageAlpha;
@synthesize minimumPageScale = _minimumPageScale;
@synthesize orientation;
@synthesize currentPageIndex = _currentPageIndex;

#pragma mark -
#pragma mark Private Methods
-(void)handleTapGesture:(UIGestureRecognizer*)gestureRecognizer
{
    NSInteger tappedIndex = 0;
    CGPoint locationInScrollView = [gestureRecognizer locationInView:_scrollView];
    if (CGRectContainsPoint(_scrollView.bounds, locationInScrollView))
    {
        tappedIndex = _currentPageIndex;
        if ([self.delegate respondsToSelector:@selector(flowView:didTapPageAtIndex:)])
        {
            [self.delegate flowView:self didTapPageAtIndex:tappedIndex];
        }
    }
}

- (void)initialize
{
    self.clipsToBounds = YES;
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    [self addGestureRecognizer:tapRecognizer];
    
    _needsReload = YES;
    _pageSize = self.bounds.size;
    _pageCount = 0;
    _currentPageIndex = 0;
    
    _minimumPageAlpha = 1.0;
    _minimumPageScale = 1.0;
    
    _visibleRange = NSMakeRange(0, 0);
    
    _reusableCells = [[NSMutableArray alloc] initWithCapacity:0];
    _cells = [[NSMutableArray alloc] initWithCapacity:0];
    
    _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    _scrollView.delegate = self;
    _scrollView.pagingEnabled = YES;
    _scrollView.clipsToBounds = NO;
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = NO;

    UIView *superViewOfScrollView = [[UIView alloc] initWithFrame:self.bounds];
    [superViewOfScrollView setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
    [superViewOfScrollView setBackgroundColor:[UIColor clearColor]];
    [superViewOfScrollView addSubview:_scrollView];
    [self addSubview:superViewOfScrollView];
    
}


- (void)dealloc
{
    _scrollView.delegate = nil;
}

- (void)queueReusableCell:(UIView *)cell
{
    [_reusableCells addObject:cell];
}

- (void)removeCellAtIndex:(NSInteger)index
{
    UIView *cell = [_cells objectAtIndex:index];
    if ((NSObject *)cell == [NSNull null])
    {
        return;
    }
    
    [self queueReusableCell:cell];
    
    if (cell.superview)
    {
        cell.layer.transform = CATransform3DIdentity;
        [cell removeFromSuperview];
    }
    
    [_cells replaceObjectAtIndex:index withObject:[NSNull null]];
}

- (void)refreshVisibleCellAppearance
{
    
    if (_minimumPageAlpha == 1.0 && _minimumPageScale == 1.0)
    {
        return;
    }
    switch (orientation)
    {
        case PagedFlowViewOrientationHorizontal:
        {
            CGFloat offset = _scrollView.contentOffset.x;
            
            for (NSInteger i = _visibleRange.location; i < _visibleRange.location + _visibleRange.length; i++)
            {
                UIView *cell = [_cells objectAtIndex:i];
                CGFloat origin = cell.frame.origin.x;
                CGFloat delta = fabs(origin - offset);
                                                
                [UIView beginAnimations:@"CellAnimation" context:nil];
                if (delta < _pageSize.width)
                {
                    cell.alpha = 1 - (delta / _pageSize.width) * (1 - _minimumPageAlpha);
                    
                    CGFloat pageScale = 1 - (delta / _pageSize.width) * (1 - _minimumPageScale);
                    cell.layer.transform = CATransform3DMakeScale(pageScale, pageScale, 1);
                }
                else
                {
                    cell.alpha = _minimumPageAlpha;
                    cell.layer.transform = CATransform3DMakeScale(_minimumPageScale, _minimumPageScale, 1);
                }
                [UIView commitAnimations];
            }
            break;   
        }
        case PagedFlowViewOrientationVertical:
        {
            CGFloat offset = _scrollView.contentOffset.y;
            
            for (NSInteger i = _visibleRange.location; i < _visibleRange.location + _visibleRange.length; i++)
            {
                UIView *cell = [_cells objectAtIndex:i];
                CGFloat origin = cell.frame.origin.y;
                CGFloat delta = fabs(origin - offset);
                                
                [UIView beginAnimations:@"CellAnimation" context:nil];
                if (delta < _pageSize.height) {
                    cell.alpha = 1 - (delta / _pageSize.height) * (1 - _minimumPageAlpha);
                    
                    CGFloat pageScale = 1 - (delta / _pageSize.height) * (1 - _minimumPageScale);
                    cell.layer.transform = CATransform3DMakeScale(pageScale, pageScale, 1);
                } else {
                    cell.alpha = _minimumPageAlpha;
                    cell.layer.transform = CATransform3DMakeScale(_minimumPageScale, _minimumPageScale, 1);
                }
                [UIView commitAnimations];
            }
        }
        default:
            break;
    }

}

- (void)setPageAtIndex:(NSInteger)pageIndex
{
    NSParameterAssert(pageIndex >= 0 && pageIndex < [_cells count]);
    
    UIView *cell = [_cells objectAtIndex:pageIndex];
    
    if ((NSObject *)cell == [NSNull null])
    {
        cell = [_dataSource flowView:self cellForPageAtIndex:pageIndex];
        NSAssert(cell!=nil, @"datasource must not return nil");
        [_cells replaceObjectAtIndex:pageIndex withObject:cell];
        
        
        switch (orientation) {
            case PagedFlowViewOrientationHorizontal:
                cell.frame = CGRectMake(_pageSize.width * pageIndex, 0, _pageSize.width, _pageSize.height);
                break;
            case PagedFlowViewOrientationVertical:
                cell.frame = CGRectMake(0, _pageSize.height * pageIndex, _pageSize.width, _pageSize.height);
                break;
            default:
                break;
        }
        
        if (!cell.superview)
        {
            [_scrollView addSubview:cell];
        }
    }
}


- (void)setPagesAtContentOffset:(CGPoint)offset
{
    if ([_cells count] == 0)
        return;
    
    CGPoint startPoint = CGPointMake(offset.x - _scrollView.frame.origin.x, offset.y - _scrollView.frame.origin.y);
    CGPoint endPoint = CGPointMake(MAX(0, startPoint.x) + self.bounds.size.width, MAX(0, startPoint.y) + self.bounds.size.height);
    
    
    switch (orientation)
    {
        case PagedFlowViewOrientationHorizontal:
        {
            NSInteger startIndex = 0;
            for (int i =0; i < [_cells count]; i++)
            {
                if (_pageSize.width * (i +1) > startPoint.x)
                {
                    startIndex = i;
                    break;
                }
            }
            
            NSInteger endIndex = startIndex;
            for (NSInteger i = startIndex; i < [_cells count]; i++)
            {
                if ((_pageSize.width * (i + 1) < endPoint.x && _pageSize.width * (i + 2) >= endPoint.x) || i+ 2 == [_cells count]) {
                    endIndex = i + 1;
                    break;
                }
            }
            
            startIndex = MAX(startIndex - 1, 0);
            endIndex = MIN(endIndex + 1, [_cells count] - 1);
            
            if (_visibleRange.location == startIndex && _visibleRange.length == (endIndex - startIndex + 1))
            {
                return;
            }
            
            _visibleRange.location = startIndex;
            _visibleRange.length = endIndex - startIndex + 1;
            
            for (NSInteger i = startIndex; i <= endIndex; i++)
            {
                [self setPageAtIndex:i];
            }
            
            for (NSInteger i = 0; i < startIndex; i ++)
            {
                [self removeCellAtIndex:i];
            }
            
            for (NSInteger i = endIndex + 1; i < [_cells count]; i ++)
            {
                [self removeCellAtIndex:i];
            }
            break;
        }
        case PagedFlowViewOrientationVertical:
        {
            NSInteger startIndex = 0;
            for (NSInteger i =0; i < [_cells count]; i++)
            {
                if (_pageSize.height * (i +1) > startPoint.y)
                {
                    startIndex = i;
                    break;
                }
            }
            
            NSInteger endIndex = startIndex;
            for (NSInteger i = startIndex; i < [_cells count]; i++)
            {
                if ((_pageSize.height * (i + 1) < endPoint.y && _pageSize.height * (i + 2) >= endPoint.y) || i+ 2 == [_cells count]) {
                    endIndex = i + 1;
                    break;
                }
            }
            
            startIndex = MAX(startIndex - 1, 0);
            endIndex = MIN(endIndex + 1, [_cells count] - 1);
            
            if (_visibleRange.location == startIndex && _visibleRange.length == (endIndex - startIndex + 1))
            {
                return;
            }
            
            _visibleRange.location = startIndex;
            _visibleRange.length = endIndex - startIndex + 1;
            
            for (NSInteger i = startIndex; i <= endIndex; i++)
            {
                [self setPageAtIndex:i];
            }
            
            for (NSInteger i = 0; i < startIndex; i ++)
            {
                [self removeCellAtIndex:i];
            }
            
            for (NSInteger i = endIndex + 1; i < [_cells count]; i ++) {
                [self removeCellAtIndex:i];
            }
            break;
        }
        default:
            break;
    }
    
    
    
}

#pragma mark -
#pragma mark Override Methods

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self initialize];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self initialize];
    }
    return self;
}

- (void)layoutSubviews{
    [super layoutSubviews];
    
    if (_needsReload)
    {
        
        if (_dataSource && [_dataSource respondsToSelector:@selector(numberOfPagesInFlowView:)]) {
            _pageCount = [_dataSource numberOfPagesInFlowView:self];
            
            if (pageControl && [pageControl respondsToSelector:@selector(setNumberOfPages:)]) {
                [pageControl setNumberOfPages:_pageCount];
            }
        }
        
        if (_delegate && [_delegate respondsToSelector:@selector(sizeForPageInFlowView:)]) {
            _pageSize = [_delegate sizeForPageInFlowView:self];
        }
        
        [_reusableCells removeAllObjects];
        _visibleRange = NSMakeRange(0, 0);
        
        for (NSInteger i=0; i<[_cells count]; i++) {
            [self removeCellAtIndex:i];
        }
        
        [_cells removeAllObjects];
        for (NSInteger index=0; index<_pageCount; index++)
        {
            [_cells addObject:[NSNull null]];
        }
        
        switch (orientation) {
            case PagedFlowViewOrientationHorizontal:
                _scrollView.frame = CGRectMake(0, 0, _pageSize.width, _pageSize.height);
                _scrollView.contentSize = CGSizeMake(_pageSize.width * _pageCount,_pageSize.height);
                CGPoint theCenter = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
                _scrollView.center = theCenter;
                break;
            case PagedFlowViewOrientationVertical:{
                _scrollView.frame = CGRectMake(0, 0, _pageSize.width, _pageSize.height);
                _scrollView.contentSize = CGSizeMake(_pageSize.width ,_pageSize.height * _pageCount);
                CGPoint theCenter = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
                _scrollView.center = theCenter;
                break;
            }
            default:
                break;
        }
    }
    

    [self setPagesAtContentOffset:_scrollView.contentOffset];
    
    [self refreshVisibleCellAppearance];
    
}

#pragma mark -
#pragma mark PagedFlowView API

- (void)reloadData
{
    _needsReload = YES;
    
    [self setNeedsLayout];
}


- (UIView *)dequeueReusableCell{
    UIView *cell = [_reusableCells lastObject];
    if (cell)
    {
        [_reusableCells removeLastObject];
    }
    
    return cell;
}

- (void)scrollToPage:(NSUInteger)pageNumber
{
    if (pageNumber < _pageCount)
    {
        switch (orientation)
        {
            case PagedFlowViewOrientationHorizontal:
                [_scrollView setContentOffset:CGPointMake(_pageSize.width * pageNumber, 0) animated:YES];
                break;
            case PagedFlowViewOrientationVertical:
                [_scrollView setContentOffset:CGPointMake(0, _pageSize.height * pageNumber) animated:YES];
                break;
        }
        [self setPagesAtContentOffset:_scrollView.contentOffset];
        [self refreshVisibleCellAppearance];
    }
}

#pragma mark -
#pragma mark hitTest

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if ([self pointInside:point withEvent:event])
    {
        CGPoint newPoint = CGPointZero;
        newPoint.x = point.x - _scrollView.frame.origin.x + _scrollView.contentOffset.x;
        newPoint.y = point.y - _scrollView.frame.origin.y + _scrollView.contentOffset.y;
        if ([_scrollView pointInside:newPoint withEvent:event])
        {
            return [_scrollView hitTest:newPoint withEvent:event];
        }
        
        return _scrollView;
    }
    
    return nil;
}


#pragma mark -
#pragma mark UIScrollView Delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    [self setPagesAtContentOffset:scrollView.contentOffset];
    [self refreshVisibleCellAppearance];
}


- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    NSInteger pageIndex;
    
    switch (orientation)
    {
        case PagedFlowViewOrientationHorizontal:
            pageIndex = floor(_scrollView.contentOffset.x / _pageSize.width);
            break;
        case PagedFlowViewOrientationVertical:
            pageIndex = floor(_scrollView.contentOffset.y / _pageSize.height);
            break;
        default:
            break;
    }
    
    if (pageControl && [pageControl respondsToSelector:@selector(setCurrentPage:)])
    {
        [pageControl setCurrentPage:pageIndex];
    }
    
    if ([_delegate respondsToSelector:@selector(flowView:didScrollToPageAtIndex:)] && _currentPageIndex != pageIndex)
    {
        [_delegate flowView:self didScrollToPageAtIndex:pageIndex];
    }
    
    _currentPageIndex = pageIndex;
}

@end
