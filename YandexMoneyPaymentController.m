//
//  YandexMoneyPaymentController.m
//  AutoHelp
//
//  Created on 13.01.2018.
//  Copyright © 2018. All rights reserved.
//

#import "YandexMoneyPaymentController.h"
#import "AutoHelp-Swift.h"


@interface YandexMoneyPaymentController () <UIWebViewDelegate> {
    YMAExternalPaymentSession *session;
    NSString *requestID;
    YMAResponseStatus lastStatus;
}

@end

@implementation YandexMoneyPaymentController

-(void)viewDidLoad {
    [super viewDidLoad];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self authorization];
    });
}

-(void)authorization {
    
    session = [[YMAExternalPaymentSession alloc] init];
    
    if (StorageManager.shared.yandexInstanceID == nil) {
        [session instanceWithClientId: @"secret key"
                                token: nil
                           completion: ^(NSString *ID, NSError *error)     {
                               if (error != nil) {
                                   NSLog(@"%@", error.localizedDescription);
                               } 
                               else {
                                   StorageManager.shared.yandexInstanceID = ID;
                                   session.instanceId = ID;
                                   NSLog(@"NEW INSTANCE ID: %@", ID);
                                   [self requestExternalPayment];
                               }
                           }];
    } else {
        NSString *ID = StorageManager.shared.yandexInstanceID;
        session.instanceId = ID;
        NSLog(@"OLD INSTANCE ID: %@", ID);
        [self requestExternalPayment];
    }
    
};

-(void)requestExternalPayment {
    
    NSDictionary *paymentParams = @{
        @"amount" : @(_amount),
        @"pattern_id" : @"p2p",
        @"instance_id" : StorageManager.shared.yandexInstanceID,
        @"to" : @(0)
    };
    
    YMAExternalPaymentRequest *externalPaymentRequest = [YMAExternalPaymentRequest externalPaymentWithPatternId: @"p2p"
                                                                                               andPaymentParams: paymentParams];
    
    [session performRequest: externalPaymentRequest
                      token: nil
                 completion: ^(YMABaseRequest *request, YMABaseResponse *response, NSError *error) {
                     if (error != nil) {
                         NSLog(@"%@", error.localizedDescription);
                     } else {
                         YMAExternalPaymentResponse *externalPaymentResponse = (YMAExternalPaymentResponse *)response;
                         requestID = [externalPaymentResponse paymentRequestInfo].requestId;
                         if (requestID == nil) {
                             NSLog(@"REQUEST ID IS NIL");
                         } else {
                             NSLog(@"REQUEST ID: %@", requestID);
                             [self processExternalPayment];
                         }
                     }
                 }];
    
};

-(void)processExternalPayment {
    
    YMABaseRequest *processExternalPaymentRequest = [YMAProcessExternalPaymentRequest processExternalPaymentWithRequestId: requestID
                                                                                                               successUri: @"http://blank.html"
                                                                                                                  failUri: @"http://blank.html"
                                                                                                             requestToken: NO];
    
    [session performRequest: processExternalPaymentRequest
                      token: nil
                 completion: ^(YMABaseRequest *request, YMABaseResponse *response, NSError *error) {
                     
                     if (error != nil) {
                         NSLog(@"%@", error.localizedDescription);
                         return;
                     }
                     
                     YMABaseProcessResponse *baseResponse = (YMABaseProcessResponse *)response;
                    
                     if (baseResponse.status == YMAResponseStatusInProgress) {
                         
                         NSLog(@"EXTERNAL PAYMENT IN PROGRESS");

                         dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, baseResponse.nextRetry);
                         dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                             [self processExternalPayment];
                         });
                         
                     } else if (baseResponse.status == YMAResponseStatusSuccess) {
                         
                         NSLog(@"EXTERNAL PAYMENT SUCCESSED");
                         dispatch_async(dispatch_get_main_queue(), ^{
                             [_webView stopLoading];
                             [_replenishView paymentSuccessed];
                             [self.navigationController popViewControllerAnimated: YES];
                         });
                         
                     } else if (baseResponse.status == YMAResponseStatusExtAuthRequired) {
                         
                         if (lastStatus == YMAResponseStatusExtAuthRequired) {
                             NSLog(@"EXTERNAL PAYMENT WAIT FOR USER");
                             return;
                         }
                         
                         dispatch_async(dispatch_get_main_queue(), ^{
                             
                             NSLog(@"EXTERNAL PAYMENT AUTH REQUIRED");

                             YMAProcessExternalPaymentResponse *processExternalPaymentResponse = (YMAProcessExternalPaymentResponse *)response;
                             YMAAscModel *asc = processExternalPaymentResponse.asc;
                         
                             NSMutableString *post = [NSMutableString string];
                         
                             for (NSString *key in asc.params.allKeys) {
                                 NSString *paramValue = [self addPercentEscapesToString:(asc.params)[key]];
                                 NSString *paramKey = [self addPercentEscapesToString:key];
                             
                                 [post appendString:[NSString stringWithFormat:@"%@=%@&", paramKey, paramValue]];
                             }
                         
                             if (post.length)
                                 [post deleteCharactersInRange:NSMakeRange(post.length - 1, 1)];
                         
                             NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:asc.url];
                             NSData *postData = [post dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
                             [request setHTTPMethod:@"POST"];
                             [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long) postData.length] forHTTPHeaderField:@"Content-Length"];
                             [request setHTTPBody:postData];
                         
                             [_webView loadRequest:request];
                         });
                         
                     } else if (baseResponse.status == YMAResponseStatusRefused) {
                         
                         [_replenishView paymentFailed];
                         [self.navigationController popViewControllerAnimated: YES];
                         
                     }
                     
                     lastStatus = baseResponse.status;
                     
                 }];
    
};

- (NSString *)addPercentEscapesToString:(NSString *)string {
    return (NSString *) CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                  (__bridge CFStringRef)string,
                                                                                  NULL,
                                                                                  (CFStringRef)@";/?:@&=+$,",
                                                                                  kCFStringEncodingUTF8));
}

-(void)webViewDidFinishLoad:(UIWebView *)webView {
    
    [self processExternalPayment];
    
}

@end
