//
//  SKTRichNotificationViewController.m
//
//  Created by Mike Spensieri on 2016-08-29.
//  Copyright © 2016 Smooch Technologies Inc. All rights reserved.
//

#import "SKTRichNotificationViewController.h"
#import <UserNotifications/UserNotifications.h>
#import <UserNotificationsUI/UserNotificationsUI.h>

#pragma mark - Constants

static const CGFloat kLabelPadding = 10;
static const CGFloat kBubbleMargin = 10;
static const CGFloat kBubbleMaxWidthPercent = 0.8;
static const CGFloat kBubbleCornerRadius = 9;
static const CGFloat kAvatarSize = 40;

static const long kAppUserMessageColor = 0x00B0FF;
static const long kAppMakerMessageColor = 0xEDEDED;

static NSString* const kRoleKey = @"role";
static NSString* const kTextKey = @"text";
static NSString* const kAvatarUrlKey = @"avatarUrl";
static NSString* const kHistoryKey = @"history";
static NSString* const kAppUserRole = @"appUser";
static NSString* const kAppMakerRole = @"appMaker";

static NSString* const kDefaultAvatarFilename = @"defaultAvatar";

#pragma mark - SKTAvatarImageView

@interface SKTAvatarImageView : UIImageView
@property NSDictionary* message;
@end

@implementation SKTAvatarImageView
@end

#pragma mark - SKTPaddedLabel

@interface SKTPaddedLabel : UILabel
@end

@implementation SKTPaddedLabel

- (void)drawTextInRect:(CGRect)rect
{
    UIEdgeInsets insets = { kLabelPadding, kLabelPadding, kLabelPadding, kLabelPadding };
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, insets)];
}

@end

#pragma mark - SKTRichNotificationViewController

@interface SKTRichNotificationViewController () <UNNotificationContentExtension>

@property NSMutableArray* labels;
@property NSMutableArray* imageViews;
@property NSURLSession* urlSession;
@property NSCache* imageCache;
@property NSMutableDictionary* pendingDownloads;

@end

@implementation SKTRichNotificationViewController

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    self.labels = [NSMutableArray array];
    self.imageViews = [NSMutableArray array];
    self.urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    self.imageCache = [[NSCache alloc] init];
    self.pendingDownloads = [NSMutableDictionary dictionary];
}

-(UIColor*)colorFromHex:(long)hex
{
    return [UIColor colorWithRed:((float)((hex & 0xFF0000) >> 16))/255.0 green:((float)((hex & 0xFF00) >> 8))/255.0 blue:((float)(hex & 0xFF))/255.0 alpha:1.0];
}

-(UILabel*)labelAtIndex:(NSUInteger)index
{
    if(index < self.labels.count){
        return self.labels[index];
    }
    
    UILabel* label = [[SKTPaddedLabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.numberOfLines = 0;
    label.layer.cornerRadius = kBubbleCornerRadius;
    label.layer.masksToBounds = YES;
    [self.labels addObject:label];
    [self.view addSubview:label];
    
    return label;
}

-(SKTAvatarImageView*)imageViewAtIndex:(NSUInteger)index
{
    if(index < self.imageViews.count){
        return self.imageViews[index];
    }
    
    SKTAvatarImageView* imageView = [[SKTAvatarImageView alloc] initWithImage:[UIImage imageNamed:kDefaultAvatarFilename]];
    imageView.layer.cornerRadius = kAvatarSize / 2;
    imageView.layer.masksToBounds = YES;
    [self.view addSubview:imageView];
    [self.imageViews addObject:imageView];
    
    return imageView;
}

-(NSArray*)getMessages:(UNNotification*)notification
{
    NSMutableArray* messages = [NSMutableArray array];
    
    NSArray* history = notification.request.content.userInfo[kHistoryKey];
    if(history){
        [messages addObjectsFromArray:history];
    }
    
    NSString* text = notification.request.content.body;
    NSString* name = notification.request.content.userInfo[@"name"];
    if(name && [text rangeOfString:name].location == 0){
        text = [text stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@: ", name] withString:@""];
    }
    
    [messages addObject:@{
                          kTextKey: text,
                          kRoleKey: kAppMakerRole,
                          kAvatarUrlKey: notification.request.content.userInfo[kAvatarUrlKey] ?: @""
                          }];
    return messages;
}

-(void)fetchImageWithAvatarUrl:(NSString*)avatarUrl withCompletion:(void (^)(UIImage* image))completion
{
    if(!avatarUrl || avatarUrl.length == 0){
        return;
    }
    
    NSURL* url = [NSURL URLWithString:avatarUrl];
    
    if(!url){
        return;
    }

    UIImage* cachedImage = [self.imageCache objectForKey:avatarUrl];
    
    if(cachedImage){
        completion(cachedImage);
        return;
    }
    
    if(self.pendingDownloads[avatarUrl]){
        NSMutableArray* array = self.pendingDownloads[avatarUrl];
        [array addObject:completion];
        return;
    }

    self.pendingDownloads[avatarUrl] = [NSMutableArray arrayWithObject:completion];
    
    [[self.urlSession dataTaskWithURL:[NSURL URLWithString:avatarUrl] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        UIImage* image = [UIImage imageWithData:data];
        if(!image){
            return;
        }
        
        [self.imageCache setObject:image forKey:avatarUrl];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.pendingDownloads[avatarUrl] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                void (^completionBlock)(UIImage*) = obj;
                completionBlock(image);
            }];
            
            [self.pendingDownloads removeObjectForKey:avatarUrl];
        });
    }] resume];
}

- (void)didReceiveNotification:(UNNotification *)notification
{
    [self.labels setValue:@YES forKey:@"hidden"];
    [self.imageViews setValue:@YES forKey:@"hidden"];
    
    NSArray* messages = [self getMessages:notification];
    CGFloat maxWidth = self.view.bounds.size.width - 3*kBubbleMargin - kAvatarSize;

    __block CGFloat currentHeight = 0;
    [messages enumerateObjectsUsingBlock:^(NSDictionary*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        UILabel* label = [self labelAtIndex:idx];
        
        label.text = obj[kTextKey];
        
        CGSize size = [label sizeThatFits:CGSizeMake(maxWidth * kBubbleMaxWidthPercent, CGFLOAT_MAX)];
        CGRect frame = CGRectMake(0,
                                  currentHeight + kBubbleMargin,
                                  size.width + 2*kLabelPadding,
                                  size.height + 2*kLabelPadding);
        
        BOOL isAppUser = [obj[kRoleKey] isEqualToString:kAppUserRole];
        
        if(isAppUser){
            label.backgroundColor = [self colorFromHex:kAppUserMessageColor];
            label.textColor = [UIColor whiteColor];
            frame.origin.x = self.view.bounds.size.width - kBubbleMargin - frame.size.width;
        }else{
            label.backgroundColor = [self colorFromHex:kAppMakerMessageColor];
            label.textColor = [UIColor blackColor];
            frame.origin.x = 2*kBubbleMargin + kAvatarSize;
            
            SKTAvatarImageView* imageView = [self imageViewAtIndex:idx];
            imageView.frame = CGRectMake(kBubbleMargin, CGRectGetMaxY(frame) - kAvatarSize, kAvatarSize, kAvatarSize);
            imageView.hidden = NO;
            imageView.message = obj;
            
            NSString* avatarUrl = obj[kAvatarUrlKey];
            [self fetchImageWithAvatarUrl:avatarUrl withCompletion:^(UIImage *image) {
                if(imageView.message == obj){
                    imageView.image = image;
                }
            }];
        }

        label.frame = frame;
        label.hidden = NO;
        
        currentHeight += label.bounds.size.height + kBubbleMargin;
    }];
    
    
    self.preferredContentSize = CGSizeMake(self.view.bounds.size.width, currentHeight + kBubbleMargin);
}

@end
