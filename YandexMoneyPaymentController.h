//
//  YandexMoneyPaymentController.h
//  AutoHelp
//
//  Created on 13.01.2018.
//  Copyright © 2018. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <YandexMoneySDKObjc/YandexMoneySDKObjc-umbrella.h>
//#import "YandexMoneySDKiOS-umbrella.h"

@protocol AbstractReplenishView;

@interface YandexMoneyPaymentController : UIViewController

@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property float amount;
@property (weak) id<AbstractReplenishView> replenishView;

@end
